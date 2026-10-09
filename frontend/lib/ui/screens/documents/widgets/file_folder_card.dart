import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/file_icon_helper.dart';
import '../../../../domain/entities/document_model.dart';

class FileFolderCard extends StatefulWidget {
  final DocumentModel document;
  final bool isGrid;
  final String userRole;
  final VoidCallback onTap;
  final VoidCallback? onIconTap;
  final String? token;
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
    this.onIconTap,
    this.token,
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
  static final bool _isMobileOrAndroid =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static String? _cachedToken;

  @override
  void initState() {
    super.initState();
    if (widget.token == null && _cachedToken == null) {
      const FlutterSecureStorage().read(key: 'jwt_token').then((t) {
        if (mounted && t != null) {
          setState(() => _cachedToken = t);
        }
      });
    }
  }

  String? get _effectiveToken => widget.token ?? _cachedToken;

  bool get _hasPreview {
    final ext = widget.document.fileName.toLowerCase().split('.').last;
    return const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'pdf'}.contains(ext);
  }

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
      const PopupMenuItem(
        value: 'open_with',
        child: Row(
          children: [
            Icon(Icons.apps_rounded, size: 18),
            SizedBox(width: 12),
            Text('Open With', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      if (_isExcel)
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_document, size: 18, color: Colors.orange),
              SizedBox(width: 12),
              Text('Edit', style: TextStyle(fontSize: 14, color: Colors.orange)),
            ],
          ),
        ),
      const PopupMenuItem(
        value: 'upload_version',
        child: Row(
          children: [
            Icon(Icons.upload_file_rounded, size: 18, color: AppColors.primaryGreen),
            SizedBox(width: 12),
            Text('Upload New Version', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'version_history',
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 18),
            SizedBox(width: 12),
            Text('Version History', style: TextStyle(fontSize: 14)),
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
    final RenderBox? overlay =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
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
  // GRID CARD — 2-section design optimized for mobile & desktop
  // ════════════════════════════════════════
  Widget _buildGridCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseCardColor =
        isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;
    final cardColor = widget.isSelected
        ? Color.alphaBlend(
            AppColors.primaryGreen.withValues(alpha: isDark ? 0.22 : 0.12),
            baseCardColor,
          )
        : baseCardColor;

    return RepaintBoundary(
      child: GestureDetector(
        // Desktop: right-click opens context menu
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        // Mobile: long press opens context menu
        onLongPressStart: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.isMultiSelectMode
                ? () => widget.onSelectedChanged?.call(!widget.isSelected)
                : widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.primaryGreen
                      : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                  width: widget.isSelected ? 1.5 : 1.0,
                ),
                boxShadow: _isMobileOrAndroid
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top section: File preview canvas with icon & quick actions
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (widget.isMultiSelectMode) {
                          widget.onSelectedChanged?.call(!widget.isSelected);
                        } else {
                          widget.onTap();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _fileColor.withValues(
                            alpha: isDark ? 0.09 : 0.06,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(_fileIcon, size: 36, color: _fileColor),
                            if (_hasPreview && _effectiveToken != null)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(11),
                                  ),
                                  child: Image.network(
                                    '${ApiConstants.baseUrl}/documents/${widget.document.id}/thumbnail?token=$_effectiveToken',
                                    fit: BoxFit.cover,
                                    cacheWidth: 300,
                                    cacheHeight: 300,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            if (widget.isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.20),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(11),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (!widget.isMultiSelectMode && widget.onIconTap != null) {
                                    widget.onIconTap!();
                                  } else {
                                    widget.onSelectedChanged?.call(!widget.isSelected);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(scale: anim, child: child),
                                    child: widget.isSelected
                                        ? Container(
                                            key: const ValueKey('checked_grid_box'),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen,
                                              borderRadius: BorderRadius.circular(5),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            key: const ValueKey('unchecked_grid_box'),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.black.withValues(alpha: 0.45)
                                                  : Colors.black.withValues(alpha: 0.22),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.90),
                                                width: 1.5,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 2,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                                if (!widget.isMultiSelectMode)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 16,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                    onSelected: widget.onActionSelected,
                                    itemBuilder: (_) => _buildMenuItems(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom section: File name, metadata & status badge
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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
                            fontSize: 12,
                            height: 1.25,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${FileIconHelper.formatFileSize(widget.document.fileSize ?? widget.document.size)} • ${formatShortDate(widget.document.createdAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildStatusBadge(widget.document.status, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // LIST ROW — Premium card row with 40x40 badge & combined metadata
  // ════════════════════════════════════════
  Widget _buildListRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseRowColor =
        isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;
    final rowColor = widget.isSelected
        ? Color.alphaBlend(
            AppColors.primaryGreen.withValues(alpha: isDark ? 0.22 : 0.12),
            baseRowColor,
          )
        : null;

    return RepaintBoundary(
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        onLongPressStart: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: Material(
          color: rowColor ?? Colors.transparent,
          child: InkWell(
            onTap: widget.isMultiSelectMode
                ? () => widget.onSelectedChanged?.call(!widget.isSelected)
                : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Premium 40x40 animated selection badge
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!widget.isMultiSelectMode && widget.onIconTap != null) {
                        widget.onIconTap!();
                      } else if (widget.isMultiSelectMode) {
                        widget.onSelectedChanged?.call(!widget.isSelected);
                      } else {
                        widget.onTap();
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: widget.isSelected
                          ? Container(
                              key: const ValueKey('checked_list'),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.check, size: 22, color: Colors.white),
                              ),
                            )
                          : Container(
                              key: const ValueKey('normal_list'),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _fileColor.withValues(
                                  alpha: isDark ? 0.16 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(_fileIcon, size: 22, color: _fileColor),
                                    if (_hasPreview && _effectiveToken != null)
                                      Positioned.fill(
                                        child: Image.network(
                                          '${ApiConstants.baseUrl}/documents/${widget.document.id}/thumbnail?token=$_effectiveToken',
                                          fit: BoxFit.cover,
                                          cacheWidth: 120,
                                          cacheHeight: 120,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // File name & Combined metadata subtitle
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
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${FileIconHelper.formatFileSize(widget.document.fileSize ?? widget.document.size)} • ${formatShortDate(widget.document.createdAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildStatusBadge(widget.document.status, isDark),
                            if (widget.document.documentType != null &&
                                widget.document.documentType!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : Colors.grey.shade300,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  widget.document.documentType!,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ⋮ Actions button
                  if (!widget.isMultiSelectMode)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
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
      ),
    );
  }

  /// Standardized status system badge:
  /// ✓ Complete / Verified, ! Missing, ○ Archived
  Widget _buildStatusBadge(String? status, bool isDark) {
    final norm = (status ?? 'Completed').trim().toLowerCase();

    Color fg;
    Color bg;
    Color border;
    String label;
    IconData icon;

    if (norm == 'completed' || norm == 'complete' || norm == 'verified') {
      fg = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
      bg = isDark ? const Color(0x334CAF50) : const Color(0x182E7D32);
      border = isDark ? const Color(0x4D81C784) : const Color(0x332E7D32);
      label = 'Complete';
      icon = Icons.check_rounded;
    } else if (norm == 'missing') {
      fg = isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
      bg = isDark ? const Color(0x33F44336) : const Color(0x1AC62828);
      border = isDark ? const Color(0x4DEF5350) : const Color(0x33C62828);
      label = 'Missing';
      icon = Icons.priority_high_rounded;
    } else if (norm == 'archived') {
      fg = isDark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);
      bg = isDark ? const Color(0x3378909C) : const Color(0x1A546E7A);
      border = isDark ? const Color(0x4DB0BEC5) : const Color(0x33546E7A);
      label = 'Archived';
      icon = Icons.circle_outlined;
    } else {
      fg = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
      bg = isDark ? const Color(0x334CAF50) : const Color(0x182E7D32);
      border = isDark ? const Color(0x4D81C784) : const Color(0x332E7D32);
      label = 'Complete';
      icon = Icons.check_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 10.5, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

