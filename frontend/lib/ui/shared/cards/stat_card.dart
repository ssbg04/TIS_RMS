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
        final iconSize = isSmall ? 24.0 : 28.0;
        final titleFontSize = isSmall ? 11.0 : 13.0;
        final valueFontSize = isSmall ? 20.0 : 24.0;
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
                padding: EdgeInsets.all(padding),
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
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                                  size: 16,
                                ),
                            ],
                          ),
                          Column(
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
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    fontSize: isSmall ? 9.0 : 11.0,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
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
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
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
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: TextStyle(
                                      fontSize: isSmall ? 9.0 : 11.0,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                                      fontWeight: FontWeight.w500,
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
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
