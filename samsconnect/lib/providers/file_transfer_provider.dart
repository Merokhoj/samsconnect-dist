import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../services/file_transfer/file_transfer_service.dart';
import '../data/models/device.dart';

enum TransferStatus { idle, transferring, completed, error }

class FileTransferProvider with ChangeNotifier {
  final FileTransferService _fileTransferService;

  TransferStatus _status = TransferStatus.idle;
  String? _errorMessage;
  double _progress = 0;

  String _currentPath = '/sdcard';
  List<String> _contents = [];
  bool _isLoading = false;

  FileTransferProvider(this._fileTransferService);

  TransferStatus get status => _status;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  String get currentPath => _currentPath;
  List<String> get contents => _contents;
  bool get isLoading => _isLoading;

  Future<void> loadDirectory(Device device, String path) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _contents = await _fileTransferService.listDirectory(
        device.id,
        device.platform,
        path,
      );
      _currentPath = path;
    } catch (e) {
      _errorMessage = 'Failed to load directory: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pushFiles(
    Device device,
    List<String> localPaths,
    String remoteDir,
  ) async {
    _status = TransferStatus.transferring;
    _errorMessage = null;
    _progress = 0;
    notifyListeners();

    try {
      int completed = 0;
      for (final path in localPaths) {
        final fileName = path.split('/').last;
        final success = await _fileTransferService.pushFile(
          device.id,
          device.platform,
          path,
          '$remoteDir/$fileName',
        );

        if (!success) {
          throw Exception('Failed to transfer $fileName');
        }

        completed++;
        _progress = completed / localPaths.length;
        notifyListeners();
      }

      _status = TransferStatus.completed;
      // Refresh current directory if we just pushed into it
      if (remoteDir == _currentPath) {
        await loadDirectory(device, _currentPath);
      }
    } catch (e) {
      _status = TransferStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> pullFile(
    Device device,
    String remotePath,
    String localPath,
  ) async {
    _status = TransferStatus.transferring;
    _errorMessage = null;
    _progress = 0;
    notifyListeners();

    try {
      final success = await _fileTransferService.pullFile(
        device.id,
        device.platform,
        remotePath,
        localPath,
      );

      if (!success) {
        throw Exception('Failed to download file');
      }

      _status = TransferStatus.completed;
      _progress = 1.0;
    } catch (e) {
      _status = TransferStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Pull a file to a temporary location and open it with system default
  Future<void> openRemoteFile(Device device, String remotePath) async {
    _status = TransferStatus.transferring;
    _errorMessage = null;
    notifyListeners();

    try {
      final fileName = remotePath.split('/').last;
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/${device.id}-$fileName';

      final success = await _fileTransferService.pullFile(
        device.id,
        device.platform,
        remotePath,
        localPath,
      );

      if (success) {
        // Open with system default command
        if (Platform.isLinux) {
          await Process.run('xdg-open', [localPath]);
        } else if (Platform.isWindows) {
          await Process.run('start', ['', localPath], runInShell: true);
        } else if (Platform.isMacOS) {
          await Process.run('open', [localPath]);
        }
        _status = TransferStatus.completed;
      } else {
        throw Exception('Failed to pull file for opening');
      }
    } catch (e) {
      _errorMessage = 'Failed to open file: $e';
      _status = TransferStatus.error;
    }
    notifyListeners();
  }

  void reset() {
    _status = TransferStatus.idle;
    _errorMessage = null;
    _progress = 0;
    notifyListeners();
  }
}
