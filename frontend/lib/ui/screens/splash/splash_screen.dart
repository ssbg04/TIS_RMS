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

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _statusText = 'Starting up…';
  double? _scanProgress; // null = indeterminate, 0.0–1.0 = progress

  late AnimationController _logoAnimController;
  late Animation<double> _logoScaleAnimation;

  @override
  void initState() {
    super.initState();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoAnimController, curve: Curves.easeInOut),
    );

    _initializeApp();
  }

  @override
  void dispose() {
    _logoAnimController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await ForegroundSyncService.requestPermissions();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // ── Step 1: Resolve server URL ─────────────────────────────────────────
    await _resolveServer();
    if (!mounted) return;

    // ── Step 2: Try auto-login ─────────────────────────────────────────────
    setState(() {
      _statusText = 'Checking session…';
      _scanProgress = null;
    });

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
    // 1. Check saved URL first (if user explicitly selected/saved a VPS, LAN IP, or Tunnel URL)
    final saved = await ServerDiscoveryService.getSaved();
    if (saved != null) {
      setState(() => _statusText = 'Connecting to saved server…');
      final alive = await ServerDiscoveryService.ping(saved);
      if (alive) {
        ApiConstants.setBaseUrl(saved);
        return;
      }
      // Saved server is unreachable — don't wipe credentials, continue to LAN scan & tunnel fallback
    }

    // 2. Automatically scan local network first by default (LAN Discovery)
    await _runScan();
  }

  Future<void> _runScan() async {
    setState(() {
      _statusText = 'Detecting network…';
      _scanProgress = null;
    });

    final prefixes = await ServerDiscoveryService.getSubnetPrefixes();

    if (prefixes.isNotEmpty) {
      final subnetLabel = prefixes.map((p) => '${p}0/24').join(', ');
      setState(() {
        _statusText = 'Scanning LAN ($subnetLabel)…';
        _scanProgress = 0.0;
      });

      final found = await ServerDiscoveryService.discover(
        onProgress: (subnet, scanned, total) {
          if (!mounted) return;
          setState(() {
            _statusText = 'Scanning ${subnet}x … ($scanned/$total)';
            _scanProgress = scanned / total;
          });
        },
      );

      if (found != null) {
        await ServerDiscoveryService.save(found);
        ApiConstants.setBaseUrl(found);
        if (mounted) {
          setState(() {
            _statusText = 'Local server found: $found';
            _scanProgress = 1.0;
          });
        }
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }
    }

    // 3. If local server was not found on LAN, connect to tunnel domain fallback
    setState(() {
      _statusText = 'Connecting to tunnel domain…';
      _scanProgress = null;
    });

    final tunnelAlive =
        await ServerDiscoveryService.ping(ApiConstants.tunnelUrl);
    if (tunnelAlive) {
      await ServerDiscoveryService.save(ApiConstants.tunnelUrl);
      ApiConstants.setBaseUrl(ApiConstants.tunnelUrl);
      if (mounted) {
        setState(() {
          _statusText = 'Connected to tunnel server';
          _scanProgress = 1.0;
        });
      }
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // 4. If the tunnel domain is ALSO not working, show error dialog with Close App (without clearing remember me credentials)
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
              // Close app without clearing remember me credentials
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Column(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (kIsWeb ||
                      Platform.isWindows ||
                      Platform.isMacOS ||
                      Platform.isLinux)
                    ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 150,
                        height: 150,
                      ),
                    )
                  else
                    Image.asset(
                      'assets/images/logo.png',
                      width: 150,
                      height: 150,
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'TIS RMS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C8248),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Record Management System',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),

                  // Progress indicator — linear when scanning, circular otherwise
                  SizedBox(
                    width: 240,
                    child: _scanProgress != null
                        ? Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _scanProgress,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1C8248),
                                      ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1C8248),
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusText,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
