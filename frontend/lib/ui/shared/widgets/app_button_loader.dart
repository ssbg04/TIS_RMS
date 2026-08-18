import 'package:flutter/material.dart';

/// Standardized, non-stretching circular loading indicator for buttons and dialog actions.
/// Guarantees a true 1:1 circular aspect ratio with zero padding/flex deformation.
class AppButtonLoader extends StatelessWidget {
  final Color? color;
  final double size;
  final double strokeWidth;

  const AppButtonLoader({
    super.key,
    this.color,
    this.size = 18.0,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.white);

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
          ),
        ),
      ),
    );
  }
}
