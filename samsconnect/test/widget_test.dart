import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samsconnect/main.dart';
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
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Mock path_provider and window_manager
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const windowChannel = MethodChannel('window_manager');

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel,
        (methodCall) async {
      return '.';
    });

    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, (methodCall) async {
      return null;
    });

    // Set surface size to desktop to ensure Sidebar is visible
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester
        .pumpWidget(SamsConnectApp(toolsService: ManualMockToolsService()));
    await tester.pumpAndSettle();

    // Verify that our app shows the title
    expect(find.text('SamsConnect'), findsAtLeast(1));

    // Reset surface size
    addTearDown(tester.view.resetPhysicalSize);
  });
}
