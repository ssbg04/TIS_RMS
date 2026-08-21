import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/document_model.dart';

class FileFolderCard extends StatefulWidget {
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

  @override
  State<FileFolderCard> createState() => _FileFolderCardState();
}

class _FileFolderCardState extends State<FileFolderCard> {
  // True on Android/iOS — long press is the context menu trigger.
  bool get _isExcel {
    final name = widget.document.fileName.toLowerCase();
    return name.endsWith('.xlsx') ||
        name.endsWith('.xls') ||
        name.endsWith('.csv');
  }

  IconData get _fileIcon {
    final name = widget.document.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return Icons.image;
    }
    if (_isExcel) {
      return Icons.table_chart;
    }
    return Icons.insert_drive_file;
  }

  Color get _fileColor {
    final name = widget.document.fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Colors.redAccent;
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return Colors.blueAccent;
    }
    if (_isExcel) {
      return Colors.green;
    }
    return AppColors.primaryGreen;
  }

  Color get _statusColor {
    switch (widget.document.status) {
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
        value: 'select',
        child: Row(
          children: [
            Icon(Icons.check_box_outlined, size: 18),
            SizedBox(width: 12),
            Text('Select', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      if (_isExcel)
        const PopupMenuItem(
          value: 'convert_pdf',
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: Colors.deepOrangeAccent,
              ),
              SizedBox(width: 12),
              Text('Convert to PDF', style: TextStyle(fontSize: 14)),
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

    if (widget.userRole != 'teacher') {
      items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: AppColors.error),
              SizedBox(width: 12),
              Text(
                'Delete',
                style: TextStyle(fontSize: 14, color: AppColors.error),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }

  void _showContextMenu(BuildContext context, Offset position) {
    if (widget.isMultiSelectMode) return;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: _buildMenuItems(),
    ).then((value) {
      if (value != null && widget.onActionSelected != null) {
        widget.onActionSelected!(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGrid) return _buildGridCard(context);
    return _buildListRow(context);
  }

  // ════════════════════════════════════════
  // GRID CARD
  // ════════════════════════════════════════
  Widget _buildGridCard(BuildContext context) {
    return GestureDetector(
      // Desktop: right-click opens context menu
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      // Mobile: long press opens context menu
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: InkWell(
        onTap: widget.isMultiSelectMode
            ? () => widget.onSelectedChanged?.call(!widget.isSelected)
            : widget.onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        child: Ink(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primaryGreen.withValues(alpha: 0.05)
                : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite),
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primaryGreen
                  : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : Colors.grey.shade200),
              width: widget.isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (widget.isMultiSelectMode)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Checkbox(
                    value: widget.isSelected,
                    activeColor: AppColors.primaryGreen,
                    onChanged: widget.onSelectedChanged,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_fileIcon, size: 48, color: _fileColor),
                    const SizedBox(height: 10),
                    Text(
                      widget.document.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.document.studentName != null
                          ? 'Student Folders / ${widget.document.studentName}'
                          : (widget.document.studentLrn != null
                                ? 'Student Folders / LRN: ${widget.document.studentLrn}'
                                : '—'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(small: true),
                  ],
                ),
              ),
              // ⋮ button visible on both mobile and desktop
              if (!widget.isMultiSelectMode)
                Positioned(
                  top: 2,
                  right: 2,
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      size: 18,
                    ),
                    onSelected: widget.onActionSelected,
                    itemBuilder: (_) => _buildMenuItems(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // LIST ROW — matches the table header columns
  // ════════════════════════════════════════
  Widget _buildListRow(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: InkWell(
        onTap: widget.isMultiSelectMode
            ? () => widget.onSelectedChanged?.call(!widget.isSelected)
            : widget.onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: Ink(
          color: widget.isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.05)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (widget.isMultiSelectMode) ...[
                  Checkbox(
                    value: widget.isSelected,
                    activeColor: AppColors.primaryGreen,
                    onChanged: widget.onSelectedChanged,
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const SizedBox(width: 4),
                ],
                // File icon
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Icon(_fileIcon, size: 24, color: _fileColor),
                  ),
                ),
                const SizedBox(width: 8),

                // File name
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.document.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),

                // Student
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.document.studentName != null
                        ? 'Student Folders / ${widget.document.studentName}'
                        : (widget.document.studentLrn != null
                              ? 'Student Folders / LRN: ${widget.document.studentLrn}'
                              : '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),

                // Doc type
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.document.documentType ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),

                // Status
                Expanded(child: _buildStatusBadge()),

                // ⋮ Actions — visible on desktop & mobile
                SizedBox(
                  width: 40,
                  child: widget.isMultiSelectMode
                      ? const SizedBox.shrink()
                      : PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            size: 18,
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                          onSelected: widget.onActionSelected,
                          itemBuilder: (_) => _buildMenuItems(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        widget.document.status,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          color: _statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
