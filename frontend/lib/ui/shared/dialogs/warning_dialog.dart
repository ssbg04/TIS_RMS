import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';

/// Shows a reusable warning dialog.
///
/// Parameters:
/// - [context]     – The [BuildContext] to use for showing the dialog.
/// - [title]       – The dialog title (e.g. "Warning").
/// - [message]     – The body message to display.
/// - [buttonLabel] – Optional button label. Defaults to `'Got It'`.
/// - [onDismissed] – Optional callback invoked after the user taps the button.
void showWarningDialog(
  BuildContext context,
  String title,
  String message, {
  String buttonLabel = 'Got It',
  VoidCallback? onDismissed,
}) {
  SoundService.playWarning();
  HapticService.warning();

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  final cardBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDismissed?.call();
              },
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    },
  );
}
