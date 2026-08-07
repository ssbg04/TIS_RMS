import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class UploadModalHeaderWidget extends StatelessWidget {
  final int step;

  const UploadModalHeaderWidget({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Upload Documents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Stepper
                _buildStepper(context, isDark),
              ],
            ),
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStep(context, isDark, 1, 'Select Files', isActive: step >= 0, isDone: step >= 1),
        _buildConnector(isDark, active: step >= 1),
        _buildStep(context, isDark, 2, 'Review & Upload', isActive: step >= 1, isDone: false),
      ],
    );
  }

  Widget _buildStep(BuildContext context, bool isDark, int num, String label,
      {required bool isActive, required bool isDone}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primaryGreen : (isDark ? AppColors.darkSurface2 : Colors.grey.shade200),
            border: Border.all(
              color: isActive
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : Text(
                    '$num',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : (isDark ? AppColors.darkTextMuted : Colors.grey.shade500),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? AppColors.primaryGreen : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          child: Text(label),
        ),
      ],
    );
  }

  Widget _buildConnector(bool isDark, {required bool active}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 20,
        height: 1.5,
        color: active ? AppColors.primaryGreen : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
    );
  }
}
