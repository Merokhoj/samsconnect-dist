import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

class ToolsService {
  final Logger _logger = Logger();
  late String _toolsDir;

  String? _adbPath;
  String? _mirroringPath;

  String? get adbPath => _adbPath;
  String? get mirroringPath => _mirroringPath;

  Future<void> initialize() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      _toolsDir = p.join(appSupportDir.path, 'tools');

      if (!await Directory(_toolsDir).exists()) {
        await Directory(_toolsDir).create(recursive: true);
      }

      await _extractTools();
    } catch (e) {
      _logger.e('Failed to initialize ToolsService', error: e);
      rethrow;
    }
  }

  Future<void> _extractTools() async {
    final platform = _getPlatformFolder();
    if (platform == null) return;

    final adbAssetPath = 'assets/tools/$platform/adb';
    final scrcpyAssetPath = 'assets/tools/$platform/samsconnect';
    final scrcpyServerAssetPath = 'assets/tools/$platform/samsconnect-server';

    _adbPath = await _extractFile(adbAssetPath, 'adb');
    _mirroringPath = await _extractFile(
      scrcpyAssetPath,
      'samsconnect',
      fallbackAssetPaths: ['assets/tools/$platform/console-core'],
    );
    await _extractFile(
      scrcpyServerAssetPath,
      'samsconnect-server',
      fallbackAssetPaths: ['assets/tools/$platform/console-server'],
    );

    if (Platform.isLinux || Platform.isMacOS) {
      if (_adbPath != null) await _makeExecutable(_adbPath!);
      if (_mirroringPath != null) await _makeExecutable(_mirroringPath!);
    }
  }

  Future<String?> _extractFile(
    String assetPath,
    String fileName, {
    List<String> fallbackAssetPaths = const [],
  }) async {
    final targetPath = p.join(_toolsDir, fileName);
    final targetFile = File(targetPath);

    try {
      final exists = await targetFile.exists();
      ByteData? data;

      // Try main path and then fallbacks
      final allPaths = [assetPath, ...fallbackAssetPaths];
      for (final path in allPaths) {
        try {
          data = await rootBundle.load(path);
          break; // Found it
        } catch (_) {
          continue;
        }
      }

      if (data == null) {
        _logger.w('Failed to load asset from $allPaths');
        if (exists) {
          _logger.i('Using existing file at $targetPath');
          return targetPath;
        }
        return null;
      }

      final bytes = data.buffer.asUint8List();

      // Write to target
      try {
        await targetFile.writeAsBytes(bytes);
        _logger.i('Extracted $fileName to $targetPath');
      } catch (e) {
        if (exists) {
          _logger.w(
            'Failed to overwrite $fileName (likely in use). Using existing file.',
          );
          return targetPath;
        }
        rethrow;
      }

      return targetPath;
    } catch (e) {
      _logger.e('Failed to extract $fileName from $assetPath', error: e);
      return null;
    }
  }

  Future<void> _makeExecutable(String path) async {
    try {
      await Process.run('chmod', ['+x', path]);
      _logger.i('Set executable bit for $path');
    } catch (e) {
      _logger.e('Failed to set executable bit for $path', error: e);
    }
  }

  String? _getPlatformFolder() {
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return null;
  }
}
