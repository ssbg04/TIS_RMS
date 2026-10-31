import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/navigation/navigation_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';
import '../../screens/login/login_screen.dart';

/// Single-flight modal that alerts the user when their session has ended
/// mid-usage, guiding them cleanly back to the Login Screen.
class SessionExpiredDialog {
  static bool _isShowing = false;

  /// Shows non-technical session expired alert and transitions to LoginScreen.
  static Future<void> show([BuildContext? context]) async {
    final ctx = context ?? NavigationService.currentContext;
    if (ctx == null || _isShowing) return;

    _isShowing = true;

    try {
      SoundService.playWarning();
      HapticService.warning();
    } catch (_) {}

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            ),
            backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: isDark ? 0.22 : 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Colors.amber,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Session Ended',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'For your account\'s security, your login session has ended. Please sign in again to continue using TIS RMS.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    _isShowing = false;

                    // 1. Wipe credentials
                    try {
                      const storage = FlutterSecureStorage();
                      await storage.delete(key: 'jwt_token');
                      await storage.delete(key: 'remember_me');
                    } catch (_) {}
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('jwt_token');
                      await prefs.remove('rememberMe');
                    } catch (_) {}

                    // 2. Navigate and destroy back-stack to LoginScreen
                    final navigator = NavigationService.currentState;
                    if (navigator != null) {
                      navigator.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    ),
                  ),
                  child: const Text(
                    'SIGN IN AGAIN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    _isShowing = false;
  }
}

