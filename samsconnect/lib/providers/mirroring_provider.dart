import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../services/mirroring/mirroring_service.dart';
import '../data/models/device.dart';
import '../data/models/mirroring_config.dart';

class MirroringProvider with ChangeNotifier {
  final MirroringService _mirroringService;
  final Logger _logger = Logger();

  MirroringStatus _status = MirroringStatus.stopped;
  String? _errorMessage;
  Device? _mirroredDevice;
  MirroringConfig _config = MirroringConfig.fromQuality(MirrorQuality.high);
  MirroringStats _stats = MirroringStats();

  MirroringProvider(this._mirroringService);

  MirroringStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Device? get mirroredDevice => _mirroredDevice;
  MirroringConfig get config => _config;
  MirroringStats get stats => _stats;
  bool get isRunning => _status == MirroringStatus.running;

  Future<void> initialize() async {
    try {
      await _mirroringService.initialize();
      _logger.i('MirroringProvider initialized');
    } catch (e) {
      _errorMessage = e.toString();
      _logger.e('Failed to initialize mirroring', error: e);
      notifyListeners();
    }
  }

  Future<void> startMirroring(Device device) async {
    try {
      _status = MirroringStatus.starting;
      _errorMessage = null;
      notifyListeners();

      await _mirroringService.startMirroring(device, config: _config);

      _status = _mirroringService.status;
      _mirroredDevice = device;

      if (_status == MirroringStatus.error) {
        _errorMessage = _mirroringService.errorMessage;
      }

      notifyListeners();

      // Start monitoring
      _mirroringService.monitorStatus().listen((status) {
        _status = status;
        if (status == MirroringStatus.stopped ||
            status == MirroringStatus.error) {
          _mirroredDevice = null;
          _errorMessage = _mirroringService.errorMessage;
          _stats = MirroringStats(); // Reset stats
        }
        notifyListeners();
      });

      // Listen for stats
      _mirroringService.statsStream.listen((stats) {
        _stats = stats;
        notifyListeners();
      });
    } catch (e) {
      _status = MirroringStatus.error;
      _errorMessage = e.toString();
      _mirroredDevice = null;
      notifyListeners();
      _logger.e('Failed to start mirroring', error: e);
    }
  }

  Future<void> stopMirroring() async {
    try {
      await _mirroringService.stopMirroring();
      _status = MirroringStatus.stopped;
      _mirroredDevice = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      _logger.e('Failed to stop mirroring', error: e);
    }
  }

  Future<void> updateQuality(MirrorQuality quality) async {
    _config = MirroringConfig.fromQuality(quality);
    notifyListeners();

    if (_status == MirroringStatus.running) {
      await _mirroringService.updateConfig(_config);
      _status = _mirroringService.status;
      _errorMessage = _mirroringService.errorMessage;
      notifyListeners();
    }
  }

  Future<void> updateConfig(MirroringConfig newConfig) async {
    _config = newConfig;
    notifyListeners();

    if (_status == MirroringStatus.running) {
      await _mirroringService.updateConfig(newConfig);
      _status = _mirroringService.status;
      _errorMessage = _mirroringService.errorMessage;
      notifyListeners();
    }
  }

  void toggleShowTouches() {
    updateConfig(_config.copyWith(showTouches: !_config.showTouches));
  }

  void toggleStayAwake() {
    updateConfig(_config.copyWith(stayAwake: !_config.stayAwake));
  }

  void toggleTurnScreenOff() {
    updateConfig(_config.copyWith(turnScreenOff: !_config.turnScreenOff));
  }
}
