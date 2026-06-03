import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// Shows a reusable success dialog.
///
/// Parameters:
/// - [context] – The [BuildContext] to use for showing the dialog.
/// - [message] – The body message to display (e.g. "Student added successfully!").
/// - [title] – Optional dialog title. Defaults to `'Success'`.
/// - [buttonLabel] – Optional OK button label. Defaults to `'OK'`.
/// - [onDismissed] – Optional callback invoked after the user taps the button.
void showSuccessDialog(
  BuildContext context, {
  required String message,
  String title = 'Success',
  String buttonLabel = 'OK',
  VoidCallback? onDismissed,
}) {
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
              Icons.check_circle,
              color: AppColors.success,
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
                backgroundColor: AppColors.success,
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