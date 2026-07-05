import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusText = 'Starting up…';
  double? _scanProgress; // null = indeterminate, 0.0–1.0 = progress

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── Server resolution logic ────────────────────────────────────────────────

  Future<void> _resolveServer() async {
    // Windows: always local, no need to scan
    if (!kIsWeb && Platform.isWindows) {
      ApiConstants.setBaseUrl('http://127.0.0.1:${ApiConstants.port}');
      return;
    }

    // Android / other: check saved URL first
    final saved = await ServerDiscoveryService.getSaved();
    if (saved != null) {
      setState(() => _statusText = 'Connecting to saved server…');
      final alive = await ServerDiscoveryService.ping(saved);
      if (alive) {
        ApiConstants.setBaseUrl(saved);
        return;
      }
      // Saved server is gone — clear it and scan
      await ServerDiscoveryService.clear();
    }

    // Run subnet scan
    await _runScan();
  }

  Future<void> _runScan() async {
    // Get own IP / subnet prefixes first
    setState(() {
      _statusText = 'Detecting network…';
      _scanProgress = null;
    });

    final prefixes = await ServerDiscoveryService.getSubnetPrefixes();

    if (prefixes.isEmpty) {
      // No LAN interface found — go straight to manual entry
      await _showManualEntryDialog(reason: 'No Wi-Fi or LAN connection detected.');
      return;
    }

    final subnetLabel = prefixes.map((p) => '${p}0/24').join(', ');
    setState(() {
      _statusText = 'Scanning $subnetLabel…';
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
          _statusText = 'Server found: $found';
          _scanProgress = 1.0;
        });
      }
      await Future.delayed(const Duration(milliseconds: 600));
    } else {
      await _showManualEntryDialog(
        reason: 'No TIS RMS server was found on your network.',
      );
    }
  }

  // ── Manual entry dialog ────────────────────────────────────────────────────

  Future<void> _showManualEntryDialog({required String reason}) async {
    final controller = TextEditingController();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.wifi_find, color: AppColors.primaryGreen, size: 36),
        title: const Text('Server Not Found', textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Server IP Address',
                hintText: '192.168.1.x',
                prefixIcon: const Icon(Icons.dns_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Re-run scan
              await _runScan();
            },
            child: const Text('Retry Scan',
                style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                final url = ip.startsWith('http')
                    ? ip
                    : 'http://$ip:${ApiConstants.port}';
                ServerDiscoveryService.save(url);
                ApiConstants.setBaseUrl(url);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Column(
        children: [
          if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
            const SizedBox(
              height: 32,
              child: WindowCaption(
                brightness: Brightness.dark,
                backgroundColor: AppColors.primaryGreen,
                title: Text('TIS RMS',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', width: 150, height: 150),
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
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1C8248)),
                                ),
                              ),
                            ],
                          )
                        : const LinearProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1C8248)),
                            backgroundColor: Color(0xFFE8F5E9),
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