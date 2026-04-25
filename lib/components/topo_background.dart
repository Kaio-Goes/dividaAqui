import 'package:flutter/material.dart';

class TopoBackground extends StatelessWidget {
  const TopoBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TopoPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TopoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 6; i++) {
      final offset = i * 60.0;
      final path = Path()
        ..moveTo(-60, size.height * 0.15 + offset)
        ..cubicTo(
          size.width * 0.2, size.height * 0.05 + offset,
          size.width * 0.5, size.height * 0.25 + offset,
          size.width * 0.8, size.height * 0.1 + offset,
        )
        ..cubicTo(
          size.width * 1.0, size.height * 0.02 + offset,
          size.width * 1.1, size.height * 0.2 + offset,
          size.width + 60, size.height * 0.15 + offset,
        );
      canvas.drawPath(path, linePaint);
    }

    for (int i = 0; i < 4; i++) {
      final offset = i * 80.0 - 40;
      final path = Path()
        ..moveTo(size.width * 0.1, -40 + offset)
        ..cubicTo(
          size.width * 0.3, size.height * 0.1 + offset,
          size.width * 0.6, -20 + offset,
          size.width * 0.9, size.height * 0.12 + offset,
        );
      canvas.drawPath(path, linePaint);
    }

    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    _drawStar(canvas, starPaint, Offset(size.width * 0.15, size.height * 0.12), 6);
    _drawStar(canvas, starPaint, Offset(size.width * 0.75, size.height * 0.28), 5);
    _drawStar(canvas, starPaint, Offset(size.width * 0.5, size.height * 0.06), 4);
  }

  void _drawStar(Canvas canvas, Paint paint, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r * 3)
      ..lineTo(c.dx + r, c.dy - r)
      ..lineTo(c.dx + r * 3, c.dy)
      ..lineTo(c.dx + r, c.dy + r)
      ..lineTo(c.dx, c.dy + r * 3)
      ..lineTo(c.dx - r, c.dy + r)
      ..lineTo(c.dx - r * 3, c.dy)
      ..lineTo(c.dx - r, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TopoPainter old) => false;
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 40)
      ..quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, 24)
      ..quadraticBezierTo(size.width * 0.75, 48, size.width, 20)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(WaveClipper old) => false;
}
