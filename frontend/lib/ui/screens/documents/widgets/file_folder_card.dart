import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/file_icon_helper.dart';
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
  final bool isArchiveScreen;

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
    this.isArchiveScreen = false,
  });

  @override
  State<FileFolderCard> createState() => _FileFolderCardState();
}

class _FileFolderCardState extends State<FileFolderCard> {
  bool get _isExcel => FileIconHelper.isExcel(
        widget.document.fileName,
        docType: widget.document.documentType,
      );

  IconData get _fileIcon => FileIconHelper.getIcon(
        widget.document.fileName,
        docType: widget.document.documentType,
      );

  Color get _fileColor => FileIconHelper.getColor(
        widget.document.fileName,
        docType: widget.document.documentType,
      );

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
        value: 'properties',
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.primaryGreen,
            ),
            SizedBox(width: 12),
            Text('Properties', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
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
      if (widget.isArchiveScreen) {
        items.add(
          const PopupMenuItem(
            value: 'restore',
            child: Row(
              children: [
                Icon(
                  Icons.unarchive_outlined,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                SizedBox(width: 12),
                Text('Restore', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      } else {
        items.add(
          const PopupMenuItem(
            value: 'archive',
            child: Row(
              children: [
                Icon(
                  Icons.archive_outlined,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                SizedBox(width: 12),
                Text('Archive', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      }
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
  // GRID CARD — Compact: Filename and Icon only, no chips or 3 dots
  // ════════════════════════════════════════
  Widget _buildGridCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                : (isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite),
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_fileIcon, size: 42, color: _fileColor),
                      const SizedBox(height: 8),
                      Text(
                        widget.document.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // LIST ROW — Matches folder style: Name, size below, date right, 3 dots
  // ════════════════════════════════════════
  Widget _buildListRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                const SizedBox(width: 12),

                // File name & Size below
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.document.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FileIconHelper.formatFileSize(
                          widget.document.fileSize ?? widget.document.size,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Date on right side
                Text(
                  formatShortDate(widget.document.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.textMuted,
                  ),
                ),

                const SizedBox(width: 4),

                // ⋮ Actions — visible on desktop & mobile
                SizedBox(
                  width: 36,
                  child: widget.isMultiSelectMode
                      ? const SizedBox.shrink()
                      : PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
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
}
