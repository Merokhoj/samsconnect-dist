import 'dart:io';

import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import '../../data/models/device.dart';
import '../../data/models/app_info.dart';
import 'base_mobile_service.dart';

class IosService implements BaseMobileService {
  final Logger _logger = Logger();
  final Map<String, String> _mountPoints = {};

  String _getMountPath(String deviceId) => '/tmp/console_ios_$deviceId';

  @override
  MobilePlatform get platform => MobilePlatform.ios;

  @override
  Future<void> initialize() async {
    // Check if libimobiledevice is installed
    try {
      // Check for either idevice_id (newer) or idevicelist (older)
      final checkId = await Process.run('which', ['idevice_id']);
      final checkList = await Process.run('which', ['idevicelist']);

      if (checkId.exitCode != 0 && checkList.exitCode != 0) {
        _logger.w(
          'libimobiledevice (idevice_id or idevicelist) not found. iOS devices will not be detected. Install with: sudo apt install libimobiledevice6 libimobiledevice-utils',
        );
        return; // Don't throw, just warn
      }
      _logger.i('IosService initialized successfully');
    } catch (e) {
      _logger.w('Failed to initialize iOS service (non-fatal)', error: e);
    }
  }

  @override
  Future<List<Device>> getDevices() async {
    try {
      // Try idevice_id -l first (newer), then idevicelist -u (older)
      ProcessResult result;
      try {
        result = await Process.run('idevice_id', ['-l']);
        if (result.exitCode != 0) {
          result = await Process.run('idevicelist', ['-u']);
        }
      } catch (e) {
        result = await Process.run('idevicelist', ['-u']);
      }

      if (result.exitCode != 0) {
        return [];
      }

      final udids = result.stdout
          .toString()
          .split('\n')
          .where((s) => s.trim().isNotEmpty);
      final devices = <Device>[];

      for (final udid in udids) {
        try {
          // Get basic info for each device
          final infoResult = await Process.run('ideviceinfo', [
            '-u',
            udid,
            '-s',
          ]);
          if (infoResult.exitCode == 0) {
            devices.add(
              Device.fromIosString(
                'UniqueDeviceID: $udid\n${infoResult.stdout}',
              ),
            );
          } else {
            // Fallback for minimal info
            devices.add(
              Device(
                id: udid,
                name: 'iOS Device',
                model: 'iPhone',
                osVersion: 'Unknown',
                platform: MobilePlatform.ios,
                method: ConnectionMethod.usb,
              ),
            );
          }
        } catch (e) {
          _logger.w('Failed to get info for iOS device $udid', error: e);
        }
      }

      return devices;
    } catch (e) {
      _logger.e('Error listing iOS devices', error: e);
      return [];
    }
  }

  @override
  Future<Map<String, String>> getFullSystemProperties(String deviceId) async {
    try {
      final result = await Process.run('ideviceinfo', ['-u', deviceId]);
      if (result.exitCode != 0) return {};

      final lines = result.stdout.toString().split('\n');
      final props = <String, String>{};

      for (var line in lines) {
        if (line.contains(':')) {
          final firstColonIndex = line.indexOf(':');
          final key = line.substring(0, firstColonIndex).trim();
          final value = line.substring(firstColonIndex + 1).trim();
          props[key] = value;
        }
      }

      // Fetch disk usage info
      try {
        final diskResult = await Process.run('ideviceinfo', [
          '-u',
          deviceId,
          '-q',
          'com.apple.disk_usage',
        ]);
        if (diskResult.exitCode == 0) {
          final diskLines = diskResult.stdout.toString().split('\n');
          for (var line in diskLines) {
            if (line.contains(':')) {
              final parts = line.split(':');
              final key = parts[0].trim();
              final value = parts.sublist(1).join(':').trim();
              props['disk.$key'] = value;
            }
          }
        }
      } catch (e) {
        _logger.w('Failed to get disk usage for $deviceId');
      }

      final productType = props['ProductType'] ?? '';
      final modelInfo = _getIosHardwareInfo(productType);

      // Map common properties for DeviceInfo.fromMap compatibility
      props['manufacturer'] = 'Apple';
      props['brand'] = 'Apple';
      props['model'] = modelInfo.name;
      props['osVersion'] = props['ProductVersion'] ?? 'Unknown';
      props['serialNumber'] = props['SerialNumber'] ?? deviceId;
      props['deviceName'] = props['DeviceName'] ?? 'iPhone';
      props['sdkVersion'] = props['ProductVersion'] ?? 'Unknown';
      props['cpuInfo'] = props['CPUArchitecture'] ?? 'arm64';
      props['ramInfo'] = modelInfo.ram;
      props['displayResolution'] = modelInfo.resolution;

      // Storage calculation
      if (props.containsKey('disk.TotalDiskCapacity') ||
          props.containsKey('disk.TotalDataCapacity')) {
        // Prefer TotalDiskCapacity for the hardware total, fallback to TotalDataCapacity
        final totalRaw =
            props['disk.TotalDiskCapacity'] ?? props['disk.TotalDataCapacity']!;
        final availRaw = props['disk.TotalDataAvailable'] ?? '0';

        final total = int.tryParse(totalRaw) ?? 0;
        final avail = int.tryParse(availRaw) ?? 0;

        props['totalStorage'] =
            '${(total / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
        props['availableStorage'] =
            '${(avail / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }

      return props;
    } catch (e) {
      _logger.e('Failed to get iOS device properties', error: e);
      return {};
    }
  }

  @override
  Future<List<AppInfo>> getInstalledApps(String deviceId) async {
    try {
      final userApps = await _fetchApps(deviceId, '-l'); // User apps
      final systemApps = await _fetchApps(
        deviceId,
        '-l -o list_system',
      ); // System apps

      return [
        ...userApps.map((a) => a.copyWith(isSystemApp: false)),
        ...systemApps.map((a) => a.copyWith(isSystemApp: true)),
      ];
    } catch (e) {
      _logger.e('Error listing iOS apps', error: e);
      return [];
    }
  }

  Future<List<AppInfo>> _fetchApps(String deviceId, String listFlag) async {
    try {
      // ideviceinstaller -u <deviceId> <listFlag>
      final flags = listFlag.split(' ');
      final result = await Process.run('ideviceinstaller', [
        '-u',
        deviceId,
        ...flags,
      ]);

      if (result.exitCode != 0) return [];

      final lines = result.stdout.toString().split('\n');
      final apps = <AppInfo>[];

      for (var line in lines) {
        if (line.startsWith('Total:') ||
            line.contains('CFBundleIdentifier') ||
            line.trim().isEmpty) {
          continue;
        }

        final parts = line.split(',').map((s) => s.trim()).toList();
        if (parts.length >= 3) {
          apps.add(
            AppInfo(
              name: parts[2].replaceAll('"', ''),
              packageName: parts[0].replaceAll('"', ''),
              version: parts[1].replaceAll('"', ''),
              isSystemApp: false, // Will be overridden by caller
            ),
          );
        }
      }

      return apps;
    } catch (e) {
      _logger.w('Failed to fetch apps with flag $listFlag', error: e);
      return [];
    }
  }

  @override
  Future<Uint8List?> getScreenCapture(String deviceId) async {
    // Screen capture for iOS is not directly available via command line in a simple way
    // like ADB. Usually requires mounting developer images and using idevicescreenshot.
    try {
      final result = await Process.run(
          'idevicescreenshot',
          [
            '-u',
            deviceId,
            '-',
          ],
          stdoutEncoding: null); // Use null for raw binary output

      if (result.exitCode == 0) {
        final stdout = result.stdout;
        if (stdout is Uint8List) return stdout;
        if (stdout is List<int>) return Uint8List.fromList(stdout);
      }
    } catch (e) {
      _logger.w(
        'iOS screenshot failed (idevicescreenshot might be missing or image not mounted)',
        error: e,
      );
    }
    return null;
  }

  @override
  Future<bool> installApp(String deviceId, String filePath) async {
    final result = await Process.run('ideviceinstaller', [
      '-u',
      deviceId,
      '-i',
      filePath,
    ]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> uninstallApp(String deviceId, String packageName) async {
    final result = await Process.run('ideviceinstaller', [
      '-u',
      deviceId,
      '-U',
      packageName,
    ]);
    return result.exitCode == 0;
  }

  @override
  Future<void> reboot(String deviceId) async {
    await Process.run('idevicediagnostics', ['-u', deviceId, 'restart']);
  }

  @override
  Future<List<String>> listDirectory(String deviceId, String path) async {
    try {
      final mountPath = await _ensureMounted(deviceId);
      if (mountPath == null) return [];

      // Convert virtual path to local mount path
      // Virtual paths for iOS: /Media -> <mountPath>
      String localPath;
      if (path.startsWith('/Media')) {
        localPath = path.replaceFirst('/Media', mountPath);
      } else {
        localPath = p.join(
          mountPath,
          path.startsWith('/') ? path.substring(1) : path,
        );
      }

      // Improved robustness: retry listing if it fails with I/O error
      int retries = 3;
      while (retries > 0) {
        try {
          final dir = Directory(localPath);
          if (!await dir.exists()) return [];

          final entities = await dir.list().toList();
          return entities.map((e) {
            final name = p.basename(e.path);
            return e is Directory ? '$name/' : name;
          }).toList();
        } catch (e) {
          _logger.w(
            'iOS listDirectory failed (${4 - retries}), retrying...',
            error: e,
          );
          await Future.delayed(const Duration(milliseconds: 1000));
          retries--;
          // If input/output error, it might be that fusermount needs a reload or wait
          if (retries == 0) rethrow;
        }
      }
      return [];
    } catch (e) {
      _logger.e('Failed to list iOS directory', error: e);
      return [];
    }
  }

  @override
  Future<bool> pushFile(
    String deviceId,
    String localPath,
    String remotePath,
  ) async {
    try {
      final mountPath = await _ensureMounted(deviceId);
      if (mountPath == null) return false;

      String targetPath;
      if (remotePath.startsWith('/Media')) {
        targetPath = remotePath.replaceFirst('/Media', mountPath);
      } else {
        targetPath = p.join(
          mountPath,
          remotePath.startsWith('/') ? remotePath.substring(1) : remotePath,
        );
      }

      final file = File(localPath);
      if (!await file.exists()) return false;

      await file.copy(targetPath);
      return true;
    } catch (e) {
      _logger.e('Failed to push file to iOS', error: e);
      return false;
    }
  }

  @override
  Future<bool> pullFile(
    String deviceId,
    String remotePath,
    String localPath,
  ) async {
    try {
      final mountPath = await _ensureMounted(deviceId);
      if (mountPath == null) return false;

      String sourcePath;
      if (remotePath.startsWith('/Media')) {
        sourcePath = remotePath.replaceFirst('/Media', mountPath);
      } else {
        sourcePath = p.join(
          mountPath,
          remotePath.startsWith('/') ? remotePath.substring(1) : remotePath,
        );
      }

      final file = File(sourcePath);
      if (!await file.exists()) return false;

      await file.copy(localPath);
      return true;
    } catch (e) {
      _logger.e('Failed to pull file from iOS', error: e);
      return false;
    }
  }

  Future<String?> _ensureMounted(String deviceId) async {
    if (_mountPoints.containsKey(deviceId)) {
      return _mountPoints[deviceId];
    }

    final mountPath = _getMountPath(deviceId);

    // Attempt to clear any stale FUSE mounts before doing any directory operations.
    // Stale mounts cause "Input/output error" on the directory itself.
    try {
      await Process.run('fusermount', ['-uz', mountPath]);
      // Small delay to allow the kernel to clean up the mount entry
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (_) {}

    final dir = Directory(mountPath);
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      _logger.e('Failed to create mount directory: $mountPath', error: e);
      return null;
    }

    try {
      // Try to mount Media folder
      // We use --container or --documents for apps, but for general media access
      // we just use the default which mounts the Media directory.
      final result = await Process.run('ifuse', [mountPath, '-u', deviceId]);
      if (result.exitCode == 0) {
        // Small wait to ensure fuse is actually ready
        await Future.delayed(const Duration(milliseconds: 500));
        _mountPoints[deviceId] = mountPath;
        return mountPath;
      } else {
        _logger.e('ifuse mount failed: ${result.stderr}');
        // If it fails because it's already mounted, we might be lucky
        if (result.stderr.toString().contains('already mounted')) {
          _mountPoints[deviceId] = mountPath;
          return mountPath;
        }
        return null;
      }
    } catch (e) {
      _logger.e('Failed to run ifuse', error: e);
      return null;
    }
  }

  Future<void> _unmount(String deviceId) async {
    if (_mountPoints.containsKey(deviceId)) {
      final mountPath = _mountPoints[deviceId]!;
      try {
        await Process.run('fusermount', ['-u', mountPath]);
        _mountPoints.remove(deviceId);
      } catch (e) {
        _logger.e('Failed to unmount $mountPath', error: e);
      }
    }
  }

  _IosHardwareInfo _getIosHardwareInfo(String productType) {
    const map = {
      'iPhone10,1': _IosHardwareInfo('iPhone 8', '2 GB', '1334x750'),
      'iPhone10,4': _IosHardwareInfo('iPhone 8', '2 GB', '1334x750'),
      'iPhone10,2': _IosHardwareInfo('iPhone 8 Plus', '3 GB', '1920x1080'),
      'iPhone10,5': _IosHardwareInfo('iPhone 8 Plus', '3 GB', '1920x1080'),
      'iPhone10,3': _IosHardwareInfo('iPhone X', '3 GB', '2436x1125'),
      'iPhone10,6': _IosHardwareInfo('iPhone X', '3 GB', '2436x1125'),
      'iPhone11,2': _IosHardwareInfo('iPhone XS', '4 GB', '2436x1125'),
      'iPhone11,4': _IosHardwareInfo('iPhone XS Max', '4 GB', '2688x1242'),
      'iPhone11,6': _IosHardwareInfo('iPhone XS Max', '4 GB', '2688x1242'),
      'iPhone11,8': _IosHardwareInfo('iPhone XR', '3 GB', '1792x828'),
      'iPhone12,1': _IosHardwareInfo('iPhone 11', '4 GB', '1792x828'),
      'iPhone12,3': _IosHardwareInfo('iPhone 11 Pro', '4 GB', '2436x1125'),
      'iPhone12,5': _IosHardwareInfo('iPhone 11 Pro Max', '4 GB', '2688x1242'),
      'iPhone12,8': _IosHardwareInfo('iPhone SE (2nd Gen)', '3 GB', '1334x750'),
      'iPhone13,1': _IosHardwareInfo('iPhone 12 mini', '4 GB', '2340x1080'),
      'iPhone13,2': _IosHardwareInfo('iPhone 12', '4 GB', '2532x1170'),
      'iPhone13,3': _IosHardwareInfo('iPhone 12 Pro', '6 GB', '2532x1170'),
      'iPhone13,4': _IosHardwareInfo('iPhone 12 Pro Max', '6 GB', '2778x1284'),
      'iPhone14,2': _IosHardwareInfo('iPhone 13 Pro', '6 GB', '2532x1170'),
      'iPhone14,3': _IosHardwareInfo('iPhone 13 Pro Max', '6 GB', '2778x1284'),
      'iPhone14,4': _IosHardwareInfo('iPhone 13 mini', '4 GB', '2340x1080'),
      'iPhone14,5': _IosHardwareInfo('iPhone 13', '4 GB', '2532x1170'),
      'iPhone14,6': _IosHardwareInfo('iPhone SE (3rd Gen)', '4 GB', '1334x750'),
      'iPhone14,7': _IosHardwareInfo('iPhone 14', '6 GB', '2532x1170'),
      'iPhone14,8': _IosHardwareInfo('iPhone 14 Plus', '6 GB', '2778x1284'),
      'iPhone15,2': _IosHardwareInfo('iPhone 14 Pro', '6 GB', '2556x1179'),
      'iPhone15,3': _IosHardwareInfo('iPhone 14 Pro Max', '6 GB', '2796x1290'),
      'iPhone15,4': _IosHardwareInfo('iPhone 15', '6 GB', '2556x1179'),
      'iPhone15,5': _IosHardwareInfo('iPhone 15 Plus', '6 GB', '2796x1290'),
      'iPhone16,1': _IosHardwareInfo('iPhone 15 Pro', '8 GB', '2556x1179'),
      'iPhone16,2': _IosHardwareInfo('iPhone 15 Pro Max', '8 GB', '2796x1290'),
      'iPhone17,1': _IosHardwareInfo('iPhone 16 Pro', '8 GB', '2622x1206'),
      'iPhone17,2': _IosHardwareInfo('iPhone 16 Pro Max', '8 GB', '2868x1320'),
      'iPhone17,3': _IosHardwareInfo('iPhone 16', '8 GB', '2556x1179'),
      'iPhone17,4': _IosHardwareInfo('iPhone 16 Plus', '8 GB', '2796x1290'),
    };

    return map[productType] ??
        _IosHardwareInfo(productType, 'Unknown', 'Unknown');
  }

  @override
  void dispose() {
    for (final deviceId in _mountPoints.keys.toList()) {
      _unmount(deviceId);
    }
  }
}

class _IosHardwareInfo {
  final String name;
  final String ram;
  final String resolution;
  const _IosHardwareInfo(this.name, this.ram, this.resolution);
}
