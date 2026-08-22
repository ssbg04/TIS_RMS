import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class FabActionItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final int badgeCount;
  final String? heroTag;
  final String? label;

  const FabActionItem({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.badgeCount = 0,
    this.heroTag,
    this.label,
  });
}

/// An animated floating action button speed-dial menu that expands smoothly
/// vertically upwards on mobile devices.
class HorizontalExpandableFab extends StatefulWidget {
  final List<FabActionItem> items;
  final String heroTag;

  const HorizontalExpandableFab({
    super.key,
    required this.items,
    this.heroTag = 'expandable_fab',
  });

  @override
  State<HorizontalExpandableFab> createState() => _HorizontalExpandableFabState();
}

class _HorizontalExpandableFabState extends State<HorizontalExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didUpdateWidget(HorizontalExpandableFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length <= 1 && _isOpen) {
      _controller.reverse();
      _isOpen = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    // If only 1 item, render directly as a single FloatingActionButton
    if (widget.items.length == 1) {
      final item = widget.items.first;
      Widget fab = FloatingActionButton(
        heroTag: item.heroTag ?? '${widget.heroTag}_single',
        backgroundColor: item.backgroundColor ?? AppColors.primaryGreen,
        foregroundColor: item.foregroundColor ?? Colors.white,
        shape: const CircleBorder(),
        tooltip: item.tooltip,
        onPressed: item.onPressed,
        child: Icon(item.icon),
      );

      if (item.badgeCount > 0) {
        fab = Badge(
          label: Text('${item.badgeCount}'),
          backgroundColor: AppColors.error,
          offset: const Offset(4, -4),
          child: fab,
        );
      }
      return fab;
    }

    final totalBadgeCount = widget.items.fold<int>(
      0,
      (sum, item) => sum + item.badgeCount,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Vertically expanding action items (expanding upwards)
        SizeTransition(
          sizeFactor: _expandAnimation,
          axis: Axis.vertical,
          alignment: Alignment.bottomRight,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < widget.items.length; i++) ...[
                  _buildSubItem(widget.items[i], i),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),

        // Main Menu Toggle Button (anchored at bottom right)
        _buildMainToggle(totalBadgeCount),
      ],
    );
  }

  Widget _buildMainToggle(int totalBadgeCount) {
    Widget toggleFab = FloatingActionButton(
      heroTag: widget.heroTag,
      backgroundColor: _isOpen ? Colors.grey.shade800 : AppColors.primaryGreen,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      tooltip: _isOpen ? 'Close Menu' : 'Actions Menu',
      onPressed: _toggle,
      child: RotationTransition(
        turns: _rotateAnimation,
        child: Icon(_isOpen ? Icons.close : Icons.add, size: 28),
      ),
    );

    if (!_isOpen && totalBadgeCount > 0) {
      toggleFab = Badge(
        label: Text('$totalBadgeCount'),
        backgroundColor: AppColors.error,
        offset: const Offset(4, -4),
        child: toggleFab,
      );
    }

    return toggleFab;
  }

  Widget _buildSubItem(FabActionItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelText = item.label ?? item.tooltip;

    Widget button = FloatingActionButton.small(
      heroTag: item.heroTag ?? '${widget.heroTag}_item_$index',
      backgroundColor: item.backgroundColor ?? AppColors.primaryGreen,
      foregroundColor: item.foregroundColor ?? Colors.white,
      shape: const CircleBorder(),
      tooltip: item.tooltip,
      onPressed: () {
        _close();
        item.onPressed();
      },
      child: Icon(item.icon, size: 20),
    );

    if (item.badgeCount > 0) {
      button = Badge(
        label: Text('${item.badgeCount}'),
        backgroundColor: AppColors.error,
        offset: const Offset(4, -4),
        child: button,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (labelText.isNotEmpty) ...[
          GestureDetector(
            onTap: () {
              _close();
              item.onPressed();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          width: 56,
          alignment: Alignment.center,
          child: button,
        ),
      ],
    );
  }
}
