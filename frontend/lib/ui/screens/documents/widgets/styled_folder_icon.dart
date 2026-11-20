import 'package:flutter/material.dart';

/// Ultra-modern, dimensional folder icon designed for contemporary mobile & desktop interfaces.
///
/// Features:
/// - Organic curved tab geometry with interior pocket depth.
/// - Staggered dual document sheets peeking from the pocket for rich tangible realism.
/// - Front flap with smooth squircle contours, frosted glass top-rim highlight, and ambient drop shadow.
/// - Documents screen: Sleek frosted-glass capsule pills for JHS & SHS completion status.
/// - Archives screen: Minimalist archival vault seal emblem.
class StyledFolderIcon extends StatelessWidget {
  final int jhsCompleted;
  final int jhsTotal;
  final int shsCompleted;
  final int shsTotal;
  final bool isMobile;
  final bool isArchived;

  const StyledFolderIcon({
    super.key,
    required this.jhsCompleted,
    required this.jhsTotal,
    required this.shsCompleted,
    required this.shsTotal,
    this.isMobile = false,
    this.isArchived = false,
  });

  @override
  Widget build(BuildContext context) {
    // Proportions calibrated for touch targets and crisp vector scaling
    final width = isMobile ? 92.0 : 104.0;
    final height = isMobile ? 66.0 : 74.0;
    final frontHeight = isMobile ? 50.0 : 56.0;

    // Palette: Vibrant Modern Amber (Documents) vs Rich Archival Bronze/Terracotta (Archives)
    final backColorTop = isArchived ? const Color(0xFFC2410C) : const Color(0xFFD97706);
    final backColorBottom = isArchived ? const Color(0xFF7C2D12) : const Color(0xFF92400E);
    final pocketInteriorColor = isArchived ? const Color(0xFF431407) : const Color(0xFF78350F);

    final frontGradient = isArchived
        ? const [
            Color(0xFFFB923C), // Luminous rust top highlight
            Color(0xFFEA580C), // Warm terracotta center
            Color(0xFF9A3412), // Deep archival bronze base
          ]
        : const [
            Color(0xFFFDE047), // Sunlit golden-yellow top rim
            Color(0xFFF59E0B), // Radiant warm amber center
            Color(0xFFD97706), // Rich deep amber base
          ];

    final shadowColor = (isArchived
            ? const Color(0xFF431407)
            : const Color(0xFF78350F))
        .withValues(alpha: 0.38);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── 1. Back Plate with Smooth Organic Tab ───────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _ModernFolderBackPainter(
                colorTop: backColorTop,
                colorBottom: backColorBottom,
                tabWidthRatio: 0.44,
              ),
            ),
          ),

          // ── 2. Dark Interior Pocket Shadow (Creates authentic hollow depth) ─
          Positioned(
            top: isMobile ? 12.0 : 14.0,
            left: 5,
            right: 5,
            height: isMobile ? 16.0 : 18.0,
            child: Container(
              decoration: BoxDecoration(
                color: pocketInteriorColor.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),

          // ── 3. Staggered Document Papers Peeking Out ────────────────────────
          // Back Document Sheet (Slightly tilted)
          Positioned(
            top: isMobile ? 7.0 : 8.0,
            left: width * 0.17,
            right: width * 0.13,
            height: isMobile ? 28.0 : 32.0,
            child: Transform.rotate(
              angle: 0.03, // ~1.7 degree tilt
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Front Document Sheet (Crisp White with Document Rule Lines)
          Positioned(
            top: isMobile ? 8.0 : 9.5,
            left: width * 0.14,
            right: width * 0.16,
            height: isMobile ? 30.0 : 34.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(top: 5, left: 7, right: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 2.2,
                    width: width * 0.38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(height: 3.5),
                  Container(
                    height: 2.0,
                    width: width * 0.24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 4. Front Cover Flap with Curvature & Specular Highlight ────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: frontHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: frontGradient,
                  stops: const [0.0, 0.40, 1.0],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Subtle frosted glass top-edge sheen
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Content
                  Center(
                    child: isArchived
                        // Archives: Minimalist Vault Emblem
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.30),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              Icons.inventory_2_rounded,
                              size: isMobile ? 18 : 21,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          )
                        // Documents: Sleek Modern Capsule Progress Pills
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCapsulePill('JHS', jhsCompleted, jhsTotal, isJhs: true),
                                  const SizedBox(width: 5),
                                  _buildCapsulePill('SHS', shsCompleted, shsTotal, isJhs: false),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsulePill(String label, int done, int total, {required bool isJhs}) {
    final isComplete = total > 0 && done >= total;

    // Palette: Emerald when done; Deep Cognac/Amber for JHS; Deep Royal Navy for SHS
    final bgGradient = isComplete
        ? const [Color(0xFF059669), Color(0xFF047857)]
        : (isJhs
            ? const [Color(0xFF9A3412), Color(0xFF7C2D12)]
            : const [Color(0xFF1E40AF), Color(0xFF1E3A8A)]);

    final dotColor = isComplete
        ? const Color(0xFF34D399) // Light emerald glow
        : (isJhs
            ? const Color(0xFFFB923C) // Orange dot
            : const Color(0xFF60A5FA)); // Blue dot

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bgGradient,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1.2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isComplete)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(Icons.check_rounded, size: 10.5, color: Colors.white),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 4.5,
                height: 4.5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.6),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          Text(
            '$label $done/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the back plate of the folder, rendering continuous bezier curves
class _ModernFolderBackPainter extends CustomPainter {
  final Color colorTop;
  final Color colorBottom;
  final double tabWidthRatio;

  _ModernFolderBackPainter({
    required this.colorTop,
    required this.colorBottom,
    required this.tabWidthRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tabW = w * tabWidthRatio;
    const tabH = 13.0;
    const r = 9.0;

    final path = Path();
    // Start at bottom-left corner
    path.moveTo(0, h - r);
    path.quadraticBezierTo(0, h, r, h);
    // Bottom edge to bottom-right
    path.lineTo(w - r, h);
    path.quadraticBezierTo(w, h, w, h - r);
    // Right side up to shoulder
    path.lineTo(w, tabH + 2);
    path.quadraticBezierTo(w, tabH - 2, w - r, tabH - 2);
    // Shoulder to tab curve
    path.lineTo(tabW + 7, tabH - 2);
    path.quadraticBezierTo(tabW + 1, tabH - 2, tabW - 3, tabH - 6);
    path.lineTo(tabW - 6, 3);
    path.quadraticBezierTo(tabW - 8, 0, tabW - 14, 0);
    // Tab top to top-left corner
    path.lineTo(r, 0);
    path.quadraticBezierTo(0, 0, 0, r);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colorTop, colorBottom],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ModernFolderBackPainter oldDelegate) {
    return oldDelegate.colorTop != colorTop ||
        oldDelegate.colorBottom != colorBottom ||
        oldDelegate.tabWidthRatio != tabWidthRatio;
  }
}
