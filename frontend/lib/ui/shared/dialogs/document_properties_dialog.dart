import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/file_icon_helper.dart';
import '../../../../domain/entities/document_model.dart';

class DocumentPropertiesDialog extends StatelessWidget {
  final DocumentModel document;

  const DocumentPropertiesDialog({
    super.key,
    required this.document,
  });

  static Future<void> show(
    BuildContext context, {
    required DocumentModel document,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => DocumentPropertiesDialog(document: document),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileColor = FileIconHelper.getColor(
      document.fileName,
      docType: document.documentType,
    );
    final fileIcon = FileIconHelper.getIcon(
      document.fileName,
      docType: document.documentType,
    );

    final extension = document.fileName.contains('.')
        ? '.${document.fileName.split('.').last.toUpperCase()}'
        : 'Unknown';

    Color statusColor;
    switch (document.status) {
      case 'Completed':
        statusColor = isDark ? Colors.green.shade300 : AppColors.success;
        break;
      case 'Archived':
        statusColor = isDark ? Colors.blue.shade300 : Colors.blue;
        break;
      default:
        statusColor = isDark ? AppColors.darkTextSecondary : Colors.grey;
    }

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Icon + Name + Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: fileColor.withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(fileIcon, color: fileColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.fileName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              document.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      splashRadius: 18,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 16),

                // Section: Document Details
                Text(
                  'DOCUMENT DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                _buildPropertyRow(
                  context,
                  label: 'Document Type',
                  value: document.documentType ?? 'General Document',
                  icon: Icons.description_outlined,
                ),
                _buildPropertyRow(
                  context,
                  label: 'Student',
                  value: document.studentName != null
                      ? '${document.studentName} (LRN: ${document.studentLrn ?? "—"})'
                      : (document.studentLrn != null
                          ? 'LRN: ${document.studentLrn}'
                          : '—'),
                  icon: Icons.person_outline_rounded,
                ),
                _buildPropertyRow(
                  context,
                  label: 'File Size',
                  value: document.size ?? '—',
                  icon: Icons.data_usage_rounded,
                ),
                _buildPropertyRow(
                  context,
                  label: 'File Extension',
                  value: extension,
                  icon: Icons.extension_outlined,
                ),
                _buildPropertyRow(
                  context,
                  label: 'Created / Uploaded',
                  value: formatModalDate(document.createdAt.toIso8601String()),
                  icon: Icons.calendar_today_outlined,
                ),
                if (document.filePath.isNotEmpty) ...[
                  _buildPropertyRow(
                    context,
                    label: 'File Path',
                    value: document.filePath,
                    icon: Icons.folder_open_outlined,
                    isCopyable: true,
                  ),
                ],

                const SizedBox(height: 24),

                // Actions Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    bool isCopyable = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isCopyable)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied to clipboard'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
