import 'package:flutter_test/flutter_test.dart';
import 'package:samsconnect/services/mirroring/mirroring_service.dart';
import 'package:samsconnect/services/tools/tools_service.dart';

class ManualMockToolsService implements ToolsService {
  @override
  String? get adbPath => 'adb';
  @override
  String? get mirroringPath => 'scrcpy';
  @override
  Future<void> initialize() async {}
}

void main() {
  group('MirroringService Stats Parsing', () {
    late MirroringService service;

    setUp(() {
      service = MirroringService(ManualMockToolsService());
    });

    test('should parse FPS correctly', () async {
      final statsList = <MirroringStats>[];
      service.statsStream.listen(statsList.add);

      service.parseStats('FPS: 59.5');
      await Future.delayed(Duration.zero);

      expect(statsList.last.fps, 59.5);
    });

    test('should parse latency correctly', () async {
      final statsList = <MirroringStats>[];
      service.statsStream.listen(statsList.add);

      service.parseStats('latency=45');
      await Future.delayed(Duration.zero);

      expect(statsList.last.latency, 45);
    });

    test('should handle mixed input', () async {
      final statsList = <MirroringStats>[];
      service.statsStream.listen(statsList.add);

      service.parseStats('FPS: 60.0, latency=30');
      await Future.delayed(Duration.zero);

      expect(statsList.last.fps, 60.0);
      expect(statsList.last.latency, 30);
    });
  });
}
