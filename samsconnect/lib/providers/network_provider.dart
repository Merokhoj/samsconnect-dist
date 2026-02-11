import 'package:flutter/foundation.dart';
import '../services/network/network_service.dart';

class NetworkProvider with ChangeNotifier {
  final NetworkService _networkService;

  String? _localIp;
  String? _wifiName;
  bool _isLoading = false;

  NetworkProvider(this._networkService);

  String? get localIp => _localIp;
  String? get wifiName => _wifiName;
  bool get isLoading => _isLoading;

  Future<void> refreshNetworkInfo() async {
    _isLoading = true;
    notifyListeners();

    try {
      _localIp = await _networkService.getLocalIpAddress();
      _wifiName = await _networkService.getWifiName();
    } catch (e) {
      // Log error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
