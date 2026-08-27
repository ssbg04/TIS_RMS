import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';

/// Shows a reusable success dialog.
///
/// Parameters:
/// - [context] – The [BuildContext] to use for showing the dialog.
/// - [message] – The body message to display (e.g. "Student added successfully!").
/// - [title] – Optional dialog title. Defaults to `'Success'`.
/// - [buttonLabel] – Optional OK button label. Defaults to `'OK'`.
/// - [onDismissed] – Optional callback invoked after the user taps the button.
/// - [filePath] – Optional file path to show as a clickable link.
Future<void> showSuccessDialog(
  BuildContext context, {
  required String message,
  String title = 'Success',
  String buttonLabel = 'OK',
  VoidCallback? onDismissed,
  String? filePath,
}) {
  SoundService.playSuccess();
  HapticService.success();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (filePath != null && filePath.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Saved Location:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Tooltip(
                message: 'Click to open file location',
                child: InkWell(
                  onTap: () async {
                    try {
                      if (Platform.isWindows) {
                        final file = File(filePath);
                        if (await file.exists()) {
                          await Process.run('explorer', ['/select,', filePath]);
                        } else {
                          await Process.run('explorer', [file.parent.path]);
                        }
                      } else {
                        var uri = Uri.file(filePath);
                        if (!await launchUrl(uri)) {
                          final parentDir = File(filePath).parent.path;
                          uri = Uri.file(parentDir);
                          await launchUrl(uri);
                        }
                      }
                    } catch (e) {
                      debugPrint('Error opening path: $e');
                    }
                  },
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusSmall,
                      ),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_open_rounded,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filePath,
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.primaryGreen,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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

