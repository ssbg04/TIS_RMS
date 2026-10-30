import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/theme_extension.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData? icon;

  const AppErrorState({
    super.key,
    this.title = 'Unable to Load Data',
    this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon,
  });

  /// Factory constructor that presents a polite, non-technical message
  /// guiding the user to check network connection (Wi-Fi, internet, mobile data).
  factory AppErrorState.fromError({
    Key? key,
    dynamic error,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
    String? customTitle,
    String? customMessage,
  }) {
    return AppErrorState(
      key: key,
      title: customTitle ?? 'Unable to Load Data',
      message: customMessage ?? _friendlyMessage(error),
      onRetry: onRetry,
      retryLabel: retryLabel,
      icon: Icons.wifi_off_rounded,
    );
  }

  static String _friendlyMessage(dynamic error) {
    // If a clean custom message was passed, keep it only if not raw technical jargon
    if (error != null) {
      final str = error.toString();
      final lower = str.toLowerCase();
      final isTechnical = lower.contains('exception') ||
          lower.contains('socket') ||
          lower.contains('xmlhttprequest') ||
          lower.contains('host lookup') ||
          lower.contains('handshake') ||
          lower.contains('dio') ||
          lower.contains('http') ||
          lower.contains('stack trace') ||
          lower.contains('status code') ||
          lower.contains('typeerror') ||
          lower.contains('nosuchmethod') ||
          lower.contains('internal server');

      if (!isTechnical && str.length < 120 && !str.startsWith('Error:')) {
        return str;
      }
    }

    return 'Please check your Wi-Fi, internet connection, or mobile data and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.wifi_off_rounded,
                size: 44,
                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.p8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message ?? 'Please check your Wi-Fi, internet connection, or mobile data and try again.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSizes.p20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p20,
                    vertical: AppSizes.p12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
