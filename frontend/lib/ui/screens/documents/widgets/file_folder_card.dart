import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/document_model.dart';

class FileFolderCard extends StatelessWidget {
  final DocumentModel document;
  final bool isGrid;
  final String userRole;
  final VoidCallback onTap;
  final void Function(String)? onActionSelected;
  final void Function(int studentId)? onViewProfile;

  // Multi-select features
  final bool isMultiSelectMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const FileFolderCard({
    super.key,
    required this.document,
    required this.isGrid,
    required this.userRole,
    required this.onTap,
    this.onActionSelected,
    this.onViewProfile,
    this.isMultiSelectMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  IconData get _fileIcon {
    final name = document.fileName.toLowerCase();
    if (name.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  Color get _fileColor {
    final name = document.fileName.toLowerCase();
    if (name.endsWith('.pdf')) {
      return Colors.redAccent;
    }
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return Colors.blueAccent;
    }
    return AppColors.primaryGreen;
  }

  Color get _statusColor {
    switch (document.status) {
      case 'Completed':
        return AppColors.success;
      case 'Archived':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'preview',
        child: Row(
          children: [
            Icon(Icons.visibility, size: 18),
            SizedBox(width: 12),
            Text('Preview', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'queue',
        child: Row(
          children: [
            Icon(Icons.print, size: 18),
            SizedBox(width: 12),
            Text('Add to Print List', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'copy',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            SizedBox(width: 12),
            Text('Copy', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'download',
        child: Row(
          children: [
            Icon(Icons.download, size: 18),
            SizedBox(width: 12),
            Text('Download', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'view_profile',
        child: Row(
          children: [
            Icon(Icons.person, size: 18, color: AppColors.primaryGreen),
            SizedBox(width: 12),
            Text('View Student Profile', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    ];

    if (userRole != 'teacher') {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: AppColors.error),
            SizedBox(width: 12),
            Text('Delete', style: TextStyle(fontSize: 14, color: AppColors.error)),
          ],
        ),
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (isGrid) return _buildGridCard();
    return _buildListRow();
  }

  // ════════════════════════════════════════
  // GRID CARD
  // ════════════════════════════════════════
  Widget _buildGridCard() {
    return InkWell(
      onTap: isMultiSelectMode ? () => onSelectedChanged?.call(!isSelected) : onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.05)
              : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            if (isMultiSelectMode)
              Positioned(
                top: 4,
                left: 4,
                child: Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primaryGreen,
                  onChanged: onSelectedChanged,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _fileColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_fileIcon, size: 40, color: _fileColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    document.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    document.studentName ?? document.studentLrn ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusBadge(small: true),
                ],
              ),
            ),
            if (!isMultiSelectMode)
              Positioned(
                top: 2,
                right: 2,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textSecondary, size: 18),
                  onSelected: onActionSelected,
                  itemBuilder: (_) => _buildMenuItems(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // LIST ROW — matches the table header columns
  // ════════════════════════════════════════
  Widget _buildListRow() {
    return InkWell(
      onTap: isMultiSelectMode ? () => onSelectedChanged?.call(!isSelected) : onTap,
      child: Container(
        color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.05) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (isMultiSelectMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primaryGreen,
                onChanged: onSelectedChanged,
              ),
              const SizedBox(width: 8),
            ] else ...[
              const SizedBox(width: 4),
            ],
            // File icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _fileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_fileIcon, size: 18, color: _fileColor),
            ),
            const SizedBox(width: 8),

            // File name
            Expanded(
              flex: 3,
              child: Text(
                document.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary),
              ),
            ),

            // Student
            Expanded(
              flex: 2,
              child: Text(
                document.studentName ??
                    (document.studentLrn != null
                        ? 'LRN: ${document.studentLrn}'
                        : '—'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),

            // Doc type
            Expanded(
              flex: 2,
              child: Text(
                document.documentType ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),

            // Status
            Expanded(child: _buildStatusBadge()),

            // Actions
            SizedBox(
              width: 40,
              child: isMultiSelectMode
                  ? const SizedBox.shrink()
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: AppColors.textSecondary),
                      onSelected: onActionSelected,
                      itemBuilder: (_) => _buildMenuItems(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        document.status,
        style: TextStyle(
            fontSize: small ? 10 : 11,
            color: _statusColor,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}