import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'dart:math';
import '../services/connection/adb_service.dart';
import '../services/connection/connection_history_service.dart';
import '../data/models/device.dart';
import '../data/models/device_info.dart';
import '../data/models/app_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'dart:async';

import '../services/connection/base_mobile_service.dart';

class ConnectionProvider with ChangeNotifier {
  final Map<MobilePlatform, BaseMobileService> _services;
  final ConnectionHistoryService _historyService = ConnectionHistoryService();

  final Logger _logger = Logger();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  Device? _connectedDevice;
  List<Device> _availableDevices = [];
  List<Device> _savedDevices = [];
  String? _errorMessage;
  bool _isLoading = false;
  Timer? _devicePollTimer;

  // Notification callback for UI
  Function(String message)? onDeviceChanged;

  ConnectionProvider(List<BaseMobileService> services)
    : _services = {for (var s in services) s.platform: s};

  ConnectionStatus get status => _status;
  Device? get connectedDevice => _connectedDevice;
  List<Device> get availableDevices => _availableDevices;
  List<Device> get savedDevices => _savedDevices;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  BaseMobileService? getService(MobilePlatform platform) => _services[platform];
  AdbService get adbService => _services[MobilePlatform.android] as AdbService;

  Future<void> initialize() async {
    try {
      // Small delay to ensure we are out of the build phase
      await Future.microtask(() {});
      _isLoading = true;
      notifyListeners();

      for (var service in _services.values) {
        await service.initialize();
      }

      // Setup App Icon Cache (Still uses ADB service for now as it has the logic)
      final appDir = await getApplicationSupportDirectory();
      final iconCachePath = p.join(appDir.path, 'app_icons');
      adbService.setIconCacheDir(iconCachePath);

      await _loadSavedDevices();
      await refreshDevices();

      // Try to auto-connect to last device if enabled
      await _tryAutoConnect();

      // Start polling for device changes
      _startDevicePolling();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startDevicePolling() {
    _devicePollTimer?.cancel();
    _devicePollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkForDeviceChanges();
    });
  }

  Future<void> _checkForDeviceChanges() async {
    try {
      // Fetch list from all services
      final currentDevices = <Device>[];
      for (var service in _services.values) {
        currentDevices.addAll(await service.getDevices());
      }

      // Check if list changed by comparing IDs
      final currentIds = currentDevices.map((d) => d.id).toSet();
      final previousIds = _availableDevices.map((d) => d.id).toSet();

      if (currentIds.length != previousIds.length ||
          !currentIds.containsAll(previousIds)) {
        // Identify changes for notification
        final newIds = currentIds.difference(previousIds);
        final removedIds = previousIds.difference(currentIds);

        if (newIds.isNotEmpty) {
          final newDevices = currentDevices.where((d) => newIds.contains(d.id));
          for (final d in newDevices) {
            _logger.i('New device detected: ${d.name} (${d.id})');
            onDeviceChanged?.call('${d.name} Connected');
          }
        }
        if (removedIds.isNotEmpty) {
          final removedDevices = _availableDevices.where(
            (d) => removedIds.contains(d.id),
          );
          for (final d in removedDevices) {
            _logger.i('Device disconnected: ${d.name} (${d.id})');
            onDeviceChanged?.call('${d.name} Disconnected');
          }

          // If the connected device was removed, update status
          if (_connectedDevice != null &&
              removedIds.contains(_connectedDevice!.id)) {
            _connectedDevice = null;
            _status = ConnectionStatus.disconnected;
            notifyListeners();
          }
        }

        // Refresh full details
        await refreshDevices();
      }
    } catch (e) {
      // Silent error during polling to avoid spamming
      _logger.d('Poll error: $e');
    }
  }

  Future<void> _loadSavedDevices() async {
    _savedDevices = await _historyService.getAllDevices();
    notifyListeners();
  }

  Future<void> _tryAutoConnect() async {
    final lastDevice = await _historyService.getLastConnectedDevice();
    if (lastDevice != null && lastDevice.isWireless) {
      // Try to reconnect to last WiFi device
      try {
        await connectWifi(lastDevice.ipAddress!);
      } catch (e) {
        _logger.w('Failed to auto-connect to ${lastDevice.id}', error: e);
      }
    }
  }

  Future<void> refreshDevices() async {
    try {
      // Don't set isLoading during auto-refresh to avoid flickering
      // Only set it if list is empty (initial load)
      if (_availableDevices.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }

      final allDevices = <Device>[];
      for (var service in _services.values) {
        final platformDevices = await service.getDevices();
        allDevices.addAll(platformDevices);
      }

      // Fetch detailed info for each device
      final detailedDevices = <Device>[];
      for (final device in allDevices) {
        final service = _services[device.platform];
        if (service == null) {
          detailedDevices.add(device);
          continue;
        }

        try {
          if (device.platform == MobilePlatform.android) {
            final ads = service as AdbService;
            final props = await ads.getAllDeviceProperties(device.id);
            final battery = await ads.getBatteryInfo(device.id);
            final storage = await ads.getStorageInfo(device.id);
            final resolution = await ads.getDisplayResolution(device.id);

            final deviceInfo = DeviceInfo.fromProperties(props).copyWith(
              batteryLevel: battery['level'] as int,
              isCharging: battery['isCharging'] as bool,
              totalStorage: storage['total']!,
              availableStorage: storage['available']!,
              displayResolution: resolution,
            );

            detailedDevices.add(
              device.copyWith(
                name: deviceInfo.displayName,
                model: deviceInfo.model,
                osVersion: deviceInfo.osVersion,
                info: deviceInfo,
              ),
            );
          } else {
            // iOS Details
            final props = await service.getFullSystemProperties(device.id);
            final deviceInfo = DeviceInfo.fromMap(props); // Logic inside mapper

            detailedDevices.add(
              device.copyWith(
                name: deviceInfo.displayName,
                model: deviceInfo.model,
                osVersion: deviceInfo.osVersion,
                info: deviceInfo,
              ),
            );
          }
        } catch (e) {
          _logger.w('Failed to get detailed info for ${device.id}', error: e);
          detailedDevices.add(device);
        }
      }
      // Sort: Apple (iOS) devices first, then Android
      detailedDevices.sort((a, b) {
        if (a.platform == b.platform) {
          return a.name.compareTo(b.name);
        }
        return a.platform == MobilePlatform.ios ? -1 : 1;
      });

      _availableDevices = detailedDevices;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (_isLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> connectUsb(Device device) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Device is already connected via USB
      _connectedDevice = device;
      _status = ConnectionStatus.connected;

      // Save to history
      await _historyService.saveDevice(device);
      await _loadSavedDevices();
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> connectWifi(String ipAddress) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await adbService.connectWifi(ipAddress);

      if (success) {
        await Future.delayed(const Duration(seconds: 1));
        await refreshDevices();

        final device = _availableDevices.firstWhere(
          (d) => d.ipAddress == ipAddress,
          orElse: () => throw Exception('Device not found after connection'),
        );

        _connectedDevice = device;
        _status = ConnectionStatus.connected;

        // Save to history
        await _historyService.saveDevice(device);
        await _loadSavedDevices();
      } else {
        throw Exception('Failed to connect to $ipAddress');
      }
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> pairAndConnect(String ipPort, String pairingCode) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final paired = await adbService.pairDevice(ipPort, pairingCode);

      if (paired) {
        _logger.i('Paired successfully, now connecting...');
        // After pairing, we need to connect.
        // Note: The port for connection might be different from the pairing port.
        // Usually users enter the "IP address & Port" shown on the main Wireless Debugging screen for connection.
        // But for convenience, we can try to connect to the same IP if we can guess the port or if it's provided.
        // However, IP/Port for pairing and connection are different.
        // We will assume the user provides the pairing IP/Port first, then we might need to connect to the connection IP/Port.

        // For now, let's just show success and let them connect normally.
        // Actually, we can try to find the device.
        await Future.delayed(const Duration(seconds: 2));
        await refreshDevices();

        _status = ConnectionStatus.disconnected;
        _errorMessage =
            'Successfully paired! Now you can connect using the connection port.';
      } else {
        throw Exception('Failed to pair. Please check the code and IP/Port.');
      }
    } catch (e) {
      _status = ConnectionStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> enableWifiMode(Device usbDevice) async {
    try {
      await adbService.enableTcpip();
      final ip = await adbService.getDeviceIp(usbDevice.id);

      if (ip != null) {
        await Future.delayed(const Duration(seconds: 3));
        await connectWifi(ip);
      } else {
        throw Exception('Could not get device IP address');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = ConnectionStatus.error;
      notifyListeners();
    }
  }

  Future<List<AppInfo>> getInstalledApps(String deviceId) async {
    final device = _availableDevices.firstWhere((d) => d.id == deviceId);
    final service = _services[device.platform];
    return service?.getInstalledApps(deviceId) ?? Future.value([]);
  }

  Future<bool> uninstallApp(String deviceId, String packageName) async {
    final device = _availableDevices.firstWhere((d) => d.id == deviceId);
    final service = _services[device.platform];
    return service?.uninstallApp(deviceId, packageName) ?? Future.value(false);
  }

  Future<bool> installApp(String deviceId, String apkPath) async {
    final device = _availableDevices.firstWhere((d) => d.id == deviceId);
    final service = _services[device.platform];
    return service?.installApp(deviceId, apkPath) ?? Future.value(false);
  }

  Future<String?> pullApp(
    String deviceId,
    String packageName,
    String localDir,
  ) async {
    final device = _availableDevices.firstWhere((d) => d.id == deviceId);
    if (device.platform == MobilePlatform.android) {
      return adbService.pullApp(deviceId, packageName, localDir);
    }
    return null;
  }

  Future<void> swipe(
    String deviceId,
    List<Point<int>> points, {
    int duration = 300,
  }) async {
    final device = _availableDevices.firstWhere((d) => d.id == deviceId);
    if (device.platform == MobilePlatform.android) {
      return adbService.swipe(deviceId, points, duration: duration);
    }
  }

  Future<void> unlockDevice(String deviceId, String pin) async {
    final device = _availableDevices.firstWhere((d) => d.id == deviceId);
    if (device.platform == MobilePlatform.android) {
      return adbService.unlockDevice(deviceId, pin);
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      final service = _services[_connectedDevice!.platform];
      if (service != null && service is AdbService) {
        await service.disconnectDevice(_connectedDevice!.id);
      }
      _connectedDevice = null;
      _status = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _devicePollTimer?.cancel();
    for (var service in _services.values) {
      service.dispose();
    }
    super.dispose();
  }
}
