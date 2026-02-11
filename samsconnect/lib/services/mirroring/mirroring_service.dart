import 'dart:io';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:meta/meta.dart';
import '../tools/tools_service.dart';
import '../../data/models/device.dart';
import '../../data/models/mirroring_config.dart';

enum MirroringStatus { stopped, starting, running, error }

class MirroringStats {
  final double fps;
  final int? latency; // ms

  MirroringStats({this.fps = 0.0, this.latency});
}

class MirroringService {
  final ToolsService _toolsService;
  final Logger _logger = Logger();

  MirroringService(this._toolsService);

  String? _mirroringPath;
  Process? _mirroringProcess;
  MirroringStatus _status = MirroringStatus.stopped;
  String? _errorMessage;
  Device? _connectedDevice;
  MirroringConfig _config = const MirroringConfig();
  final _statsController = StreamController<MirroringStats>.broadcast();
  MirroringStats _latestStats = MirroringStats();

  MirroringStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Device? get connectedDevice => _connectedDevice;
  MirroringConfig get config => _config;
  bool get isRunning => _status == MirroringStatus.running;
  Stream<MirroringStats> get statsStream => _statsController.stream;
  MirroringStats get latestStats => _latestStats;

  /// Initialize the mirroring service
  Future<void> initialize() async {
    try {
      _mirroringPath = _toolsService.mirroringPath;

      if (_mirroringPath == null || !await File(_mirroringPath!).exists()) {
        throw Exception(
          'SamsConnect core not found. Please place mirroring tools in the tools directory.',
        );
      }

      _logger.i('SamsConnect core initialized: $_mirroringPath');
    } catch (e) {
      _logger.e('Failed to initialize SamsConnect core', error: e);
      rethrow;
    }
  }

  /// Start screen mirroring for a device
  Future<void> startMirroring(Device device, {MirroringConfig? config}) async {
    if (device.platform == MobilePlatform.android && _mirroringPath == null) {
      throw Exception(
        'SamConnect core not initialized. Call initialize() first.',
      );
    }

    if (_status == MirroringStatus.running ||
        _status == MirroringStatus.starting) {
      try {
        await stopMirroring();
      } catch (e) {
        _logger.d('Error cleaning up previous mirroring session: $e');
      }
    }

    try {
      _status = MirroringStatus.starting;
      _connectedDevice = device;
      _config = config ?? _config;
      _errorMessage = null;

      if (device.platform == MobilePlatform.android) {
        final args = <String>[
          '--serial',
          device.id,
          ..._config.toMirroringArgs(),
          '--always-on-top',
          '--window-title',
          'SamsConnect - ${device.name}',
          '--print-fps',
        ];

        _logger.i(
          'Starting SamsConnect core: $_mirroringPath ${args.join(' ')}',
        );

        final serverFile = File(
          p.join(p.dirname(_mirroringPath!), 'samsconnect-server'),
        );

        final Map<String, String> env = Map.from(Platform.environment);
        if (serverFile.existsSync()) {
          env['SCRCPY_SERVER_PATH'] = serverFile.path;
        }
        // Ensure the tools dir (containing adb) is in the PATH
        final toolsDir = p.dirname(_mirroringPath!);
        final pathKey = Platform.isWindows ? 'Path' : 'PATH';
        final currentPath = env[pathKey] ?? '';
        env[pathKey] = '$toolsDir${Platform.isWindows ? ';' : ':'}$currentPath';
        // Also set ADB explicitly just in case
        env['ADB'] = p.join(toolsDir, Platform.isWindows ? 'adb.exe' : 'adb');

        _mirroringProcess = await Process.start(
          _mirroringPath!,
          args,
          environment: env,
        );
      } else {
        // iOS Mirroring with UxPlay
        _logger.i('Starting iOS Mirroring with UxPlay for ${device.name}');

        // Check if uxplay is installed
        try {
          final check = await Process.run('which', ['uxplay']);
          if (check.exitCode != 0) {
            throw Exception(
              'uxplay not found. Please install it using: sudo apt install uxplay',
            );
          }
        } catch (e) {
          throw Exception('Failed to check for uxplay: $e');
        }

        // -avdec: Force software h264 decoding for better stability on Linux
        // -p: Use legacy ports for better firewall compatibility
        final args = <String>[
          '-nh',
          '-n',
          'SamsConnect - ${device.name}',
          '-avdec',
          '-p',
        ];

        _mirroringProcess = await Process.start('uxplay', args);

        _logger.i(
          'UxPlay started. Please open Control Center on your iPhone and select Screen Mirroring -> "SamsConnect - ${device.name}"',
        );
      }

      // Catch exit
      _mirroringProcess!.exitCode.then((code) {
        _logger.i('Mirroring process exited with code $code');
        if (_status != MirroringStatus.stopped) {
          if (code != 0 && code != 255) {
            _errorMessage = 'Mirroring process crashed (code $code).';
            _status = MirroringStatus.error;
          } else {
            _status = MirroringStatus.stopped;
          }
          _mirroringProcess = null;
          _connectedDevice = null;
        }
      });

      // Listen to stderr for errors
      _mirroringProcess!.stderr.listen((data) {
        final message = String.fromCharCodes(data);
        _logger.w('Mirroring stderr: $message');

        if (device.platform == MobilePlatform.android) {
          if (message.contains('ERROR:') || message.contains('FATAL:')) {
            if (message.contains('Could not open icon image') ||
                message.contains('Could not load icon')) {
              _logger.d('Ignoring non-fatal SamConnect header error: $message');
            } else {
              _errorMessage = message;
              _status = MirroringStatus.error;
            }
          }
        } else {
          // UxPlay logging is often to stderr
          if (message.toLowerCase().contains('error') ||
              message.toLowerCase().contains('failed') ||
              message.contains('not found')) {
            _logger.w('UxPlay potential error: $message');

            if (message.contains('gstreamer plugin') &&
                message.contains('not found')) {
              _errorMessage =
                  'Missing GStreamer plugin. Please run:\nsudo apt install gstreamer1.0-plugins-bad';
              _status = MirroringStatus.error;
            } else if (_status == MirroringStatus.starting) {
              // Only set error status if we haven't reached 'running' yet
              // because uxplay logs some warnings to stderr even when working
              _errorMessage = message;
            }
          }
        }

        parseStats(message);
      });

      // Listen to stdout
      _mirroringProcess!.stdout.listen((data) {
        final message = String.fromCharCodes(data);
        _logger.d('Mirroring stdout: $message');
        parseStats(message);
      });

      // Wait a bit to see if it starts successfully
      await Future.delayed(const Duration(milliseconds: 1500));

      // Check if status is still okay
      if (_status == MirroringStatus.starting) {
        _status = MirroringStatus.running;
        _logger.i('Mirroring started successfully for ${device.id}');
      } else if (_status == MirroringStatus.error) {
        throw Exception(_errorMessage ?? 'Mirroring failed to start');
      } else {
        // For uxplay, it might stay in starting if it hasn't established a connection yet
        // but it's technically running.
        _status = MirroringStatus.running;
        _logger.i('Mirroring process running for ${device.id}');
      }
    } catch (e) {
      _status = MirroringStatus.error;
      _errorMessage = e.toString();
      _logger.e('Failed to start mirroring', error: e);
      rethrow;
    }
  }

  /// Stop screen mirroring
  Future<void> stopMirroring() async {
    if (_mirroringProcess != null) {
      try {
        _logger.i('Stopping mirroring...');
        _mirroringProcess!.kill();
        await _mirroringProcess!.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            _logger.w('Process did not exit gracefully, force killing');
            _mirroringProcess!.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
        _mirroringProcess = null;
        _status = MirroringStatus.stopped;
        _connectedDevice = null;
        _errorMessage = null;
        _logger.i('Mirroring stopped');
      } catch (e) {
        _logger.e('Error stopping mirroring', error: e);
        _status = MirroringStatus.error;
        _errorMessage = e.toString();
      }
    }
  }

  /// Update mirroring configuration (requires restart)
  Future<void> updateConfig(MirroringConfig newConfig) async {
    final wasRunning = _status == MirroringStatus.running;
    final currentDevice = _connectedDevice;

    if (wasRunning) {
      await stopMirroring();
    }

    _config = newConfig;

    if (wasRunning && currentDevice != null) {
      await startMirroring(currentDevice, config: newConfig);
    }
  }

  /// Monitor the mirroring process
  Stream<MirroringStatus> monitorStatus() async* {
    while (_status == MirroringStatus.running ||
        _status == MirroringStatus.starting) {
      await Future.delayed(const Duration(seconds: 2));
      yield _status;
    }
    yield _status;
  }

  @visibleForTesting
  void parseStats(String message) {
    // Parse FPS: "FPS: 60.0"
    if (message.contains('FPS:')) {
      final match = RegExp(r'FPS: ([\d.]+)').firstMatch(message);
      if (match != null) {
        final fps = double.tryParse(match.group(1) ?? '0') ?? 0.0;
        _latestStats = MirroringStats(fps: fps, latency: _latestStats.latency);
        _statsController.add(_latestStats);
      }
    }

    // Some versions show latency=
    if (message.contains('latency=')) {
      final match = RegExp(r'latency=(\d+)').firstMatch(message);
      if (match != null) {
        final latency = int.tryParse(match.group(1) ?? '0');
        _latestStats = MirroringStats(fps: _latestStats.fps, latency: latency);
        _statsController.add(_latestStats);
      }
    }
  }

  void dispose() {
    if (_mirroringProcess != null) {
      stopMirroring();
    }
    _statsController.close();
  }
}
