import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// A lightweight, static abstract background decorator that adds subtle,
/// non-distracting geometric shapes to make screen backgrounds engaging.
/// Fully responsive across Mobile, Web, and Desktop platforms.
class AbstractBackground extends StatelessWidget {
  final Widget child;

  const AbstractBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Static abstract background shapes layer (Ignored for pointer events)
        const IgnorePointer(
          child: _AbstractShapesCanvas(),
        ),
        // Screen Content Layer
        child,
      ],
    );
  }
}

class _AbstractShapesCanvas extends StatelessWidget {
  const _AbstractShapesCanvas();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (width == 0 || height == 0) return const SizedBox.shrink();

        return Stack(
          children: [
            // Base background tint
            Container(color: AppColors.pageBackground),

            // Shape 1: Top-Right Soft Circle Blob
            Positioned(
              top: -height * 0.08,
              right: -width * 0.05,
              child: Container(
                width: math.max(180, width * 0.35),
                height: math.max(180, width * 0.35),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryGreen.withValues(alpha: 0.07),
                      AppColors.primaryGreen.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Shape 2: Top-Left Tilted Rounded Rect
            Positioned(
              top: height * 0.12,
              left: -width * 0.04,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Container(
                  width: math.max(140, width * 0.22),
                  height: math.max(70, width * 0.11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.darkGreen.withValues(alpha: 0.035),
                  ),
                ),
              ),
            ),

            // Shape 3: Middle-Left Outline Ring
            Positioned(
              top: height * 0.45,
              left: width * 0.03,
              child: Container(
                width: math.max(80, width * 0.12),
                height: math.max(80, width * 0.12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.05),
                    width: 3,
                  ),
                ),
              ),
            ),

            // Shape 4: Bottom-Left Soft Radial Glow Blob
            Positioned(
              bottom: -height * 0.1,
              left: -width * 0.08,
              child: Container(
                width: math.max(220, width * 0.4),
                height: math.max(220, width * 0.4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryGreen.withValues(alpha: 0.06),
                      AppColors.primaryGreen.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Shape 5: Bottom-Right Tilted Pill Capsule
            Positioned(
              bottom: height * 0.15,
              right: -width * 0.03,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: math.max(160, width * 0.25),
                  height: math.max(60, width * 0.09),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: AppColors.primaryGreen.withValues(alpha: 0.04),
                  ),
                ),
              ),
            ),

            // Shape 6: Top-Center Subtle Dot Accent
            Positioned(
              top: height * 0.06,
              left: width * 0.42,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Shape 7: Bottom-Center Small Rotated Square
            Positioned(
              bottom: height * 0.08,
              left: width * 0.5,
              child: Transform.rotate(
                angle: math.pi / 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.darkGreen.withValues(alpha: 0.04),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
