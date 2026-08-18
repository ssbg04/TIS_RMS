import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/haptic_service.dart';

/// Shows a reusable error dialog.
///
/// Parameters:
/// - [context] – The [BuildContext] to use for showing the dialog.
/// - [title] – The dialog title (e.g. "Error").
/// - [message] – The body message to display.
/// - [buttonLabel] – Optional button label. Defaults to `'OK'`.
/// - [onDismissed] – Optional callback invoked after the user taps the button.
void showErrorDialog(
  BuildContext context,
  String title,
  String message, {
  String buttonLabel = 'OK',
  VoidCallback? onDismissed,
}) {
  HapticService.error();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDismissed?.call();
              },
              child: Text(buttonLabel),
            ),
          ),
        ],
      );
    },
  );
}
