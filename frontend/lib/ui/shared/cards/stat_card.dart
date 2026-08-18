import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool isSquare;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 220;
        final iconSize = isSmall ? 22.0 : 26.0;
        final titleFontSize = isSmall ? 11.5 : 13.0;
        final valueFontSize = isSmall ? 22.0 : 26.0;
        final subtitleFontSize = isSmall ? 11.0 : 12.5;
        final padding = isSmall ? 10.0 : 14.0;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: onTap != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onTap: onTap,
              borderRadius: BorderRadius.circular(12.0),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: isSmall ? 8.0 : 10.0,
                ),
                child: isSquare
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  size: iconSize,
                                  color: iconColor ?? const Color(0xFF1C8248),
                                ),
                              ),
                              if (onTap != null)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : Colors.grey.shade400,
                                  size: 16,
                                ),
                            ],
                          ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: valueFontSize,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Icon Container
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              icon,
                              size: iconSize,
                              color: iconColor ?? const Color(0xFF1C8248),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Text Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: valueFontSize,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (onTap != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : Colors.grey.shade400,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
