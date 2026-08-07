import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class DownloadGuideDialog extends StatelessWidget {
  const DownloadGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWindows = Platform.isWindows;
    final isAndroid = Platform.isAndroid;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSizes.p16),
                  Text(
                    'Download Guide',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p24),
              Text(
                'Where do my downloaded documents go?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              if (isWindows) ...[
                Text(
                  'On Windows, your downloaded documents are saved to:',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: SelectableText(
                    'C:\\Users\\<Your Username>\\Downloads\\TIS_RMS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can quickly find them by opening File Explorer and going to your standard Downloads folder.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ] else if (isAndroid) ...[
                Text(
                  'On Android, your downloaded documents are saved to:',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: SelectableText(
                    'Internal Storage > Download > TIS_RMS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can access them using your device\'s "Files" or "My Files" app.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                Text(
                  'Downloads are saved to your device\'s standard downloads directory inside a "TIS_RMS" folder.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.p24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('GOT IT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
