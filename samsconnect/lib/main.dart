import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/screens/home_screen.dart';
import 'providers/connection_provider.dart';
import 'providers/mirroring_provider.dart';
import 'providers/file_transfer_provider.dart';
import 'providers/network_provider.dart';
import 'providers/device_control_provider.dart';
import 'providers/settings_provider.dart';
import 'services/settings/settings_service.dart';
import 'services/connection/adb_service.dart';
import 'services/mirroring/mirroring_service.dart';
import 'services/file_transfer/file_transfer_service.dart';
import 'services/network/network_service.dart';
import 'services/tools/tools_service.dart';
import 'services/connection/ios_service.dart';
import 'platform/platform_interface.dart';

import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optimize font loading for Linux
  try {
    // Enable runtime font fetching but handle failures gracefully
    GoogleFonts.config.allowRuntimeFetching = true;
  } catch (e) {
    debugPrint('Font configuration error: $e');
  }

  // Intercept global errors (especially font loading errors on Linux)
  // to prevent app from crashing due to network or asset issues.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('google_fonts')) {
      debugPrint('Caught non-fatal GoogleFonts error: ${details.exception}');
      return;
    }
    originalOnError?.call(details);
  };

  // Catch async errors (like font loading failures)
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error.toString().contains('google_fonts')) {
      debugPrint('Caught async GoogleFonts error: $error');
      return true; // Error handled
    }
    return false; // Propagate other errors
  };

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: 'SamsConnect',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize ToolsService
  final toolsService = ToolsService();
  await toolsService.initialize();

  runApp(SamsConnectApp(toolsService: toolsService));
}

class SamsConnectApp extends StatelessWidget {
  final ToolsService toolsService;
  const SamsConnectApp({super.key, required this.toolsService});

  @override
  Widget build(BuildContext context) {
    // Create platform interface
    final platform = PlatformInterface.create();

    // Inject tools paths
    platform.setToolsPaths(
      adb: toolsService.adbPath,
      mirroring: toolsService.mirroringPath,
    );

    // Create services
    final adbService = AdbService(platform);
    final iosService = IosService();
    final mirroringService = MirroringService(toolsService);
    final fileTransferService = FileTransferService([adbService, iosService]);
    final networkService = NetworkService();
    final settingsService = SettingsService();

    return MultiProvider(
      providers: [
        Provider<AdbService>.value(value: adbService),
        ChangeNotifierProvider(
          create: (_) =>
              ConnectionProvider([adbService, iosService])..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => MirroringProvider(mirroringService)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => FileTransferProvider(fileTransferService),
        ),
        ChangeNotifierProvider(
          create: (_) => NetworkProvider(networkService)..refreshNetworkInfo(),
        ),
        ChangeNotifierProvider(
          create: (_) => DeviceControlProvider(adbService),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsService),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SamsConnect',
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
