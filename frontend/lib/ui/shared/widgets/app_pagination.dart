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
    if (totalPages <= 3) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final safeCurrent = currentPage.clamp(1, totalPages);
    final pages = <dynamic>[];
    pages.add(1);

    if (safeCurrent == 1) {
      pages.add('...');
      pages.add(totalPages);
    } else if (safeCurrent == totalPages) {
      pages.add('...');
      pages.add(totalPages);
    } else {
      if (safeCurrent > 2) {
        pages.add('...');
      }
      pages.add(safeCurrent);
      if (safeCurrent < totalPages - 1) {
        pages.add('...');
      }
      pages.add(totalPages);
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = _buildPageList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              iconSize: 20,
              tooltip: 'Previous page',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: isDark ? Colors.white : AppColors.textPrimary,
              disabledColor: isDark ? Colors.white24 : Colors.grey.shade300,
              onPressed: currentPage > 1
                  ? () => onPageChanged(currentPage - 1)
                  : null,
            ),
            const SizedBox(width: 4),
            ...pages.map((p) {
              if (p is int) {
                final isActive = p == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onPageChanged(p),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primaryGreen
                              : (isDark
                                  ? AppColors.darkSurface2
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(6),
                          border: isActive
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : Colors.grey.shade300,
                                ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryGreen
                                        .withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w600,
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
            }),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              iconSize: 20,
              tooltip: 'Next page',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: isDark ? Colors.white : AppColors.textPrimary,
              disabledColor: isDark ? Colors.white24 : Colors.grey.shade300,
              onPressed: currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
