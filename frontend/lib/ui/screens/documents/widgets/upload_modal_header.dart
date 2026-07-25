import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'dart:io';

class UploadModalHeaderWidget extends StatelessWidget {
  final int step;
  
  const UploadModalHeaderWidget({super.key, required this.step});

  Widget _buildStepChip(int stepNum, String label, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              '$stepNum',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 28,
        height: 2,
        color: active ? AppColors.primaryGreen : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                color: AppColors.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Upload Documents',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (Platform.isWindows)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStepChip(1, 'Select Files', step >= 0),
            _buildStepConnector(step >= 1),
            _buildStepChip(2, 'Review & Upload', step >= 1),
          ],
        ),
      ],
    );
  }
}
