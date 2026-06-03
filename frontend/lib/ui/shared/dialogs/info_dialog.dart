import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// Shows a reusable informational / warning dialog.
///
/// Parameters:
/// - [context]      – BuildContext to use for showing the dialog.
/// - [message]      – Body message to display.
/// - [title]        – Dialog title. Defaults to `'Notice'`.
/// - [icon]         – Leading icon. Defaults to [Icons.info_outline].
/// - [iconColor]    – Icon color. Defaults to [AppColors.info].
/// - [buttonLabel]  – OK button label. Defaults to `'Got It'`.
/// - [buttonColor]  – OK button background. Defaults to [AppColors.info].
/// - [onDismissed]  – Optional callback invoked after the user taps the button.
void showInfoDialog(
  BuildContext context, {
  required String message,
  String title = 'Notice',
  IconData icon = Icons.info_outline,
  Color iconColor = AppColors.info,
  String buttonLabel = 'Got It',
  Color? buttonColor,
  VoidCallback? onDismissed,
}) {
  final btnColor = buttonColor ?? iconColor;

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
            Icon(icon, color: iconColor, size: 28),
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
                backgroundColor: btnColor,
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
