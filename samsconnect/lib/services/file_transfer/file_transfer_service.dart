import 'package:logger/logger.dart';
import '../connection/base_mobile_service.dart';
import '../../data/models/device.dart';

class FileTransferService {
  final Map<MobilePlatform, BaseMobileService> _services;
  final Logger _logger = Logger();

  FileTransferService(List<BaseMobileService> services)
    : _services = {for (var s in services) s.platform: s};

  BaseMobileService? _getService(MobilePlatform platform) =>
      _services[platform];

  /// Push a file to the device
  Future<bool> pushFile(
    String deviceId,
    MobilePlatform platform,
    String localPath,
    String remotePath,
  ) async {
    _logger.i('Pushing file to $platform: $localPath to $remotePath');
    final service = _getService(platform);
    return await service?.pushFile(deviceId, localPath, remotePath) ?? false;
  }

  /// Pull a file from the device
  Future<bool> pullFile(
    String deviceId,
    MobilePlatform platform,
    String remotePath,
    String localPath,
  ) async {
    _logger.i('Pulling file from $platform: $remotePath to $localPath');
    final service = _getService(platform);
    return await service?.pullFile(deviceId, remotePath, localPath) ?? false;
  }

  /// List contents
  Future<List<String>> listDirectory(
    String deviceId,
    MobilePlatform platform,
    String path,
  ) async {
    final service = _getService(platform);
    return await service?.listDirectory(deviceId, path) ?? [];
  }

  /// Get standard directories for a platform
  String getDownloadsPath(MobilePlatform platform) =>
      platform == MobilePlatform.android
      ? '/sdcard/Download'
      : '/Media/Downloads';

  String getDcimPath(MobilePlatform platform) =>
      platform == MobilePlatform.android ? '/sdcard/DCIM' : '/Media/DCIM';

  String getPicturesPath(MobilePlatform platform) =>
      platform == MobilePlatform.android ? '/sdcard/Pictures' : '/Media/Photos';

  String getDocumentsPath(MobilePlatform platform) =>
      platform == MobilePlatform.android
      ? '/sdcard/Documents'
      : '/Media/Documents';
}
