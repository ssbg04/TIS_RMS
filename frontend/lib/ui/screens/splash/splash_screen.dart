import 'dart:async';
import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/server_discovery.dart';
import '../login/login_screen.dart';
import '../../layouts/windows_sidebar_layout.dart';
import '../../layouts/android_bottom_nav_layout.dart';
import '../../providers/auth_provider.dart';
import '../../../core/services/foreground_sync_service.dart';
import '../../shared/widgets/abstract_background.dart';
import '../../shared/widgets/app_button_loader.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoAnimController;
  late Animation<double> _logoScaleAnimation;

  Timer? _quoteTimer;
  int _quoteIndex = 0;

  static const List<String> _entertainingPhrases = [
    'Sharpening digital pencils…',
    'Organizing Form 10 envelopes…',
    'Checking student masterlists…',
    'Polishing the school seal…',
    'Dusting off the record archives…',
    'Reviewing academic credentials…',
    'Brewing coffee for the faculty…',
    'Securing student database…',
    'Preparing SF9 and SF10 documents…',
    'Almost ready for class…',
  ];

  @override
  void initState() {
    super.initState();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _logoAnimController, curve: Curves.easeInOut),
    );

    _quoteTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      setState(() {
        _quoteIndex = (_quoteIndex + 1) % _entertainingPhrases.length;
      });
    });

    _initializeApp();
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    _logoAnimController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp({bool isRetry = false}) async {
    await ForegroundSyncService.requestPermissions();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // ── Step 1: Resolve server URL silently in background ───────────────────
    final resolved = await _resolveServer(isRetry: isRetry);
    if (!resolved || !mounted) return; // Do NOT proceed to login if not connected!

    // ── Step 2: Try auto-login ─────────────────────────────────────────────
    final user = await ref.read(authProvider.notifier).tryAutoLogin();
    if (!mounted) return;

    if (user != null) {
      final isDesktop = MediaQuery.of(context).size.width >= 800;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isDesktop
              ? WindowsSidebarLayout(userRole: user.role)
              : AndroidBottomNavLayout(userRole: user.role),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // ── Server resolution logic ────────────────────────────────────────────────

  Future<bool> _resolveServer({bool isRetry = false}) async {
    final found = await ServerDiscoveryService.resolveServerWithFallback();
    if (found != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    // If all connection attempts fail, show the dialog
    if (!mounted) return false;
    await _showConnectionFailedDialog(isRetry: isRetry);
    return false;
  }

  Future<void> _showConnectionFailedDialog({bool isRetry = false}) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.cloud_off_rounded,
          color: Colors.redAccent,
          size: 40,
        ),
        title: Text(
          isRetry ? 'Still Not Connected' : 'Server Connection Failed',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRetry
                  ? 'Reconnection attempt failed. The TIS RMS server is unreachable on your Local Network (LAN) and Cloud Tunnel.\n\nWould you like to try again or close the application?'
                  : 'No local TIS RMS server was detected on your Local Network (LAN) and the Cloud Tunnel domain is unreachable.\n\nPlease check your Wi-Fi/Internet connection or ensure the server is online.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryGreen),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Checks LAN first, then Tunnel fallback automatically.',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _initializeApp(isRetry: true);
            },
            child: Text(
              isRetry ? 'RETRY' : 'RECONNECT',
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              _closeApp();
            },
            child: const Text('CLOSE APP'),
          ),
        ],
      ),
    );
  }

  void _closeApp() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemNavigator.pop();
    } else if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      exit(0);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AbstractBackground(
        child: Column(
          children: [
            if (!kIsWeb &&
                (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
              SizedBox(
                height: 32,
                child: WindowCaption(
                  brightness: Brightness.dark,
                  backgroundColor: AppColors.primaryGreen,
                  title: const Text(
                    'TIS Record Management System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.black : Colors.green.shade900)
                                    .withValues(alpha: 0.12),
                                blurRadius: 28,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 140,
                            height: 140,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Talisay Integrated School',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Record Management System',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.primaryGreen : AppColors.primaryGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tiaong, Quezon',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Smooth Loading Spinner
                      const AppButtonLoader(
                        size: 28,
                        strokeWidth: 2.6,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 18),

                      // Entertaining loading words with animated transitions
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _entertainingPhrases[_quoteIndex],
                          key: ValueKey<int>(_quoteIndex),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
