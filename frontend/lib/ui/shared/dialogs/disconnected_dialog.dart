import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/server_discovery.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';
import '../widgets/app_button_loader.dart';

class DisconnectedDialog extends StatefulWidget {
  final VoidCallback? onReconnected;

  const DisconnectedDialog({super.key, this.onReconnected});

  static bool _isShowing = false;

  /// Shows the Disconnected Dialog if not already visible.
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onReconnected,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    SoundService.playError();
    HapticService.error();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => DisconnectedDialog(onReconnected: onReconnected),
    );

    _isShowing = false;
  }

  @override
  State<DisconnectedDialog> createState() => _DisconnectedDialogState();
}

class _DisconnectedDialogState extends State<DisconnectedDialog> {
  bool _isReconnecting = false;
  bool _stillNotConnected = false;
  String _statusMessage = '';
  String? _errorMessage;

  Future<void> _handleReconnect() async {
    setState(() {
      _isReconnecting = true;
      _statusMessage = 'Checking LAN connection…';
      _errorMessage = null;
    });

    try {
      final found = await ServerDiscoveryService.resolveServerWithFallback(
        onProgress: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
      );

      if (!mounted) return;

      if (found != null) {
        SoundService.playSuccess();
        HapticService.success();
        Navigator.of(context).pop();
        widget.onReconnected?.call();

        // Show feedback snackbar
        final isLan = found.contains('192.168.') ||
            found.contains('10.') ||
            found.contains('172.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isLan
                        ? 'Connected to Local Server: $found'
                        : 'Connected to Tunnel Domain ($found)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _isReconnecting = false;
          _stillNotConnected = true;
          _errorMessage =
              'Reconnection attempt failed. The TIS RMS server is unreachable on your Local Network (LAN) and Cloud Tunnel.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReconnecting = false;
          _stillNotConnected = true;
          _errorMessage = 'Reconnection error: $e';
        });
      }
    }
  }

  void _closeApp() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemNavigator.pop();
    } else if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      contentPadding: EdgeInsets.all(isMobile ? 20 : 24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Disconnected Pulse Icon Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: isDark ? 0.18 : 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Icon(
                _stillNotConnected
                    ? Icons.cloud_off_rounded
                    : Icons.wifi_off_rounded,
                color: Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              _stillNotConnected ? 'Still Not Connected' : 'Connection Lost',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              _stillNotConnected
                  ? 'Reconnection attempt failed. The TIS RMS server remains unreachable on your Local Network (LAN) and Cloud Tunnel.\n\nWould you like to try again or close the application?'
                  : 'Unable to reach the TIS RMS server. The system checks your Local Network (LAN) first, then falls back to the Cloud Tunnel.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Target URL info box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Target: ${ApiConstants.baseUrl}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            if (_isReconnecting) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppButtonLoader(
                    size: 18,
                    strokeWidth: 2.2,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            if (_errorMessage != null && !_isReconnecting) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                // Secondary: Close App
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                      label: const Text(
                        'CLOSE APP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                      ),
                      onPressed: _isReconnecting ? null : _closeApp,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Primary: Reconnect / Retry
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      icon: _isReconnecting
                          ? const SizedBox.shrink()
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isReconnecting
                            ? 'RECONNECTING…'
                            : (_stillNotConnected ? 'RETRY' : 'RECONNECT'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                      ),
                      onPressed: _isReconnecting ? null : _handleReconnect,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
