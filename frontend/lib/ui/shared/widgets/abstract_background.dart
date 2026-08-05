import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// A lightweight, static abstract background decorator featuring a smooth, modern gradient background.
/// Fully responsive across Mobile, Web, and Desktop platforms.
class AbstractBackground extends StatelessWidget {
  final Widget child;

  const AbstractBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF10141D),
                  AppColors.darkPageBackground,
                  const Color(0xFF0D0F14),
                  AppColors.darkPageBackground,
                ]
              : [
                  const Color(0xFFEAF3ED),
                  AppColors.pageBackground,
                  const Color(0xFFE4F0E8),
                  AppColors.pageBackground,
                ],
          stops: const [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: child,
    );
  }
}
