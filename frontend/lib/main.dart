import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// UI Imports
import 'ui/screens/splash/splash_screen.dart'; 
// Core Imports
import 'core/theme/app_theme.dart'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: TisRmsApp()));
}

class TisRmsApp extends StatelessWidget {
  const TisRmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TIS RMS',
      debugShowCheckedModeBanner: false,
      
      // Clean, centralized theme reference!
      theme: AppTheme.lightTheme, 
      
      home: const SplashScreen(), 
    );
  }
}