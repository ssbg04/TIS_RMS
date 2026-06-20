import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// UI Imports
import 'ui/screens/splash/splash_screen.dart'; 
// Core Imports
import 'core/theme/app_theme.dart'; // Add this import
import 'ui/shared/widgets/inactivity_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: TisRmsApp()));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class TisRmsApp extends StatelessWidget {
  const TisRmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return InactivityWrapper(
      navigatorKey: navigatorKey,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'TIS RMS',
        debugShowCheckedModeBanner: false,
        
        // Clean, centralized theme reference!
        theme: AppTheme.lightTheme, 
        
        home: const SplashScreen(), 
      ),
    );
  }
}