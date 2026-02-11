// No imports needed for simple settings logic

class SettingsService {
  // Current settings (could be loaded from disk in the future)
  bool _darkMode = false;
  double _bitrateMbps = 4.0;
  int _maxFps = 60;

  bool get darkMode => _darkMode;
  double get bitrateMbps => _bitrateMbps;
  int get maxFps => _maxFps;

  Future<void> loadSettings() async {
    // Mock loading from storage
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> saveDarkMode(bool value) async {
    _darkMode = value;
  }

  Future<void> saveBitrate(double value) async {
    _bitrateMbps = value;
  }

  Future<void> saveMaxFps(int value) async {
    _maxFps = value;
  }
}
