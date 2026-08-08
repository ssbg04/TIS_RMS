import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/theme_extension.dart';

class DocumentsHeader extends StatelessWidget {
  final String? openedFolderName;
  final int tabIndex;
  final bool isStudentFiltered;
  final bool isMobile;
  final VoidCallback onBackToFolders;
  final VoidCallback onClearStudentFilter;
  final VoidCallback onOpenSearch;
  final VoidCallback onClearSearch;
  final bool hasActiveSearch;

  const DocumentsHeader({
    super.key,
    required this.openedFolderName,
    required this.tabIndex,
    required this.isStudentFiltered,
    required this.isMobile,
    required this.onBackToFolders,
    required this.onClearStudentFilter,
    required this.onOpenSearch,
    required this.onClearSearch,
    required this.hasActiveSearch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isFolderOpened = openedFolderName != null;

    return Row(
      children: [
        Expanded(
          child: isFolderOpened
              ? Row(
                  children: [
                    InkWell(
                      onTap: onBackToFolders,
                      child: Text(
                        'Student Folders',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      ' / ',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        openedFolderName!,
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 21,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  tabIndex == 0
                      ? 'Student Folders'
                      : tabIndex == 1
                          ? (isStudentFiltered ? 'Student Documents' : 'All Documents')
                          : 'Recycle Bin',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 21,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
        ),
        if (isStudentFiltered && !isFolderOpened) ...[
          const SizedBox(width: 12),
          Flexible(
            child: TextButton.icon(
              onPressed: onClearStudentFilter,
              icon: const Icon(Icons.close, size: 14),
              label: const Text('All Students', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        if (!isFolderOpened) ...[
          IconButton(
            icon: Icon(
              hasActiveSearch ? Icons.close : Icons.search,
              size: 28,
              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
            ),
            tooltip: hasActiveSearch ? 'Clear Search' : 'Search Documents',
            onPressed: hasActiveSearch ? onClearSearch : onOpenSearch,
          ),
        ],
      ],
    );
  }
}
