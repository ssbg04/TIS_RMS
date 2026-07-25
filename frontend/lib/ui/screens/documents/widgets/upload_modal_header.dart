import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class UploadModalHeaderWidget extends StatelessWidget {
  final int step;

  const UploadModalHeaderWidget({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  'Upload Documents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                // Stepper
                _buildStepper(),
              ],
            ),
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStep(1, 'Select Files', isActive: step >= 0, isDone: step >= 1),
        _buildConnector(active: step >= 1),
        _buildStep(2, 'Review & Upload', isActive: step >= 1, isDone: false),
      ],
    );
  }

  Widget _buildStep(int num, String label,
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
            color: isActive ? AppColors.primaryGreen : Colors.grey.shade200,
            border: Border.all(
              color: isActive
                  ? AppColors.primaryGreen
                  : Colors.grey.shade300,
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
                      color: isActive ? Colors.white : Colors.grey.shade500,
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
            color: isActive ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  Widget _buildConnector({required bool active}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 20,
        height: 1.5,
        color: active ? AppColors.primaryGreen : Colors.grey.shade300,
      ),
    );
  }
}
