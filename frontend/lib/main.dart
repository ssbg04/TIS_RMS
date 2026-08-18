import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

// UI Imports
import 'ui/screens/splash/splash_screen.dart';
// Core Imports
import 'core/theme/app_theme.dart'; // Add this import
import 'core/constants/app_colors.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/foreground_sync_service.dart';
import 'ui/providers/theme_provider.dart';
import 'ui/shared/widgets/inactivity_wrapper.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final physicalSize = view.physicalSize;
  final devicePixelRatio = view.devicePixelRatio;
  final width = physicalSize.width / devicePixelRatio;
  final height = physicalSize.height / devicePixelRatio;
  final shortestSide = width < height ? width : height;

  if (shortestSide < 600) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  await NotificationService().initialize();
  await ForegroundSyncService.init();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    Workmanager().initialize(callbackDispatcher);
    // Register periodic background sync task
    Workmanager().registerPeriodicTask(
      "tis_rms_background_sync",
      "background_sync_task",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  runApp(const ProviderScope(child: TisRmsApp()));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class TisRmsApp extends ConsumerWidget {
  const TisRmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return InactivityWrapper(
      navigatorKey: navigatorKey,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'TIS Record Management System',
        debugShowCheckedModeBanner: false,

        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,

        builder: (context, child) {
          return ColoredBox(
            color: AppColors.primaryGreen,
            child: SafeArea(child: child!),
          );
        },

        home: const SplashScreen(),
      ),
    );
  }
}
