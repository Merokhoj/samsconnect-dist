import 'package:flutter/foundation.dart';
import '../services/connection/adb_service.dart';

class DeviceControlProvider with ChangeNotifier {
  final AdbService _adbService;

  DeviceControlProvider(this._adbService);

  /// Constants for Android KeyCodes
  static const int keyCodeHome = 3;
  static const int keyCodeBack = 4;
  static const int keyCodeAppSwitch = 187; // Recents

  Future<void> pressHome(String deviceId) async {
    await _adbService.sendKeyEvent(deviceId, keyCodeHome);
  }

  Future<void> pressBack(String deviceId) async {
    await _adbService.sendKeyEvent(deviceId, keyCodeBack);
  }

  Future<void> pressRecents(String deviceId) async {
    await _adbService.sendKeyEvent(deviceId, keyCodeAppSwitch);
  }

  Future<void> volumeUp(String deviceId) async {
    await _adbService.adjustVolume(deviceId, true);
  }

  Future<void> volumeDown(String deviceId) async {
    await _adbService.adjustVolume(deviceId, false);
  }

  Future<void> pressPower(String deviceId) async {
    await _adbService.pressPower(deviceId);
  }
}
