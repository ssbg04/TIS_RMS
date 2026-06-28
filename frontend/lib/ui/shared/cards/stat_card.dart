import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 220;
        final iconSize = isSmall ? 20.0 : 28.0;
        final titleFontSize = isSmall ? 12.0 : 14.0;
        final valueFontSize = isSmall ? 22.0 : 28.0;
        final padding = isSmall ? 12.0 : 20.0;
        final iconPadding = isSmall ? 8.0 : 12.0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
              onTap: onTap,
              borderRadius: BorderRadius.circular(12.0),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Row(
                  children: [
                    // Icon Container
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  color: (iconColor ?? const Color(0xFF1C8248)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
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
                      maxLines: 1, // Prevent title from wrapping to two lines
                      overflow: TextOverflow.ellipsis, // Add '...' if title is too long
                      style: TextStyle(
                        fontSize: titleFontSize,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // FittedBox shrinks the text dynamically if the number gets too massive
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: isSmall ? 10.0 : 12.0,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
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