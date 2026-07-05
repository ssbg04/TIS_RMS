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

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),
          ...List.generate(
            totalPages,
            (i) => i + 1,
          ).where((p) => (p - currentPage).abs() <= 2).map((p) {
            final isActive = p == currentPage;
            return GestureDetector(
              onTap: () => onPageChanged(p),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? null
                      : Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
