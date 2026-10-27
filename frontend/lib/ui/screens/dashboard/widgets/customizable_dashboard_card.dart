import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/dashboard_card_config.dart';

class CustomizableDashboardCard extends StatefulWidget {
  final DashboardCardConfig config;
  final bool isCustomizing;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<int>? onSpanChanged;
  final VoidCallback? onHide;
  final void Function(String draggedId, String targetId)? onReorder;
  final Widget child;

  const CustomizableDashboardCard({
    super.key,
    required this.config,
    required this.isCustomizing,
    this.isFirst = false,
    this.isLast = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onSpanChanged,
    this.onHide,
    this.onReorder,
    required this.child,
  });

  @override
  State<CustomizableDashboardCard> createState() =>
      _CustomizableDashboardCardState();
}

class _CustomizableDashboardCardState extends State<CustomizableDashboardCard> {
  bool _isDragHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isCustomizing) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHalf = widget.config.colSpan == 6;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final willAccept = details.data != widget.config.id;
        if (willAccept != _isDragHovered) {
          setState(() => _isDragHovered = willAccept);
        }
        return willAccept;
      },
      onLeave: (_) {
        if (_isDragHovered) {
          setState(() => _isDragHovered = false);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() => _isDragHovered = false);
        widget.onReorder?.call(details.data, widget.config.id);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDragHovered
                  ? AppColors.primaryGreen
                  : (isDark
                      ? AppColors.primaryGreen.withValues(alpha: 0.5)
                      : AppColors.primaryGreen.withValues(alpha: 0.35)),
              width: _isDragHovered ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isDragHovered
                    ? AppColors.primaryGreen.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: _isDragHovered ? 12 : 6,
                spreadRadius: _isDragHovered ? 2 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Customization Header Toolbar ──────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobileOrAndroid =
                      Theme.of(context).platform == TargetPlatform.android ||
                      constraints.maxWidth < 500;
                  final showWidthToggle = !isMobileOrAndroid &&
                      constraints.maxWidth >= 520;
                  final isCompactWidth = constraints.maxWidth < 640;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface2
                          : AppColors.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.primaryGreen.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Drag Handle & Truncatable Title
                        Expanded(
                          child: Draggable<String>(
                            data: widget.config.id,
                            feedback: _buildDragFeedback(context, isDark),
                            childWhenDragging: Opacity(
                              opacity: 0.25,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.drag_indicator_rounded,
                                    size: 20,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.config.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.drag_indicator_rounded,
                                    size: 20,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.config.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Reorder Arrows (Move Up / Down)
                        Tooltip(
                          message: 'Move card up',
                          child: IconButton(
                            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                            onPressed: widget.isFirst ? null : widget.onMoveUp,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            splashRadius: 16,
                            color: AppColors.primaryGreen,
                            disabledColor: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Tooltip(
                          message: 'Move card down',
                          child: IconButton(
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            onPressed: widget.isLast ? null : widget.onMoveDown,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            splashRadius: 16,
                            color: AppColors.primaryGreen,
                            disabledColor: Colors.grey.shade400,
                          ),
                        ),

                        // Width / Column Span Switcher (Desktop only)
                        if (showWidthToggle) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: isHalf
                                ? 'Click to expand to Full Width (100%)'
                                : 'Click to shrink to Half Width (50%)',
                            child: InkWell(
                              onTap: () {
                                widget.onSpanChanged?.call(isHalf ? 12 : 6);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompactWidth ? 6 : 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isHalf
                                      ? Colors.blueAccent.withValues(alpha: 0.15)
                                      : AppColors.primaryGreen
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isHalf
                                        ? Colors.blueAccent
                                            .withValues(alpha: 0.4)
                                        : AppColors.primaryGreen
                                            .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isHalf
                                          ? Icons.view_column_rounded
                                          : Icons.view_agenda_rounded,
                                      size: 14,
                                      color: isHalf
                                          ? Colors.blueAccent
                                          : AppColors.primaryGreen,
                                    ),
                                    if (!isCompactWidth) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        isHalf ? 'Half (50%)' : 'Full (100%)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isHalf
                                              ? Colors.blueAccent
                                              : AppColors.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),

                        // Hide Card Button
                        Tooltip(
                          message: 'Hide this card',
                          child: IconButton(
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: widget.onHide,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            splashRadius: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── Card Content ──────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragFeedback(BuildContext context, bool isDark) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.config.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.config.colSpan == 6 ? 'Half' : 'Full',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
