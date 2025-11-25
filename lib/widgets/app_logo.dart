import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color accentColor;

  const AppLogo({
    super.key,
    this.size = 100,
    this.primaryColor = Colors.black,
    this.accentColor = const Color(0xFF4CAF50),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: LogoPainter(
        primaryColor: primaryColor,
        accentColor: accentColor,
      ),
    );
  }
}

class LogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  LogoPainter({required this.primaryColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circular background
    final bgPaint =
        Paint()
          ..color = primaryColor.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw notepad outline
    final notepadRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.6,
        height: size.height * 0.7,
      ),
      const Radius.circular(8),
    );

    // Notepad background
    final notepadPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawRRect(notepadRect, notepadPaint);

    // Notepad border
    final borderPaint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    canvas.drawRRect(notepadRect, borderPaint);

    // Draw lines on notepad
    final linesPaint =
        Paint()
          ..color = primaryColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final startX = notepadRect.left + 10;
    final endX = notepadRect.right - 10;
    final startY = notepadRect.top + 20;
    final lineSpacing = 12.0;

    for (int i = 0; i < 4; i++) {
      final y = startY + (i * lineSpacing);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), linesPaint);
    }

    // Draw checkmark (accent)
    final checkPath = Path();
    final checkStartX = notepadRect.left + 15;
    final checkStartY = notepadRect.bottom - 25;

    checkPath.moveTo(checkStartX, checkStartY);
    checkPath.lineTo(checkStartX + 8, checkStartY + 8);
    checkPath.lineTo(checkStartX + 20, checkStartY - 10);

    final checkPaint =
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(checkPath, checkPaint);

    // Draw pen icon
    final penPath = Path();
    final penX = notepadRect.right - 20;
    final penY = notepadRect.top + 15;

    // Pen body
    penPath.moveTo(penX, penY);
    penPath.lineTo(penX - 3, penY + 15);
    penPath.lineTo(penX + 3, penY + 15);
    penPath.close();

    // Pen tip
    penPath.moveTo(penX - 3, penY + 15);
    penPath.lineTo(penX, penY + 20);
    penPath.lineTo(penX + 3, penY + 15);

    final penPaint =
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;

    canvas.drawPath(penPath, penPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
