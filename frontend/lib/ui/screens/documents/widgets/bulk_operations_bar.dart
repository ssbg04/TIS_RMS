import 'package:flutter/foundation.dart';
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
  final VoidCallback? onBatchRestore;
  final VoidCallback? onBatchDelete;
  final bool isArchiveScreen;

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
    this.onBatchRestore,
    this.onBatchDelete,
    this.isArchiveScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isMobile = MediaQuery.of(context).size.width < 700 ||
        defaultTargetPlatform == TargetPlatform.android;

    return Container(
      height: 52,
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;

          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Exit Selection',
                onPressed: onCancel,
              ),
              const SizedBox(width: 4),
              Text(
                selectedCount == 0 ? 'Select items' : '$selectedCount selected',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  color: Colors.white,
                ),
                tooltip: allSelected ? 'Unselect All' : 'Select All',
                onPressed: onToggleSelectAll,
              ),
              if (selectedCount > 0) ...[
                if (!isCompact) ...[
                  IconButton(
                    icon: const Icon(Icons.print_rounded, color: Colors.white),
                    tooltip: 'Print',
                    onPressed: onBatchPrint,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white),
                    tooltip: 'Copy',
                    onPressed: onBatchCopy,
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Download',
                    onPressed: onBatchDownload,
                  ),
                  if (isArchiveScreen)
                    IconButton(
                      icon: const Icon(Icons.unarchive_rounded, color: Colors.white),
                      tooltip: 'Restore',
                      onPressed: onBatchRestore ?? () => onBatchStatus('Completed'),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.archive_rounded, color: Colors.white),
                      tooltip: 'Archive',
                      onPressed: onBatchArchive,
                    ),
                  if (isAdmin && onBatchDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      tooltip: 'Delete',
                      onPressed: onBatchDelete,
                    ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Download',
                    onPressed: onBatchDownload,
                  ),
                  IconButton(
                    icon: const Icon(Icons.print_rounded, color: Colors.white),
                    tooltip: 'Print',
                    onPressed: onBatchPrint,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    tooltip: 'More Actions',
                    onSelected: (val) {
                      switch (val) {
                        case 'copy':
                          onBatchCopy();
                          break;
                        case 'archive':
                          onBatchArchive();
                          break;
                        case 'restore':
                          if (onBatchRestore != null) {
                            onBatchRestore!();
                          } else {
                            onBatchStatus('Completed');
                          }
                          break;
                        case 'delete':
                          onBatchDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('Copy'),
                          ],
                        ),
                      ),
                      if (isArchiveScreen)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive_rounded, size: 20),
                              SizedBox(width: 10),
                              Text('Restore'),
                            ],
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_rounded, size: 20),
                              SizedBox(width: 10),
                              Text('Archive'),
                            ],
                          ),
                        ),
                      if (isAdmin && onBatchDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(width: 4),
            ],
          );
        },
      ),
    );
  }
}
