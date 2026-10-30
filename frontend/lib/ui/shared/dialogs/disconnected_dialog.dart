import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
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
    if (!context.mounted) return;
    if (_isShowing) return;
    _isShowing = true;
    try {
      SoundService.playError();
      HapticService.error();
    } catch (_) {}

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

  Future<void> _handleReconnect() async {
    setState(() {
      _isReconnecting = true;
    });

    try {
      final found = await ServerDiscoveryService.resolveServerWithFallback();

      if (!mounted) return;

      if (found != null) {
        SoundService.playSuccess();
        HapticService.success();
        Navigator.of(context).pop();
        widget.onReconnected?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connection restored successfully.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isReconnecting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isReconnecting = false;
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
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 40,
        vertical: 24,
      ),
      contentPadding: EdgeInsets.all(isMobile ? 20 : 24),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Centered icon container (matching AppErrorState)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: AppSizes.p16),

            // Title
            Text(
              'Connection Lost',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.p8),

            // Friendly, non-technical message
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Please check your Wi-Fi, internet connection, or mobile data and try again.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            if (_isReconnecting) ...[
              const SizedBox(height: AppSizes.p16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButtonLoader(
                    size: 16,
                    strokeWidth: 2.0,
                    color: AppColors.primaryGreen,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Reconnecting…',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSizes.p24),

            // Action Buttons: Stacked on mobile, side-by-side on desktop
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isReconnecting ? null : _handleReconnect,
                    icon: _isReconnecting
                        ? const SizedBox.shrink()
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _isReconnecting ? 'Reconnecting…' : 'Reconnect',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isReconnecting ? null : _closeApp,
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: const Text(
                      'Close App',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      side: BorderSide(
                        color: (isDark ? Colors.red.shade300 : Colors.red.shade700).withValues(alpha: 0.4),
                      ),
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isReconnecting ? null : _closeApp,
                      icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                      label: const Text(
                        'Close App',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.red.shade300 : Colors.red.shade700,
                        side: BorderSide(
                          color: (isDark ? Colors.red.shade300 : Colors.red.shade700).withValues(alpha: 0.4),
                        ),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isReconnecting ? null : _handleReconnect,
                      icon: _isReconnecting
                          ? const SizedBox.shrink()
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isReconnecting ? 'Reconnecting…' : 'Reconnect',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        ),
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
