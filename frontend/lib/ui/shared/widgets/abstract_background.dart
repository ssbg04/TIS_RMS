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

  const AbstractBackground({
    super.key,
    required this.child,
    this.withOverlay = false,
    this.overlayOpacity = 0.0,
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
    final isLandscape = mediaQuery.orientation == Orientation.landscape ||
        mediaQuery.size.width >= mediaQuery.size.height;

    final assetPath = getBackdropAsset(
      isDark: isDark,
      isLandscape: isLandscape,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image matching orientation and theme
        Positioned.fill(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
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
