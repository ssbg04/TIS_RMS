import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/utils/download_service.dart';

/// Shows a reusable success dialog.
///
/// Parameters:
/// - [context] – The [BuildContext] to use for showing the dialog.
/// - [message] – The body message to display (e.g. "Student added successfully!").
/// - [title] – Optional dialog title. Defaults to `'Success'`.
/// - [buttonLabel] – Optional OK button label. Defaults to `'OK'`.
/// - [onDismissed] – Optional callback invoked after the user taps the button.
/// - [filePath] – Optional file path to show as a clickable link.
/// - [notes] – Optional notes or instructions to display in an info callout.
Future<void> showSuccessDialog(
  BuildContext context, {
  required String message,
  String title = 'Success',
  String buttonLabel = 'OK',
  VoidCallback? onDismissed,
  String? filePath,
  String? notes,
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
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue.shade200
                              : Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                      await DownloadService.openStorageFolder(filePath);
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
          if (filePath != null && filePath.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkBorder
                            : Colors.grey.shade400,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        await DownloadService.openStorageFolder(filePath);
                      } catch (e) {
                        debugPrint('Error opening folder: $e');
                      }
                    },
                    icon: const Icon(Icons.folder_open_outlined, size: 17),
                    label: const Text(
                      'VIEW IN FOLDER',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        await DownloadService.openDownloadedFile(filePath);
                      } catch (e) {
                        debugPrint('Error opening file: $e');
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text(
                      'OPEN FILE',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onDismissed?.call();
                },
                child: Text(
                  'CLOSE',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else ...[
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
        ],
      );
    },
  );
}

