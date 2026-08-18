import 'dart:async';
import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/server_discovery.dart';
import '../login/login_screen.dart';
import '../../layouts/windows_sidebar_layout.dart';
import '../../layouts/android_bottom_nav_layout.dart';
import '../../providers/auth_provider.dart';
import '../../../core/services/foreground_sync_service.dart';
import '../../shared/widgets/abstract_background.dart';

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

  Future<void> _initializeApp() async {
    await ForegroundSyncService.requestPermissions();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // ── Step 1: Resolve server URL silently in background ───────────────────
    await _resolveServer();
    if (!mounted) return;

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

  Future<void> _resolveServer() async {
    // 1. Check saved URL first
    final saved = await ServerDiscoveryService.getSaved();
    if (saved != null) {
      final alive = await ServerDiscoveryService.ping(saved);
      if (alive) {
        ApiConstants.setBaseUrl(saved);
        return;
      }
    }

    // 2. Automatically scan local network first by default (LAN Discovery)
    await _runScan();
  }

  Future<void> _runScan() async {
    final prefixes = await ServerDiscoveryService.getSubnetPrefixes();

    if (prefixes.isNotEmpty) {
      final found = await ServerDiscoveryService.discover();
      if (found != null) {
        await ServerDiscoveryService.save(found);
        ApiConstants.setBaseUrl(found);
        await Future.delayed(const Duration(milliseconds: 300));
        return;
      }
    }

    // 3. Fallback to tunnel domain
    final tunnelAlive =
        await ServerDiscoveryService.ping(ApiConstants.tunnelUrl);
    if (tunnelAlive) {
      await ServerDiscoveryService.save(ApiConstants.tunnelUrl);
      ApiConstants.setBaseUrl(ApiConstants.tunnelUrl);
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    // 4. If connection fails, show dialog
    if (!mounted) return;
    await _showConnectionFailedDialog();
  }

  Future<void> _showConnectionFailedDialog() async {
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
        title: const Text(
          'Server Connection Failed',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No local TIS RMS server was detected on your network and the tunnel domain (${ApiConstants.tunnelUrl}) is currently unreachable.\n\nPlease check your network connection or ensure the server is online.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your saved credentials remain safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _initializeApp();
            },
            child: const Text(
              'Retry Connection',
              style: TextStyle(
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
            child: const Text('Close App'),
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
                  title: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TIS Record Management System',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryGreen,
                          ),
                          strokeWidth: 2.6,
                        ),
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
