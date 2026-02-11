import 'package:network_info_plus/network_info_plus.dart';
import 'package:logger/logger.dart';

class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final Logger _logger = Logger();

  /// Get the current local IP address of the computer
  Future<String?> getLocalIpAddress() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      _logger.i('Detected local IP: $ip');
      return ip;
    } catch (e) {
      _logger.e('Failed to get local IP address', error: e);
      return null;
    }
  }

  /// Get the current WiFi name (SSID)
  Future<String?> getWifiName() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (e) {
      _logger.e('Failed to get WiFi name', error: e);
      return null;
    }
  }
}
