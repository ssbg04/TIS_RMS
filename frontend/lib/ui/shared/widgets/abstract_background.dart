import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// An adaptive backdrop widget that displays the appropriate high-resolution
/// cropped backdrop based on the current theme (Light / Dark) and orientation (Landscape / Portrait).
///
/// Source: `assets/images/backdrop.png` cropped into:
/// - Light Landscape: `assets/images/backdrop_light_landscape.png`
/// - Light Portrait:  `assets/images/backdrop_light_portrait.png`
/// - Dark Landscape:  `assets/images/backdrop_dark_landscape.png`
/// - Dark Portrait:   `assets/images/backdrop_dark_portrait.png`
class AbstractBackground extends StatelessWidget {
  final Widget child;
  final bool withOverlay;
  final double overlayOpacity;
  final double blurSigma;

  const AbstractBackground({
    super.key,
    required this.child,
    this.withOverlay = false,
    this.overlayOpacity = 0.0,
    this.blurSigma = 2.5,
  });

  /// Helper to get the correct asset path based on brightness and orientation
  static String getBackdropAsset({
    required bool isDark,
    required bool isLandscape,
  }) {
    if (isDark) {
      return isLandscape
          ? 'assets/images/backdrop_dark_landscape.png'
          : 'assets/images/backdrop_dark_portrait.png';
    } else {
      return isLandscape
          ? 'assets/images/backdrop_light_landscape.png'
          : 'assets/images/backdrop_light_portrait.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    final assetPath = getBackdropAsset(
      isDark: isDark,
      isLandscape: isLandscape,
    );

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
        if (withOverlay && overlayOpacity > 0)
          Positioned.fill(
            child: Container(
              color: (isDark ? Colors.black : Colors.white)
                  .withValues(alpha: overlayOpacity),
            ),
          ),
        child,
      ],
    );
  }
}
