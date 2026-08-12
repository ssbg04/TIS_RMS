import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'custom_modal.dart';

class ViewActivityModal extends StatelessWidget {
  final String title;
  final String description;
  final String date;
  final String? performedBy;
  final String? action;
  final Color? actionColor;
  final IconData icon;

  const ViewActivityModal({
    super.key,
    required this.title,
    required this.description,
    required this.date,
    this.performedBy,
    this.action,
    this.actionColor,
    required this.icon,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    required String date,
    String? performedBy,
    String? action,
    Color? actionColor,
    required IconData icon,
  }) {
    return CustomModal.show(
      context: context,
      title: 'Activity Details',
      icon: icon,
      maxWidth: 500,
      content: ViewActivityModal(
        title: title,
        description: description,
        date: date,
        performedBy: performedBy,
        action: action,
        actionColor: actionColor,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 6),
                Text(
                  action!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: actionColor ?? AppColors.primaryGreen,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Description',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                   color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Metadata
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date & Time',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (performedBy != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performed By',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        performedBy!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
