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

  const FileFolderCard({
    super.key,
    required this.document,
    required this.isGrid,
    required this.userRole,
    required this.onTap,
    this.onActionSelected,
    this.onViewProfile,
  });

  IconData get _fileIcon {
    final name = document.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color get _fileColor {
    final name = document.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Colors.redAccent;
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) return Colors.blueAccent;
    return AppColors.primaryGreen;
  }

  Color get _statusColor {
    switch (document.status) {
      case 'Verified':
        return AppColors.success;
      case 'Pending':
        return Colors.orange;
      case 'Draft':
        return Colors.grey;
      case 'Archived':
        return Colors.blue;
      case 'Rejected':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
          value: 'preview',
          child: ListTile(
              dense: true,
              leading: Icon(Icons.visibility, size: 18),
              title: Text('Preview', style: TextStyle(fontSize: 14)))),
      const PopupMenuItem(
          value: 'queue',
          child: ListTile(
              dense: true,
              leading: Icon(Icons.print, size: 18),
              title: Text('Add to Print Queue',
                  style: TextStyle(fontSize: 14)))),
      const PopupMenuItem(
          value: 'download',
          child: ListTile(
              dense: true,
              leading: Icon(Icons.download, size: 18),
              title: Text('Download', style: TextStyle(fontSize: 14)))),
      const PopupMenuDivider(),
      const PopupMenuItem(
          value: 'view_profile',
          child: ListTile(
              dense: true,
              leading:
                  Icon(Icons.person, size: 18, color: AppColors.primaryGreen),
              title: Text('View Student Profile',
                  style: TextStyle(fontSize: 14)))),
    ];

    if (userRole != 'teacher') {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
          value: 'delete',
          child: ListTile(
              dense: true,
              leading:
                  Icon(Icons.delete_outline, size: 18, color: AppColors.error),
              title: Text('Delete',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.error)))));
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
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
              child: PopupMenuButton<String>(
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