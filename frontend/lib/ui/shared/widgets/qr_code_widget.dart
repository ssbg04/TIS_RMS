import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Renders a crisp vector QR code card with white quiet-zone padding so
/// authenticator apps can scan it reliably in both light and dark modes.
class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _QrPainter(qrImage),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrImage qrImage;

  _QrPainter(this.qrImage);

  @override
  void paint(Canvas canvas, Size size) {
    final count = qrImage.moduleCount;
    if (count <= 0) return;

    final cellSize = size.width / count;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (int row = 0; row < count; row++) {
      for (int col = 0; col < count; col++) {
        if (qrImage.isDark(row, col)) {
          // Slight 0.2px overlap prevents hairline anti-aliasing seams on scaled canvases
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize,
              row * cellSize,
              cellSize + 0.2,
              cellSize + 0.2,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) {
    return oldDelegate.qrImage != qrImage;
  }
}
