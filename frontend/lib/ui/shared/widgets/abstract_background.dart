import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// A lightweight, static abstract background decorator featuring exactly 3 large, solid shapes (no outlines).
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

            // Shape 1 (Top-Right): Large Solid Circle
            Positioned(
              top: -height * 0.12,
              right: -width * 0.10,
              child: Container(
                width: math.max(320, width * 0.55),
                height: math.max(320, width * 0.55),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen.withValues(alpha: 0.075),
                ),
              ),
            ),

            // Shape 2 (Top-Left): Large Solid Tilted Rect Block
            Positioned(
              top: height * 0.08,
              left: -width * 0.12,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Container(
                  width: math.max(260, width * 0.45),
                  height: math.max(140, width * 0.22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(48),
                    color: AppColors.darkGreen.withValues(alpha: 0.055),
                  ),
                ),
              ),
            ),

            // Shape 3 (Bottom-Right): Large Solid Tilted Pill Capsule
            Positioned(
              bottom: height * 0.05,
              right: -width * 0.06,
              child: Transform.rotate(
                angle: math.pi / 5,
                child: Container(
                  width: math.max(280, width * 0.50),
                  height: math.max(120, width * 0.22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                    color: AppColors.primaryGreen.withValues(alpha: 0.065),
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
