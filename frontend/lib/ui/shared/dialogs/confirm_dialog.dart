import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';

/// Shows a reusable confirmation dialog and returns true if confirmed, false/null otherwise.
///
/// Parameters:
/// - [context]      – BuildContext to show the dialog.
/// - [title]        – Dialog title (e.g. "Deactivate User?").
/// - [message]      – Body description or prompt.
/// - [confirmLabel] – Label for the positive/action button (defaults to 'Confirm').
/// - [cancelLabel]  – Label for the dismiss button (defaults to 'Cancel').
/// - [isDanger]     – When true, styles the action as destructive/danger (red).
/// - [confirmColor] – Custom color for the confirm button.
/// - [icon]         – Optional leading icon (defaults to help/warning icon).
/// - [iconColor]    – Optional color for the icon.
/// - [customBody]   – Optional additional widget below the message.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDanger = false,
  Color? confirmColor,
  IconData? icon,
  Color? iconColor,
  Widget? customBody,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveIconColor = iconColor ?? (isDanger ? AppColors.error : AppColors.primaryGreen);
  final effectiveConfirmColor = confirmColor ?? (isDanger ? AppColors.error : AppColors.primaryGreen);
  final effectiveIcon = icon ?? (isDanger ? Icons.warning_amber_rounded : Icons.help_outline_rounded);

  if (isDanger) {
    SoundService.playWarning();
    HapticService.warning();
  } else {
    SoundService.playConfirm();
    HapticService.medium();
  }

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
      final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
      final cardBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;

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
                color: effectiveIconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(effectiveIcon, color: effectiveIconColor, size: 24),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
                height: 1.4,
              ),
            ),
            if (customBody != null) ...[
              const SizedBox(height: 12),
              customBody,
            ],
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  foregroundColor: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                child: Text(
                  cancelLabel.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectiveConfirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  confirmLabel.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
