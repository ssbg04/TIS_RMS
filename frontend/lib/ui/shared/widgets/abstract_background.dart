import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/theme_provider.dart';

/// An adaptive backdrop widget that displays the appropriate high-resolution
/// cropped backdrop based on the current theme (Light / Dark) and orientation (Landscape / Portrait).
///
/// Source: `assets/images/backdrop.png` cropped into:
/// - Light Landscape: `assets/images/backdrop_light_landscape.webp`
/// - Light Portrait:  `assets/images/backdrop_light_portrait.webp`
/// - Dark Landscape:  `assets/images/backdrop_dark_landscape.webp`
/// - Dark Portrait:   `assets/images/backdrop_dark_portrait.webp`
class AbstractBackground extends ConsumerWidget {
  final Widget child;
  final bool withOverlay;
  final double? overlayOpacity;
  final double blurSigma;

  const AbstractBackground({
    super.key,
    required this.child,
    this.withOverlay = true,
    this.overlayOpacity,
    this.blurSigma = 4.0,
  });

  /// Helper to get the correct asset path based on brightness and orientation
  static String getBackdropAsset({
    required bool isDark,
    required bool isLandscape,
  }) {
    if (isDark) {
      return isLandscape
          ? 'assets/images/backdrop_dark_landscape.webp'
          : 'assets/images/backdrop_dark_portrait.webp';
    } else {
      return isLandscape
          ? 'assets/images/backdrop_light_landscape.webp'
          : 'assets/images/backdrop_light_portrait.webp';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = ref.watch(highContrastProvider);
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    final assetPath = getBackdropAsset(
      isDark: isDark,
      isLandscape: isLandscape,
    );

    final defaultOpacity = highContrast
        ? (isDark ? 0.88 : 0.90)
        : (isDark ? 0.42 : 0.58);
    final rawOpacity = overlayOpacity ?? defaultOpacity;
    final effectiveOpacity = highContrast
        ? rawOpacity.clamp(0.85, 1.0)
        : rawOpacity;
    final scrimColor =
        isDark ? AppColors.darkPageBackground : AppColors.pageBackground;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image with edge-to-edge coverage and overlay mini blur
        Positioned.fill(
          child: ClipRect(
            child: Transform.scale(
              scale: blurSigma > 0 ? 1.06 : 1.0,
              child: blurSigma > 0
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: blurSigma,
                        sigmaY: blurSigma,
                        tileMode: TileMode.clamp,
                      ),
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    )
                  : Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
            ),
          ),
        ),
        if (withOverlay && effectiveOpacity > 0)
          Positioned.fill(
            child: Container(
              color: scrimColor.withValues(alpha: effectiveOpacity),
            ),
          ),
        child,
      ],
    );
  }
}
