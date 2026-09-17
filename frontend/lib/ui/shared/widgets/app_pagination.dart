import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AppPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  List<dynamic> _buildPageList() {
    if (totalPages <= 1) return [];
    if (totalPages <= 7) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final safeCurrent = currentPage.clamp(1, totalPages);
    final pages = <dynamic>[];

    pages.add(1);

    if (safeCurrent <= 3) {
      pages.addAll([2, 3, 4, '...', totalPages]);
    } else if (safeCurrent >= totalPages - 2) {
      pages.addAll([
        '...',
        totalPages - 3,
        totalPages - 2,
        totalPages - 1,
        totalPages,
      ]);
    } else {
      pages.addAll([
        '...',
        safeCurrent - 1,
        safeCurrent,
        safeCurrent + 1,
        '...',
        totalPages,
      ]);
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 640;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      alignment: Alignment.center,
      child: isDesktop
          ? _buildDesktopOption02(context, isDark)
          : _buildMobileOption01(context, isDark),
    );
  }

  // ── DESKTOP: OPTION 02 ──────────────────────────────────────────
  Widget _buildDesktopOption02(BuildContext context, bool isDark) {
    final pages = _buildPageList();
    final canPrev = currentPage > 1;
    final canNext = currentPage < totalPages;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "Previous" text button
        InkWell(
          onTap: canPrev ? () => onPageChanged(currentPage - 1) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              'Previous',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: canPrev
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    : (isDark ? Colors.white24 : Colors.grey.shade400),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Page number pills
        ...pages.map((p) => _buildPageItem(p, isDark)),

        const SizedBox(width: 8),

        // "Next" text button
        InkWell(
          onTap: canNext ? () => onPageChanged(currentPage + 1) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              'Next',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: canNext
                    ? AppColors.primaryGreen
                    : (isDark ? Colors.white24 : Colors.grey.shade400),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Page Dropdown Selector: "Page [ 1 ▾ ]"
        _buildPageDropdown(context, isDark),
      ],
    );
  }

  // ── MOBILE: OPTION 01 (COMPACT) ──────────────────────────────────
  Widget _buildMobileOption01(BuildContext context, bool isDark) {
    final canPrev = currentPage > 1;
    final canNext = currentPage < totalPages;

    // Compact list of pages (show 3 max around current)
    final safeCurrent = currentPage.clamp(1, totalPages);
    final compactPages = <dynamic>[];
    if (totalPages <= 4) {
      compactPages.addAll(List.generate(totalPages, (i) => i + 1));
    } else {
      if (safeCurrent > 1) compactPages.add(safeCurrent - 1);
      compactPages.add(safeCurrent);
      if (safeCurrent < totalPages) compactPages.add(safeCurrent + 1);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // « (First)
          _buildNavIconButton(
            icon: Icons.keyboard_double_arrow_left_rounded,
            enabled: canPrev,
            isDark: isDark,
            tooltip: 'First Page',
            onTap: () => onPageChanged(1),
          ),
          const SizedBox(width: 4),

          // ‹ (Prev)
          _buildNavIconButton(
            icon: Icons.chevron_left_rounded,
            enabled: canPrev,
            isDark: isDark,
            tooltip: 'Previous Page',
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 4),

          // Numbers
          ...compactPages.map((p) => _buildPageItem(p, isDark, compact: true)),

          const SizedBox(width: 4),

          // › (Next)
          _buildNavIconButton(
            icon: Icons.chevron_right_rounded,
            enabled: canNext,
            isDark: isDark,
            tooltip: 'Next Page',
            onTap: () => onPageChanged(currentPage + 1),
          ),
          const SizedBox(width: 4),

          // » (Last)
          _buildNavIconButton(
            icon: Icons.keyboard_double_arrow_right_rounded,
            enabled: canNext,
            isDark: isDark,
            tooltip: 'Last Page',
            onTap: () => onPageChanged(totalPages),
          ),

          const SizedBox(width: 10),

          // Compact Page [ X ▾ ]
          _buildPageDropdown(context, isDark, compact: true),
        ],
      ),
    );
  }

  Widget _buildNavIconButton({
    required IconData icon,
    required bool enabled,
    required bool isDark,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                : (isDark ? Colors.white24 : Colors.grey.shade400),
          ),
        ),
      ),
    );
  }

  Widget _buildPageItem(dynamic p, bool isDark, {bool compact = false}) {
    if (p is int) {
      final isActive = p == currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onPageChanged(p),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: compact ? 32 : 36,
              height: compact ? 32 : 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryGreen
                    : (isDark ? AppColors.darkSurfaceCard : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? AppColors.primaryGreen
                      : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$p',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      );
    }
  }

  Widget _buildPageDropdown(BuildContext context, bool isDark, {bool compact = false}) {
    return PopupMenuButton<int>(
      tooltip: 'Select Page',
      initialValue: currentPage,
      onSelected: (page) {
        if (page != currentPage) {
          onPageChanged(page);
        }
      },
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 280),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
      itemBuilder: (ctx) {
        return List.generate(totalPages, (i) {
          final pageNum = i + 1;
          final isSelected = pageNum == currentPage;
          return PopupMenuItem<int>(
            value: pageNum,
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page $pageNum',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
              ],
            ),
          );
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Text(
                'Page',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '$currentPage',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }
}
