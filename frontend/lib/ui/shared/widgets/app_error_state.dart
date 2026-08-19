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

  /// Factory constructor that inspects the raw error to present
  /// an appropriate title, icon, and user-friendly explanation.
  factory AppErrorState.fromError({
    Key? key,
    required dynamic error,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
    String? customTitle,
  }) {
    final isConn = _isConnectionError(error);
    final title = customTitle ?? (isConn ? 'No Connection to Server' : 'Unable to Load Data');
    final message = _formatErrorMessage(error, isConn);
    final icon = isConn ? Icons.wifi_off_rounded : Icons.error_outline_rounded;

    return AppErrorState(
      key: key,
      title: title,
      message: message,
      onRetry: onRetry,
      retryLabel: retryLabel,
      icon: icon,
    );
  }

  static bool _isConnectionError(dynamic error) {
    if (error == null) return false;
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('network is unreachable') ||
        str.contains('connection timed out') ||
        str.contains('connecttimeout') ||
        str.contains('connectionerror') ||
        str.contains('failed host lookup') ||
        str.contains('clientexception') ||
        str.contains('handshakeexception') ||
        str.contains('no internet') ||
        str.contains('offline') ||
        str.contains('network error');
  }

  static String _formatErrorMessage(dynamic error, bool isConnection) {
    if (isConnection) {
      return 'Could not connect to the server. Please check your network connection and try again.';
    }
    if (error == null) {
      return 'An unexpected error occurred while retrieving data.';
    }
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring(11);
    }
    return raw;
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
            Icon(
              icon ?? Icons.wifi_off_rounded,
              size: 56,
              color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
            ),
            const SizedBox(height: AppSizes.p16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSizes.p8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Text(
                  message!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
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
