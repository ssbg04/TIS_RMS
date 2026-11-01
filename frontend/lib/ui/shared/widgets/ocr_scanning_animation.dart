import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// A zero-KB native 60fps OCR scanning animation combining:
/// 1. A custom-painted Laser Document Scanner with glowing scan beam & viewfinder brackets.
/// 2. A live step-by-step OCR pipeline ticker showing active extraction stages.
class OcrScanningAnimation extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? fileName;
  final bool compact;
  final List<String>? customSteps;

  const OcrScanningAnimation({
    super.key,
    this.title = 'Scanning Document with OCR',
    this.subtitle,
    this.fileName,
    this.compact = false,
    this.customSteps,
  });

  @override
  State<OcrScanningAnimation> createState() => _OcrScanningAnimationState();
}

class _OcrScanningAnimationState extends State<OcrScanningAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  Timer? _stepTimer;
  int _activeStep = 0;

  static const List<String> _defaultSteps = [
    'Enhancing document contrast & alignment...',
    'Running optical character recognition...',
    'Detecting 12-digit LRN & student identity...',
    'Extracting grade level, section & school year...',
  ];

  List<String> get _steps => widget.customSteps ?? _defaultSteps;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _stepTimer = Timer.periodic(const Duration(milliseconds: 1350), (_) {
      if (!mounted) return;
      setState(() {
        if (_activeStep < _steps.length - 1) {
          _activeStep++;
        } else {
          // Pulse between the last two stages while waiting for server response
          _activeStep = _steps.length - 2;
        }
      });
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scannerSize = widget.compact ? 92.0 : 124.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 16 : 24,
        vertical: widget.compact ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface2.withValues(alpha: 0.65)
            : AppColors.primaryGreen.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Animated Laser Document Scanner Graphic
          SizedBox(
            width: scannerSize,
            height: scannerSize,
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _OcrLaserScannerPainter(
                    progress: _scanController.value,
                    isDark: isDark,
                    primaryColor: AppColors.primaryGreen,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: widget.compact ? 12 : 18),

          // 2. Title & Optional Subtitle
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.compact ? 15 : 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],

          // 3. Optional Active Filename Pill
          if (widget.fileName != null && widget.fileName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: widget.compact ? 12 : 18),

          // 4. Live Step-by-Step Pipeline Ticker
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceCard.withValues(alpha: 0.85)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(_steps.length, (index) {
                  final isDone = index < _activeStep;
                  final isCurrent = index == _activeStep;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _steps.length - 1 ? 0 : 7,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Center(
                            child: isDone
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppColors.primaryGreen,
                                  )
                                : isCurrent
                                    ? const SizedBox(
                                        width: 13,
                                        height: 13,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryGreen,
                                        ),
                                      )
                                    : Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : isDone
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                              color: isCurrent
                                  ? (isDark ? Colors.white : AppColors.primaryGreen)
                                  : isDone
                                      ? (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary)
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.grey.shade400),
                            ),
                            child: Text(_steps[index]),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrLaserScannerPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color primaryColor;

  _OcrLaserScannerPainter({
    required this.progress,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft circular background aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: isDark ? 0.22 : 0.14),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * 0.52));
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.52, auraPaint);

    // Document card bounds
    final docWidth = w * 0.58;
    final docHeight = h * 0.72;
    final docLeft = (w - docWidth) / 2;
    final docTop = (h - docHeight) / 2;
    final docRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(docLeft, docTop, docWidth, docHeight),
      const Radius.circular(8),
    );

    // Document shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.35 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(docRect.shift(const Offset(0, 3)), shadowPaint);

    // Document body
    final docBgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E2923) : Colors.white;
    canvas.drawRRect(docRect, docBgPaint);

    final docBorderPaint = Paint()
      ..color = primaryColor.withValues(alpha: isDark ? 0.45 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(docRect, docBorderPaint);

    // Simulated document lines (SF10 header, LRN box, student rows)
    final scanY = docTop + 8 + (docHeight - 16) * progress;

    final linePositions = <double>[
      0.16, // Header bar
      0.30, // LRN row
      0.44, // Name row
      0.56, // Grade & Section row
      0.68, // School year row
      0.80, // Table line
    ];
    final lineWidths = <double>[0.55, 0.78, 0.72, 0.64, 0.80, 0.50];

    for (int i = 0; i < linePositions.length; i++) {
      final ly = docTop + docHeight * linePositions[i];
      final lw = (docWidth - 20) * lineWidths[i];
      final lx = docLeft + 10;

      // Distance from laser beam determines highlight intensity
      final dist = (ly - scanY).abs();
      final highlight = (1.0 - (dist / (docHeight * 0.22))).clamp(0.0, 1.0);

      final baseColor = isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.grey.shade300;
      final activeColor = primaryColor.withValues(alpha: 0.85);

      final linePaint = Paint()
        ..color = Color.lerp(baseColor, activeColor, highlight)!
        ..strokeCap = StrokeCap.round
        ..strokeWidth = i == 0 ? 5.0 : 3.5;

      canvas.drawLine(Offset(lx, ly), Offset(lx + lw, ly), linePaint);
    }

    // Laser trail glow clipped to document
    canvas.save();
    canvas.clipRRect(docRect);

    final trailHeight = docHeight * 0.24;
    final trailRect = Rect.fromLTWH(
      docLeft,
      scanY - trailHeight / 2,
      docWidth,
      trailHeight,
    );
    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: isDark ? 0.32 : 0.22),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(trailRect);
    canvas.drawRect(trailRect, trailPaint);
    canvas.restore();

    // Glowing Laser Beam Line (extends slightly outside document)
    final beamLeft = docLeft - 6;
    final beamRight = docLeft + docWidth + 6;

    final beamGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.55)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(beamLeft, scanY), Offset(beamRight, scanY), beamGlowPaint);

    final beamCorePaint = Paint()
      ..color = isDark ? const Color(0xFF69F0AE) : primaryColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(beamLeft, scanY), Offset(beamRight, scanY), beamCorePaint);

    // Viewfinder Corner Brackets (pulsing slightly)
    final pulse = math.sin(progress * math.pi) * 2.0;
    final pad = 6.0 - pulse * 0.5;
    final bLeft = docLeft - pad;
    final bRight = docLeft + docWidth + pad;
    final bTop = docTop - pad;
    final bBottom = docTop + docHeight + pad;
    const cornerLen = 10.0;

    final bracketPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Top-left bracket
    canvas.drawPath(
      Path()
        ..moveTo(bLeft, bTop + cornerLen)
        ..lineTo(bLeft, bTop)
        ..lineTo(bLeft + cornerLen, bTop),
      bracketPaint,
    );
    // Top-right bracket
    canvas.drawPath(
      Path()
        ..moveTo(bRight - cornerLen, bTop)
        ..lineTo(bRight, bTop)
        ..lineTo(bRight, bTop + cornerLen),
      bracketPaint,
    );
    // Bottom-left bracket
    canvas.drawPath(
      Path()
        ..moveTo(bLeft, bBottom - cornerLen)
        ..lineTo(bLeft, bBottom)
        ..lineTo(bLeft + cornerLen, bBottom),
      bracketPaint,
    );
    // Bottom-right bracket
    canvas.drawPath(
      Path()
        ..moveTo(bRight - cornerLen, bBottom)
        ..lineTo(bRight, bBottom)
        ..lineTo(bRight, bBottom - cornerLen),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OcrLaserScannerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

