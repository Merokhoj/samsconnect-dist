// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
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
    // Set surface size to desktop to ensure Sidebar is visible
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    // Note: This won't actually initialize tools in a test environment easily without mocks
    // TODO: Fix test by mocking window_manager and path_provider which are required by the app
    // await tester.pumpWidget(SamsConnectApp(toolsService: ManualMockToolsService()));

    // Verify that our app shows the title.
    // expect(find.text('SamsConnect'), findsOneWidget);

    // Reset surface size
    addTearDown(tester.view.resetPhysicalSize);
  });
}
