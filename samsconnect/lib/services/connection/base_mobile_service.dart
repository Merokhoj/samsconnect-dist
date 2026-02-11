import 'dart:typed_data';
import '../../data/models/device.dart';
import '../../data/models/app_info.dart';

abstract class BaseMobileService {
  MobilePlatform get platform;

  Future<void> initialize();
  Future<List<Device>> getDevices();
  Future<Map<String, String>> getFullSystemProperties(String deviceId);
  Future<List<AppInfo>> getInstalledApps(String deviceId);
  Future<Uint8List?> getScreenCapture(String deviceId);

  // File Management
  Future<List<String>> listDirectory(String deviceId, String path);
  Future<bool> pushFile(String deviceId, String localPath, String remotePath);
  Future<bool> pullFile(String deviceId, String remotePath, String localPath);

  // App Management
  Future<bool> installApp(String deviceId, String filePath);
  Future<bool> uninstallApp(String deviceId, String packageName);

  // Device Interaction (Optional/Platform Specific)
  Future<void> reboot(String deviceId);

  void dispose();
}
