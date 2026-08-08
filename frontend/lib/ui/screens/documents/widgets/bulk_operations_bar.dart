import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/theme_extension.dart';

class BulkOperationsBar extends StatelessWidget {
  final int selectedCount;
  final bool allSelected;
  final bool isAdmin;
  final VoidCallback onCancel;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onBatchPrint;
  final VoidCallback onBatchCopy;
  final VoidCallback onBatchDownload;
  final ValueChanged<String> onBatchStatus;
  final VoidCallback onBatchArchive;
  final VoidCallback? onBatchDelete;

  const BulkOperationsBar({
    super.key,
    required this.selectedCount,
    required this.allSelected,
    required this.isAdmin,
    required this.onCancel,
    required this.onToggleSelectAll,
    required this.onBatchPrint,
    required this.onBatchCopy,
    required this.onBatchDownload,
    required this.onBatchStatus,
    required this.onBatchArchive,
    this.onBatchDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final buttonColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.primaryGreen.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Tooltip(
              message: 'Cancel selection',
              child: IconButton(
                icon: Icon(Icons.close, color: buttonColor),
                onPressed: onCancel,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              selectedCount == 0 ? 'Select items' : '$selectedCount selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: allSelected ? 'Unselect All' : 'Select All',
              child: IconButton(
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  color: buttonColor,
                ),
                onPressed: onToggleSelectAll,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 1,
              height: 24,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Print',
              child: IconButton(
                icon: Icon(Icons.print_rounded, color: buttonColor),
                onPressed: selectedCount == 0 ? null : onBatchPrint,
              ),
            ),
            Tooltip(
              message: 'Copy',
              child: IconButton(
                icon: Icon(Icons.copy_rounded, color: buttonColor),
                onPressed: selectedCount == 0 ? null : onBatchCopy,
              ),
            ),
            Tooltip(
              message: 'Download',
              child: IconButton(
                icon: Icon(Icons.download_rounded, color: buttonColor),
                onPressed: selectedCount == 0 ? null : onBatchDownload,
              ),
            ),
            Tooltip(
              message: 'Complete',
              child: IconButton(
                icon: Icon(Icons.check_circle_outline_rounded, color: buttonColor),
                onPressed: selectedCount == 0 ? null : () => onBatchStatus('Completed'),
              ),
            ),
            Tooltip(
              message: 'Archive',
              child: IconButton(
                icon: Icon(Icons.archive_outlined, color: buttonColor),
                onPressed: selectedCount == 0 ? null : onBatchArchive,
              ),
            ),
            if (isAdmin) ...[
              Tooltip(
                message: 'Delete',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: selectedCount == 0 ? null : onBatchDelete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
