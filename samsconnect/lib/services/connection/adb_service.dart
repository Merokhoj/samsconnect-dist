import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:logger/logger.dart';
import '../../data/models/device.dart';
import '../../data/models/app_info.dart';
import '../../platform/platform_interface.dart';

import 'base_mobile_service.dart';

class AdbService implements BaseMobileService {
  @override
  MobilePlatform get platform => MobilePlatform.android;

  final PlatformInterface _platform;
  final Logger _logger = Logger();
  String? _adbPath;

  AdbService(this._platform);

  @override
  Future<void> initialize() async {
    try {
      _adbPath = await _platform.getAdbPath();
      _logger.i('ADB initialized at: $_adbPath');

      // Start ADB server
      await _runAdbCommand(['start-server']);
    } catch (e) {
      _logger.e('Failed to initialize ADB', error: e);
      rethrow;
    }
  }

  @override
  Future<List<Device>> getDevices() async {
    final result = await _runAdbCommand(['devices', '-l']);
    if (result.exitCode != 0) {
      throw Exception('Failed to get devices: ${result.stderr}');
    }

    final lines = (result.stdout as String).split('\n');
    final devices = <Device>[];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('List of devices')) continue;
      if (!line.contains('device')) continue;

      try {
        devices.add(Device.fromAdbString(line));
      } catch (e) {
        _logger.w('Failed to parse device: $line', error: e);
      }
    }

    return devices;
  }

  Future<bool> connectWifi(String ipAddress, {int port = 5555}) async {
    _logger.i('Connecting to $ipAddress:$port');
    final target = ipAddress.contains(':') ? ipAddress : '$ipAddress:$port';
    final result = await _runAdbCommand(['connect', target]);
    final output = result.stdout.toString();

    return output.contains('connected');
  }

  Future<bool> pairDevice(String ipPort, String pairingCode) async {
    _logger.i('Pairing with $ipPort using code $pairingCode');
    final result = await _runAdbCommand(['pair', ipPort, pairingCode]);
    final output = result.stdout.toString() + result.stderr.toString();

    _logger.i('Pairing result: $output');
    return output.contains('Successfully paired');
  }

  Future<bool> disconnectDevice(String deviceId) async {
    final result = await _runAdbCommand(['-s', deviceId, 'disconnect']);
    return result.exitCode == 0;
  }

  Future<void> enableTcpip({int port = 5555}) async {
    await _runAdbCommand(['tcpip', port.toString()]);
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<String?> getDeviceIp(String deviceId) async {
    final result = await _runAdbCommand([
      '-s',
      deviceId,
      'shell',
      'ip',
      'addr',
      'show',
      'wlan0',
    ]);

    if (result.exitCode != 0) return null;

    final output = result.stdout.toString();
    final regex = RegExp(r'inet (\d+\.\d+\.\d+\.\d+)');
    final match = regex.firstMatch(output);

    return match?.group(1);
  }

  Future<void> executeShellCommand(String deviceId, String command) async {
    await _runAdbCommand(['-s', deviceId, 'shell', command]);
  }

  Future<String> getProperty(String deviceId, String property) async {
    final result = await _runAdbCommand([
      '-s',
      deviceId,
      'shell',
      'getprop',
      property,
    ]);
    return result.stdout.toString().trim();
  }

  Future<void> pressKey(String deviceId, int keyCode) async {
    await executeShellCommand(deviceId, 'input keyevent $keyCode');
  }

  Future<void> inputText(String deviceId, String text) async {
    // Escape special characters
    final escaped = text.replaceAll(' ', '%s');
    await executeShellCommand(deviceId, 'input text "$escaped"');
  }

  Future<ProcessResult> _runAdbCommand(
    List<String> arguments, {
    Encoding? stdoutEncoding = const SystemEncoding(),
  }) async {
    if (_adbPath == null) {
      throw Exception('ADB not initialized. Call initialize() first.');
    }

    _logger.d('Running ADB: $_adbPath ${arguments.join(' ')}');
    return await Process.run(
      _adbPath!,
      arguments,
      stdoutEncoding: stdoutEncoding,
    );
  }

  /// Capture device screen
  @override
  Future<Uint8List?> getScreenCapture(String deviceId) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'exec-out',
        'screencap',
        '-p',
      ], stdoutEncoding: null);

      if (result.exitCode != 0) {
        return null;
      }

      return result.stdout as Uint8List;
    } catch (e) {
      _logger.e('Failed to capture screen', error: e);
      return null;
    }
  }

  /// Fetch detailed device properties
  Future<Map<String, String>> getDeviceProperties(
    String deviceId,
    List<String> properties,
  ) async {
    final result = <String, String>{};

    for (final prop in properties) {
      try {
        final value = await getProperty(deviceId, prop);
        if (value.isNotEmpty) {
          result[prop] = value;
        }
      } catch (e) {
        _logger.w('Failed to get property $prop', error: e);
      }
    }

    return result;
  }

  /// Fetch all raw device properties (getprop)
  @override
  Future<Map<String, String>> getFullSystemProperties(String deviceId) async {
    try {
      final result = await _runAdbCommand(['-s', deviceId, 'shell', 'getprop']);

      if (result.exitCode != 0) return {};

      final output = result.stdout.toString();
      final lines = output.split('\n');
      final properties = <String, String>{};

      // Fetch hardware info separately
      properties['cpuInfo'] = await _safeGet(() => getCpuInfo(deviceId));
      properties['ramInfo'] = await _safeGet(() => getRamInfo(deviceId));
      properties['displayResolution'] = await _safeGet(
        () => getDisplayResolution(deviceId),
      );

      final batteryInfo = await getBatteryInfo(deviceId);
      properties['batteryLevel'] = '${batteryInfo['level']}%';
      properties['batteryHealth'] = batteryInfo['health'] ?? 'Unknown';
      properties['batteryStatus'] = batteryInfo['status'] ?? 'Unknown';
      properties['batteryTemp'] = batteryInfo['temperature'] != null
          ? '${(double.parse(batteryInfo['temperature']!) / 10).toStringAsFixed(1)}°C'
          : 'Unknown';

      final storageInfo = await getStorageInfo(deviceId);
      properties['totalStorage'] = storageInfo['total'] ?? 'Unknown';
      properties['availableStorage'] = storageInfo['available'] ?? 'Unknown';

      // Output format: [key]: [value]
      // Relaxed regex to handle potential whitespace variations
      final regex = RegExp(r'\[(.*)\]:\s*\[(.*)\]');

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        final match = regex.firstMatch(line);
        if (match != null) {
          properties[match.group(1)!] = match.group(2)!;
        }
      }

      return properties;
    } catch (e) {
      _logger.e('Failed to get device properties', error: e);
      return {};
    }
  }

  @override
  Future<void> reboot(String deviceId) async {
    await _runAdbCommand(['-s', deviceId, 'reboot']);
  }

  String? _iconCacheDir;

  void setIconCacheDir(String path) {
    _iconCacheDir = path;
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  /// Get list of installed applications with details
  @override
  Future<List<AppInfo>> getInstalledApps(String deviceId) async {
    try {
      // 1. Try to get 3rd party apps first (-3)
      var listResult = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'pm',
        'list',
        'packages',
        '-3',
        '-f',
      ]);

      if (listResult.exitCode != 0 ||
          listResult.stdout.toString().trim().isEmpty) {
        // Fallback: Try getting ALL packages if -3 returned nothing
        _logger.w(
          'No 3rd party apps found or command failed. Trying all packages.',
        );
        listResult = await _runAdbCommand([
          '-s',
          deviceId,
          'shell',
          'pm',
          'list',
          'packages',
          '-f',
        ]);
      }

      if (listResult.exitCode != 0) return [];

      final lines = listResult.stdout.toString().split('\n');
      _logger.i('Found ${lines.length} lines from pm list');

      final basicApps = <String, AppInfo>{};

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final app = AppInfo.fromAdbString(line);
          basicApps[app.packageName] = app;
        } catch (e) {
          // Verify if it's just a warning line or garbage
          if (!line.startsWith('WARNING')) {
            _logger.w('Failed to parse app line: $line', error: e);
          }
        }
      }

      _logger.i('Parsed ${basicApps.length} apps successfully');

      if (basicApps.isEmpty) {
        return [];
      }

      // 2. Fetch app sizes (NEW)
      try {
        await _fetchAppSizes(deviceId, basicApps);
      } catch (e) {
        _logger.w('Failed to fetch app sizes', error: e);
      }

      // 3. Fetch app labels using cmd package
      try {
        await _fetchAppLabels(deviceId, basicApps);
      } catch (e) {
        _logger.w('Failed to fetch app labels', error: e);
      }

      // 4. Populate cached icon paths immediately
      if (_iconCacheDir != null) {
        _populateCachedIcons(basicApps);
        // Start background fetch for missing icons
        _fetchMissingIcons(deviceId, basicApps).catchError((e) {
          _logger.w('Background icon fetch error: $e');
        });
      }

      // 5. Try to fetch details via dumpsys package (heavy operation)
      try {
        final dumpsysResult = await _runAdbCommand([
          '-s',
          deviceId,
          'shell',
          'dumpsys',
          'package',
        ], stdoutEncoding: const Utf8Codec(allowMalformed: true));

        if (dumpsysResult.exitCode == 0) {
          _enrichAppsWithDumpsys(basicApps, dumpsysResult.stdout.toString());
        } else {
          _logger.w(
            'dumpsys package failed with exit code ${dumpsysResult.exitCode}. Returning basic app list.',
          );
        }
      } catch (e) {
        _logger.w(
          'Failed to fetch detailed app info via dumpsys. Returning basic app list.',
          error: e,
        );
        // Do not rethrow, return basic list
      }

      final apps = basicApps.values.toList();
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return apps;
    } catch (e) {
      _logger.e('Failed to get installed apps', error: e);
      return [];
    }
  }

  /// Get detailed information about a specific app
  Future<Map<String, dynamic>> getAppDetails(
    String deviceId,
    String packageName,
  ) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'dumpsys',
        'package',
        packageName,
      ], stdoutEncoding: const Utf8Codec(allowMalformed: true));

      if (result.exitCode != 0) {
        return {};
      }

      final output = result.stdout.toString();
      final details = <String, dynamic>{};
      final permissions = <String>[];

      final lines = output.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();

        // Parse installer
        if (trimmed.startsWith('installerPackageName=')) {
          details['installer'] = trimmed.substring(
            'installerPackageName='.length,
          );
        }
        // Parse last update time
        else if (trimmed.startsWith('lastUpdateTime=')) {
          details['lastUpdateTime'] = trimmed.substring(
            'lastUpdateTime='.length,
          );
        }
        // Parse first install time
        else if (trimmed.startsWith('firstInstallTime=')) {
          details['firstInstallTime'] = trimmed.substring(
            'firstInstallTime='.length,
          );
        }
        // Parse code path (APK location)
        else if (trimmed.startsWith('codePath=')) {
          details['apkPath'] = trimmed.substring('codePath='.length);
        }
        // Parse data directory
        else if (trimmed.startsWith('dataDir=')) {
          details['dataDir'] = trimmed.substring('dataDir='.length);
        }
        // Parse version name
        else if (trimmed.startsWith('versionName=')) {
          details['versionName'] = trimmed.substring('versionName='.length);
        }
        // Parse version code
        else if (trimmed.startsWith('versionCode=')) {
          // Format is often versionCode=123 minSdk=x targetSdk=y
          final parts = trimmed.split(' ');
          for (final part in parts) {
            if (part.startsWith('versionCode=')) {
              details['versionCode'] = part.substring('versionCode='.length);
            } else if (part.startsWith('minSdk=')) {
              details['minSdk'] = part.substring('minSdk='.length);
            } else if (part.startsWith('targetSdk=')) {
              details['targetSdk'] = part.substring('targetSdk='.length);
            }
          }
        }
        // Parse permissions
        else if (trimmed.startsWith('android.permission.')) {
          final perm = trimmed.split(':').first.trim();
          if (!permissions.contains(perm)) {
            permissions.add(perm);
          }
        }
      }

      if (permissions.isNotEmpty) {
        details['permissions'] = permissions;
      }

      return details;
    } catch (e) {
      _logger.e('Failed to get app details for $packageName', error: e);
      return {};
    }
  }

  /// Populate icon paths for apps that are already cached
  void _populateCachedIcons(Map<String, AppInfo> apps) {
    if (_iconCacheDir == null) return;
    for (final packageName in apps.keys) {
      // Always set the path so the UI tries to load it (or shows placeholder/refreshes later)
      // This fixes the issue where icons wouldn't show up even after being downloaded
      // because the path was null.
      final cachePath = '$_iconCacheDir/$packageName.png';
      apps[packageName] = apps[packageName]!.copyWith(iconPath: cachePath);
    }
  }

  /// Batch fetch app sizes using stat -c %s on APK paths
  Future<void> _fetchAppSizes(
    String deviceId,
    Map<String, AppInfo> apps,
  ) async {
    final pathsToPkg = <String, String>{};
    for (final app in apps.values) {
      if (app.apkPath != null && app.apkPath!.isNotEmpty) {
        pathsToPkg[app.apkPath!] = app.packageName;
      }
    }

    if (pathsToPkg.isEmpty) return;

    // Process in chunks to avoid command line length limits
    final paths = pathsToPkg.keys.toList();
    const int chunkSize = 40;

    for (var i = 0; i < paths.length; i += chunkSize) {
      final end = (i + chunkSize < paths.length) ? i + chunkSize : paths.length;
      final chunkPaths = paths.sublist(i, end);

      try {
        // Try stat -c %s first
        var result = await _runAdbCommand([
          '-s',
          deviceId,
          'shell',
          'stat',
          '-c',
          '%s',
          ...chunkPaths,
        ]);

        if (result.exitCode != 0) {
          // Fallback to ls -nl which shows sizes in bytes on most Androids
          result = await _runAdbCommand([
            '-s',
            deviceId,
            'shell',
            'ls',
            '-nl',
            ...chunkPaths,
          ]);

          if (result.exitCode == 0) {
            final output = result.stdout.toString().split('\n');
            for (final line in output) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) continue;
              final parts = trimmed.split(RegExp(r'\s+'));
              // ls -nl output: -rw-r--r-- 1 0 0 [size] [date] [time] [path]
              // size is typically column 4 (0-indexed) or 3 depending on output format
              if (parts.length >= 5) {
                // Try to find the first big numeric part which is likely the size
                for (int p = 3; p < parts.length; p++) {
                  final sizeBytes = int.tryParse(parts[p]);
                  if (sizeBytes != null && sizeBytes > 1024) {
                    final fullLine = trimmed;
                    final pkg = apps.values
                        .firstWhere(
                          (a) =>
                              a.apkPath != null &&
                              fullLine.contains(a.apkPath!),
                          orElse: () => apps.values.first, // fallback
                        )
                        .packageName;

                    if (apps.containsKey(pkg)) {
                      apps[pkg] = apps[pkg]!.copyWith(
                        size: _formatStorage(sizeBytes.toString()),
                      );
                    }
                    break;
                  }
                }
              }
            }
          }
        } else {
          final lines = result.stdout.toString().trim().split('\n');
          int lineIdx = 0;
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            if (lineIdx < chunkPaths.length) {
              final sizeBytes = int.tryParse(trimmed);
              if (sizeBytes != null) {
                final path = chunkPaths[lineIdx];
                final pkg = pathsToPkg[path];
                if (pkg != null && apps.containsKey(pkg)) {
                  apps[pkg] = apps[pkg]!.copyWith(
                    size: _formatStorage(sizeBytes.toString()),
                  );
                }
              }
              lineIdx++;
            }
          }
        }
      } catch (e) {
        _logger.w('Error fetching sizes for chunk $i', error: e);
      }
    }
  }

  /// Fetch missing app icons from device in background
  Future<void> _fetchMissingIcons(
    String deviceId,
    Map<String, AppInfo> apps,
  ) async {
    if (_iconCacheDir == null) return;

    // Check if device supports cmd package get-icon
    // We can just try it.

    for (final packageName in apps.keys) {
      final cachePath = '$_iconCacheDir/$packageName.png';
      final file = File(cachePath);

      // If file exists but is 0 bytes or very small, it's probably corrupted
      if (file.existsSync() && file.lengthSync() < 100) {
        try {
          await file.delete();
        } catch (_) {}
      }

      if (!file.existsSync()) {
        bool iconFound = false;

        // 1. Try cmd package get-icon first (fastest)
        try {
          // Attempt to get icon via cmd package (Android 7+)
          final result = await _runAdbCommand([
            '-s',
            deviceId,
            'shell',
            'cmd',
            'package',
            'get-icon',
            packageName,
          ], stdoutEncoding: null);

          if (result.exitCode == 0 && result.stdout != null) {
            final bytes = result.stdout as Uint8List;
            if (bytes.length > 100) {
              // Valid icons are usually larger than 100 bytes
              await file.writeAsBytes(bytes);
              iconFound = true;
            }
          }
        } catch (_) {}

        // 2. If failed, try extracting from APK (slower but robust)
        if (!iconFound && apps[packageName]?.apkPath != null) {
          await _extractIconFromApk(
            deviceId,
            packageName,
            apps[packageName]!.apkPath!,
            file,
          );
        }
      }
    }
  }

  /// Extracts the app icon directly from the APK file
  Future<void> _extractIconFromApk(
    String deviceId,
    String packageName,
    String remoteApkPath,
    File targetFile,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('apk_extract_');
    final localApkPath = '${tempDir.path}/base.apk';

    try {
      // 1. Pull the APK
      await _runAdbCommand([
        '-s',
        deviceId,
        'pull',
        remoteApkPath,
        localApkPath,
      ]);
      final apkFile = File(localApkPath);
      if (!apkFile.existsSync()) return;

      // 2. List files in APK using unzip
      final result = await Process.run('unzip', ['-l', localApkPath]);
      if (result.exitCode != 0) return;

      final output = result.stdout.toString();
      final lines = output.split('\n');

      // 3. Find the best icon candidate
      // Priority: mipmap-xxxhdpi > mipmap-xxhdpi > ... > drawable-xxxhdpi ...
      // Pattern: res/(mipmap|drawable)-[density]/ic_launcher(|_round).png
      String? bestIconPath;
      int bestScore = -1;

      // Scoring:
      // xxxhdpi: 50, xxhdpi: 40, xhdpi: 30, hdpi: 20, mdpi: 10
      // mipmap: +5, drawable: +0
      // ic_launcher: +2, other: +0
      // round: +1 (adaptive icons often use round)

      final scoreMap = {
        'xxxhdpi': 50,
        'xxhdpi': 40,
        'xhdpi': 30,
        'hdpi': 20,
        'mdpi': 10,
        'anydpi': 5,
      };

      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 4) continue;
        final path = parts.last; // Last part is the filename

        if (!path.endsWith('.png') && !path.endsWith('.webp')) {
          continue; // prefer png/webp
        }
        if (!path.contains('ic_launcher') && !path.contains('icon')) continue;

        int score = 0;

        // Density score
        for (final entry in scoreMap.entries) {
          if (path.contains(entry.key)) {
            score += entry.value;
            break;
          }
        }

        // Type score
        if (path.contains('mipmap')) score += 5;

        // Name score
        if (path.contains('ic_launcher')) score += 2;
        if (path.contains('round')) score += 1;

        if (score > bestScore) {
          bestScore = score;
          bestIconPath = path;
        }
      }

      // 4. Extract the icon
      if (bestIconPath != null) {
        // unzip -p apk path > target
        final extractResult = await Process.run(
          'unzip',
          ['-p', localApkPath, bestIconPath],
          stdoutEncoding: null, // Binary output
        );

        if (extractResult.exitCode == 0) {
          await targetFile.writeAsBytes(extractResult.stdout as Uint8List);
        }
      }
    } catch (e) {
      _logger.w('Failed to extract icon from APK for $packageName', error: e);
    } finally {
      // Cleanup
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Fetch app labels for all apps in the map
  Future<void> _fetchAppLabels(
    String deviceId,
    Map<String, AppInfo> apps,
  ) async {
    // Simple fallback: capitalize package name parts nicely
    for (final entry in apps.entries) {
      // Use simpler approach - capitalize package name parts
      if (apps[entry.key]!.name == entry.key.split('.').last) {
        // Name hasn't been enriched, try to make it prettier
        final nameParts = entry.key.split('.');
        String prettyName = nameParts.last;

        // If last part is "android", try previous part
        // e.g. com.twitter.android -> twitter
        if (prettyName.toLowerCase() == 'android' && nameParts.length > 1) {
          prettyName = nameParts[nameParts.length - 2];
        }

        // Capitalize first letter and add spaces before capitals
        if (prettyName.isNotEmpty) {
          // Split camelCase: "myApp" -> "My App"
          prettyName = prettyName
              .replaceAllMapped(
                RegExp(r'([A-Z])'),
                (match) => ' ${match.group(1)}',
              )
              .trim();
          if (prettyName.isNotEmpty) {
            prettyName = prettyName[0].toUpperCase() + prettyName.substring(1);
          }
        }
        apps[entry.key] = apps[entry.key]!.copyWith(name: prettyName);
      }
    }
  }

  void _enrichAppsWithDumpsys(Map<String, AppInfo> apps, String dumpsysOutput) {
    final lines = dumpsysOutput.split('\n');
    String? currentPackage;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('Package [')) {
        // Package [com.example.app] (hex):
        final start = trimmed.indexOf('[') + 1;
        final end = trimmed.indexOf(']');
        if (start > 0 && end > start) {
          currentPackage = trimmed.substring(start, end);
        } else {
          currentPackage = null;
        }
        continue;
      }

      if (currentPackage != null && apps.containsKey(currentPackage)) {
        // Parse version
        if (trimmed.startsWith('versionName=')) {
          final version = trimmed.substring('versionName='.length);
          apps[currentPackage] = apps[currentPackage]!.copyWith(
            version: version.isNotEmpty ? version : 'Unknown',
          );
        }
        // Parse install date
        else if (trimmed.startsWith('firstInstallTime=')) {
          final dateStr = trimmed.substring('firstInstallTime='.length);
          try {
            apps[currentPackage] = apps[currentPackage]!.copyWith(
              installDate: DateTime.parse(dateStr),
            );
          } catch (_) {}
        }
        // Parse app label/name
        else if (trimmed.startsWith('applicationInfo')) {
          // Look ahead for label
          continue;
        } else if (trimmed.contains('labelRes=0x') ||
            trimmed.contains('nonLocalizedLabel=')) {
          // Extract label if present
          if (trimmed.contains('nonLocalizedLabel=')) {
            final labelStart =
                trimmed.indexOf('nonLocalizedLabel=') +
                'nonLocalizedLabel='.length;
            var label = trimmed.substring(labelStart).trim();
            // Remove trailing attributes
            final spaceIdx = label.indexOf(' ');
            if (spaceIdx > 0) {
              label = label.substring(0, spaceIdx);
            }
            if (label.isNotEmpty && label != 'null') {
              apps[currentPackage] = apps[currentPackage]!.copyWith(
                name: label,
              );
            }
          }
        }
      }
    }
  }

  /// Fetch all standard device properties including CPU and RAM
  Future<Map<String, String>> getAllDeviceProperties(String deviceId) async {
    final properties = [
      'ro.product.manufacturer',
      'ro.product.model',
      'ro.product.brand',
      'ro.product.device',
      'ro.build.version.release',
      'ro.build.version.sdk',
      'ro.serialno',
    ];

    Map<String, String> props = {};
    try {
      props = await getDeviceProperties(deviceId, properties);
      _logger.i('Fetched ${props.length} device properties');
    } catch (e) {
      _logger.w('Failed to get basic device properties', error: e);
    }

    // Fetch additional info safely
    props['cpuInfo'] = await _safeGet(() => getCpuInfo(deviceId));
    props['ramInfo'] = await _safeGet(() => getRamInfo(deviceId));

    return props;
  }

  Future<String> _safeGet(Future<String> Function() fetcher) async {
    try {
      return await fetcher();
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Get CPU information
  Future<String> getCpuInfo(String deviceId) async {
    try {
      // 1. Try system properties first (more reliable on modern Android)
      final chipname = await getProperty(deviceId, 'ro.chipname');
      if (chipname.isNotEmpty && chipname != 'Unknown') return chipname;

      final platform = await getProperty(deviceId, 'ro.board.platform');
      if (platform.isNotEmpty && platform != 'Unknown') {
        // Platform often gives the chipset family, check hardware too
        final hardware = await getProperty(deviceId, 'ro.hardware');
        if (hardware.isNotEmpty &&
            hardware != 'Unknown' &&
            hardware != platform) {
          return '$hardware ($platform)';
        }
        return platform;
      }

      // 2. Fallback to /proc/cpuinfo
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'cat',
        '/proc/cpuinfo',
      ]);

      if (result.exitCode != 0) return 'Unknown';

      final output = result.stdout.toString();
      final lines = output.split('\n');

      // Try to find Hardware field
      for (final line in lines) {
        if (line.trim().startsWith('Hardware')) {
          final val = line.split(':')[1].trim();
          if (val.isNotEmpty) return val;
        }
      }

      // 3. Fallback to model name
      for (final line in lines) {
        if (line.trim().startsWith('model name')) {
          final val = line.split(':')[1].trim();
          if (val.isNotEmpty) return val;
        }
      }

      // 4. Fallback to processor architecture/count
      int cores = 0;
      String arch = '';
      for (final line in lines) {
        if (line.trim().startsWith('processor')) cores++;
        if (line.trim().startsWith('Features') && arch.isEmpty) {
          if (line.contains('arm64')) {
            arch = 'ARM64';
          } else if (line.contains('v7')) {
            arch = 'ARMv7';
          }
        }
      }

      if (cores > 0) {
        return arch.isNotEmpty ? '$arch ($cores cores)' : '$cores cores';
      }

      return 'Unknown';
    } catch (e) {
      _logger.w('Failed to get CPU info', error: e);
      return 'Unknown';
    }
  }

  /// Get RAM information
  Future<String> getRamInfo(String deviceId) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'cat',
        '/proc/meminfo',
      ]);

      if (result.exitCode != 0) return 'Unknown';

      final output = result.stdout.toString();
      final lines = output.split('\n');
      for (final line in lines) {
        if (line.trim().startsWith('MemTotal:')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            return _formatStorage('${parts[1]}kB'); // meminfo is usually in kB
          }
        }
      }

      return 'Unknown';
    } catch (e) {
      _logger.w('Failed to get RAM info', error: e);
      return 'Unknown';
    }
  }

  /// Get battery information
  Future<Map<String, dynamic>> getBatteryInfo(String deviceId) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'dumpsys',
        'battery',
      ]);

      if (result.exitCode != 0) {
        return {'level': 0, 'isCharging': false};
      }

      final output = result.stdout.toString();
      final lines = output.split('\n');

      int level = 0;
      bool isCharging = false;
      String? health;
      String? status;
      String? temperature;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('level:')) {
          level = int.tryParse(trimmed.split(':')[1].trim()) ?? 0;
        } else if (trimmed.startsWith('status:')) {
          final val = trimmed.split(':')[1].trim();
          status = val;
          isCharging = val == '2' || val.toLowerCase() == 'charging';
        } else if (trimmed.startsWith('health:')) {
          health = trimmed.split(':')[1].trim();
        } else if (trimmed.startsWith('temperature:')) {
          temperature = trimmed.split(':')[1].trim();
        }
      }

      return {
        'level': level,
        'isCharging': isCharging,
        'health': _parseBatteryHealth(health),
        'status': _parseBatteryStatus(status),
        'temperature': temperature,
      };
    } catch (e) {
      _logger.w('Failed to get battery info', error: e);
      return {'level': 0, 'isCharging': false};
    }
  }

  String _parseBatteryHealth(String? health) {
    switch (health) {
      case '2':
        return 'Good';
      case '3':
        return 'Overheat';
      case '4':
        return 'Dead';
      case '5':
        return 'Over Voltage';
      case '6':
        return 'Unspecified Failure';
      case '7':
        return 'Cold';
      default:
        return health ?? 'Unknown';
    }
  }

  String _parseBatteryStatus(String? status) {
    switch (status) {
      case '1':
        return 'Unknown';
      case '2':
        return 'Charging';
      case '3':
        return 'Discharging';
      case '4':
        return 'Not Charging';
      case '5':
        return 'Full';
      default:
        return status ?? 'Unknown';
    }
  }

  /// Get storage information
  Future<Map<String, String>> getStorageInfo(String deviceId) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'df',
        '-k', // Ensure units are in KB
        '/data',
      ]);

      if (result.exitCode != 0) {
        return {'total': 'Unknown', 'available': 'Unknown'};
      }

      final output = result.stdout.toString();
      final lines = output.split('\n');

      // Skip header
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(RegExp(r'\s+'));

        // Handle line wrapping where filesystem is on one line and metrics on the next
        if (parts.length == 1 && i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final nextParts = nextLine.split(RegExp(r'\s+'));
          if (nextParts.length >= 3) {
            return {
              'total': _formatStorage('${nextParts[0]}K'),
              'available': _formatStorage('${nextParts[2]}K'),
            };
          }
        }

        if (parts.length >= 4) {
          // If the first part is /data or equivalent
          if (line.contains('/data')) {
            return {
              'total': _formatStorage('${parts[1]}K'),
              'available': _formatStorage('${parts[3]}K'),
            };
          }
        }
      }

      return {'total': 'Unknown', 'available': 'Unknown'};
    } catch (e) {
      _logger.w('Failed to get storage info', error: e);
      return {'total': 'Unknown', 'available': 'Unknown'};
    }
  }

  /// Get display resolution
  Future<String> getDisplayResolution(String deviceId) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'wm',
        'size',
      ]);

      if (result.exitCode != 0) {
        return 'Unknown';
      }

      final output = result.stdout.toString().trim();
      // Output format: "Physical size: 1080x2400"
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(output);
      if (match != null) {
        return '${match.group(1)}x${match.group(2)}';
      }

      return 'Unknown';
    } catch (e) {
      _logger.w('Failed to get display resolution', error: e);
      return 'Unknown';
    }
  }

  String _formatStorage(String bytes) {
    try {
      // Remove any non-digit characters at the end (K, M, G, etc.) and spaces
      String input = bytes.trim().toUpperCase();
      double multiplier = 1.0;
      String numericPart = input;

      if (input.endsWith('KB') || input.endsWith('K')) {
        numericPart = input.replaceAll('KB', '').replaceAll('K', '').trim();
        multiplier = 1024.0;
      } else if (input.endsWith('MB') || input.endsWith('M')) {
        numericPart = input.replaceAll('MB', '').replaceAll('M', '').trim();
        multiplier = 1024.0 * 1024.0;
      } else if (input.endsWith('GB') || input.endsWith('G')) {
        numericPart = input.replaceAll('GB', '').replaceAll('G', '').trim();
        multiplier = 1024.0 * 1024.0 * 1024.0;
      } else if (input.endsWith('TB') || input.endsWith('T')) {
        numericPart = input.replaceAll('TB', '').replaceAll('T', '').trim();
        multiplier = 1024.0 * 1024.0 * 1024.0 * 1024.0;
      } else if (input.endsWith('B')) {
        numericPart = input.replaceAll('B', '').trim();
        multiplier = 1.0;
      }

      final value = double.tryParse(numericPart);
      if (value == null) return bytes;

      final totalBytes = value * multiplier;

      if (totalBytes < 1024) return '${totalBytes.toStringAsFixed(0)} B';
      if (totalBytes < 1024 * 1024) {
        return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      }
      if (totalBytes < 1024 * 1024 * 1024) {
        return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      if (totalBytes < 1024.0 * 1024 * 1024 * 1024) {
        return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
      return '${(totalBytes / (1024.0 * 1024 * 1024 * 1024)).toStringAsFixed(1)} TB';
    } catch (e) {
      return bytes;
    }
  }

  /// Push a file to the device
  @override
  Future<bool> pushFile(
    String deviceId,
    String localPath,
    String remotePath,
  ) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'push',
        localPath,
        remotePath,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      _logger.e('Failed to push file: $localPath to $remotePath', error: e);
      return false;
    }
  }

  /// Pull a file from the device
  @override
  Future<bool> pullFile(
    String deviceId,
    String remotePath,
    String localPath,
  ) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'pull',
        remotePath,
        localPath,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      _logger.e('Failed to pull file: $remotePath to $localPath', error: e);
      return false;
    }
  }

  /// List contents of a directory on the device
  @override
  Future<List<String>> listDirectory(String deviceId, String remotePath) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'ls',
        '-p',
        remotePath,
      ]);

      if (result.exitCode != 0) {
        return [];
      }

      final output = result.stdout.toString();
      return output
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      _logger.e('Failed to list directory: $remotePath', error: e);
      return [];
    }
  }

  /// Sends a key event to the device
  Future<bool> sendKeyEvent(String deviceId, int keyCode) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'input',
        'keyevent',
        keyCode.toString(),
      ]);
      return result.exitCode == 0;
    } catch (e) {
      _logger.e('Failed to send key event: $keyCode', error: e);
      return false;
    }
  }

  /// Adjusts the device volume
  Future<bool> adjustVolume(String deviceId, bool up) async {
    final keyCode = up ? 24 : 25; // KEYCODE_VOLUME_UP : KEYCODE_VOLUME_DOWN
    return sendKeyEvent(deviceId, keyCode);
  }

  /// Toggles the power button
  Future<bool> pressPower(String deviceId) async {
    return sendKeyEvent(deviceId, 26); // KEYCODE_POWER
  }

  /// Install an APK manually
  @override
  Future<bool> installApp(String deviceId, String apkPath) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'install',
        '-r',
        apkPath,
      ]);
      return result.exitCode == 0 &&
          result.stdout.toString().contains('Success');
    } catch (e) {
      _logger.e('Failed to install app: $apkPath', error: e);
      return false;
    }
  }

  /// Backup (Pull) an application APK
  Future<String?> pullApp(
    String deviceId,
    String packageName,
    String localDir,
  ) async {
    try {
      // 1. Get path
      final pathResult = await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'pm',
        'path',
        packageName,
      ]);
      if (pathResult.exitCode != 0) return null;

      // Output: package:/data/app/~~.../base.apk
      final rawPath = pathResult.stdout.toString().trim();
      if (!rawPath.startsWith('package:')) return null;

      final remotePath = rawPath.replaceAll('package:', '').trim();
      final fileName = '$packageName.apk';
      final localPath = '$localDir/$fileName';

      // 2. Pull
      final success = await pullFile(deviceId, remotePath, localPath);
      return success ? localPath : null;
    } catch (e) {
      _logger.e('Failed to backup app: $packageName', error: e);
      return null;
    }
  }

  /// Uninstall an application
  @override
  Future<bool> uninstallApp(String deviceId, String packageName) async {
    try {
      final result = await _runAdbCommand([
        '-s',
        deviceId,
        'uninstall',
        packageName,
      ]);
      return result.exitCode == 0 &&
          !result.stdout.toString().contains('Failure');
    } catch (e) {
      _logger.e('Failed to uninstall app: $packageName', error: e);
      return false;
    }
  }

  Future<void> swipe(
    String deviceId,
    List<Point<int>> points, {
    int duration = 300,
  }) async {
    if (points.length < 2) return;

    try {
      // 1. Wake up screen if it's off
      await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'input',
        'keyevent',
        '224',
      ]);

      // Small pause to allow screen to turn on
      await Future.delayed(const Duration(milliseconds: 200));

      if (points.length == 2) {
        // Standard 2-point swipe
        await _runAdbCommand([
          '-s',
          deviceId,
          'shell',
          'input',
          'swipe',
          points[0].x.toString(),
          points[0].y.toString(),
          points[1].x.toString(),
          points[1].y.toString(),
          duration.toString(),
        ]);
      } else {
        // Multi-point path (e.g., Pattern Unlock)
        // Combine multiple motionevent commands into a single shell call for speed and continuity.
        // We use 'input swipe' for better compatibility on older devices if needed,
        // but motionevent is superior for complex patterns on Android 12+.
        // Let's try to detect if we need to swipe up first to show the pattern grid.

        await _runAdbCommand([
          '-s',
          deviceId,
          'shell',
          'input',
          'swipe',
          '500',
          '1000',
          '500',
          '100',
        ]);

        await Future.delayed(const Duration(milliseconds: 300));

        final commands = <String>[];
        commands.add(
          'input motionevent DOWN ${points.first.x} ${points.first.y}',
        );

        for (int i = 1; i < points.length; i++) {
          commands.add('input motionevent MOVE ${points[i].x} ${points[i].y}');
        }

        commands.add('input motionevent UP ${points.last.x} ${points.last.y}');

        // Wrap in a single shell string for speed and continuity
        final shellCmd = commands.join(' && ');
        await _runAdbCommand(['-s', deviceId, 'shell', shellCmd]);
      }
    } catch (e) {
      _logger.e('Failed to swipe', error: e);
    }
  }

  Future<void> unlockDevice(String deviceId, String pin) async {
    try {
      // 1. Wake up device
      await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'input',
        'keyevent',
        '224',
      ]);

      // 2. Swipe up to show pin pad (generic swipe up)
      await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'input',
        'swipe',
        '500',
        '1000',
        '500',
        '100',
      ]);

      // 3. Enter PIN text
      await _runAdbCommand(['-s', deviceId, 'shell', 'input', 'text', pin]);

      // 4. Press Enter
      await _runAdbCommand([
        '-s',
        deviceId,
        'shell',
        'input',
        'keyevent',
        '66',
      ]);
    } catch (e) {
      _logger.e('Failed to unlock device', error: e);
      rethrow;
    }
  }

  @override
  void dispose() {
    if (_adbPath != null) {
      _runAdbCommand(['kill-server']);
    }
  }
}
