import 'package:flutter/material.dart';
import '../services/settings/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService;
  bool _autoTheme = true;

  SettingsProvider(this._settingsService) {
    _checkAutoTheme();
  }

  bool get darkMode => _autoTheme ? _isNightTime() : _settingsService.darkMode;
  bool get autoTheme => _autoTheme;
  double get bitrateMbps => _settingsService.bitrateMbps;
  int get maxFps => _settingsService.maxFps;

  void _checkAutoTheme() {
    // Periodically check if autoTheme is enabled
    // For now, it's a simple calculated property
  }

  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 18; // 6 PM to 6 AM is night
  }

  Future<void> setAutoTheme(bool value) async {
    _autoTheme = value;
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _autoTheme = false; // Disable auto when manual toggle used
    await _settingsService.saveDarkMode(value);
    notifyListeners();
  }

  Future<void> setBitrate(double value) async {
    await _settingsService.saveBitrate(value);
    notifyListeners();
  }

  Future<void> setMaxFps(int value) async {
    await _settingsService.saveMaxFps(value);
    notifyListeners();
  }
}
