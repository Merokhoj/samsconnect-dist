import 'dart:io';
import 'package:flutter/foundation.dart';

abstract class PlatformInterface {
  /// Get the path to ADB executable
  Future<String> getAdbPath();

  /// Get the path to mirroring executable
  Future<String> getMirroringBinaryPath();

  /// Check if required tools are available
  Future<bool> checkToolsAvailable();

  /// Get the current platform (linux, windows, macos)
  String get platformName;

  /// Custom paths from ToolsService
  void setToolsPaths({String? adb, String? mirroring});

  /// Factory method to get platform-specific implementation
  static PlatformInterface create() {
    if (kIsWeb) {
      throw UnsupportedError('Web platform is not supported');
    }

    if (Platform.isLinux) {
      return LinuxPlatform();
    } else if (Platform.isWindows) {
      return WindowsPlatform();
    } else if (Platform.isMacOS) {
      return MacOSPlatform();
    } else {
      throw UnsupportedError(
        'Platform ${Platform.operatingSystem} is not supported',
      );
    }
  }

  /// Check if ADB is in system PATH
  static Future<bool> isAdbInPath() async {
    try {
      final result = await Process.run('adb', ['version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if mirroring core is in system PATH
  static Future<bool> isMirroringInPath() async {
    try {
      final result = await Process.run('scrcpy', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}

class LinuxPlatform implements PlatformInterface {
  @override
  String get platformName => 'linux';

  String? _customAdbPath;
  String? _customMirroringPath;

  @override
  void setToolsPaths({String? adb, String? mirroring}) {
    _customAdbPath = adb;
    _customMirroringPath = mirroring;
  }

  @override
  Future<String> getAdbPath() async {
    // FIRST check if ADB is in system PATH (more reliable than bundled)
    if (await PlatformInterface.isAdbInPath()) {
      return 'adb';
    }

    // Fall back to custom extracted path if system ADB not available
    if (_customAdbPath != null && await File(_customAdbPath!).exists()) {
      return _customAdbPath!;
    }

    throw Exception(
      'ADB not found. Please install android-tools-adb: sudo apt install android-tools-adb',
    );
  }

  @override
  Future<String> getMirroringBinaryPath() async {
    // If we have a custom extracted path, use it
    if (_customMirroringPath != null &&
        await File(_customMirroringPath!).exists()) {
      return _customMirroringPath!;
    }

    // First check if tool is in PATH
    if (await PlatformInterface.isMirroringInPath()) {
      return 'scrcpy';
    }

    throw Exception(
      'SamsConnect core not found. Please install the required mirroring tools or place them in the application support directory.',
    );
  }

  @override
  Future<bool> checkToolsAvailable() async {
    try {
      await getAdbPath();
      await getMirroringBinaryPath();
      return true;
    } catch (e) {
      return false;
    }
  }
}

class WindowsPlatform implements PlatformInterface {
  @override
  String get platformName => 'windows';

  String? _customAdbPath;
  String? _customMirroringPath;

  @override
  void setToolsPaths({String? adb, String? mirroring}) {
    _customAdbPath = adb;
    _customMirroringPath = mirroring;
  }

  @override
  Future<String> getAdbPath() async {
    // If we have a custom extracted path, use it
    if (_customAdbPath != null && await File(_customAdbPath!).exists()) {
      return _customAdbPath!;
    }

    // First check if ADB is in PATH
    if (await PlatformInterface.isAdbInPath()) {
      return 'adb.exe';
    }

    throw Exception(
      'ADB not found. Please place platform-tools in the application support directory or system PATH.',
    );
  }

  @override
  Future<String> getMirroringBinaryPath() async {
    // If we have a custom extracted path, use it
    if (_customMirroringPath != null &&
        await File(_customMirroringPath!).exists()) {
      return _customMirroringPath!;
    }

    // First check if tool is in PATH
    if (await PlatformInterface.isMirroringInPath()) {
      return 'scrcpy.exe';
    }

    throw Exception(
      'SamsConnect core not found. Please place the required mirroring tools in the application support directory or system PATH.',
    );
  }

  @override
  Future<bool> checkToolsAvailable() async {
    try {
      await getAdbPath();
      await getMirroringBinaryPath();
      return true;
    } catch (e) {
      return false;
    }
  }
}

class MacOSPlatform implements PlatformInterface {
  @override
  String get platformName => 'macos';

  String? _customAdbPath;
  String? _customMirroringPath;

  @override
  void setToolsPaths({String? adb, String? mirroring}) {
    _customAdbPath = adb;
    _customMirroringPath = mirroring;
  }

  @override
  Future<String> getAdbPath() async {
    // If we have a custom extracted path, use it
    if (_customAdbPath != null && await File(_customAdbPath!).exists()) {
      return _customAdbPath!;
    }

    // First check if ADB is in PATH
    if (await PlatformInterface.isAdbInPath()) {
      return 'adb';
    }

    throw Exception(
      'ADB not found. Please place ADB in the application support directory or system PATH.',
    );
  }

  @override
  Future<String> getMirroringBinaryPath() async {
    // If we have a custom extracted path, use it
    if (_customMirroringPath != null &&
        await File(_customMirroringPath!).exists()) {
      return _customMirroringPath!;
    }

    // First check if tool is in PATH
    if (await PlatformInterface.isMirroringInPath()) {
      return 'scrcpy';
    }

    throw Exception(
      'SamsConnect core not found. Please place the required mirroring tools in the application support directory or system PATH.',
    );
  }

  @override
  Future<bool> checkToolsAvailable() async {
    try {
      await getAdbPath();
      await getMirroringBinaryPath();
      return true;
    } catch (e) {
      return false;
    }
  }
}
