import 'package:flutter/material.dart';

/// A lightweight vector rendering of Orah's mint-to-blue spiral mark.
class OrahLogo extends StatelessWidget {
  const OrahLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _OrahLogoPainter()),
      );
}

class _OrahLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide * 0.43;
    final background = Paint()..color = Colors.white;
    canvas.drawRect(rect, background);

    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9FE4C0), Color(0xFFB7E8E1), Color(0xFF82C6E8)],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = gradient);

    // Offset inner cutouts create the soft spiral/negative-space center.
    canvas.drawCircle(
      center.translate(-size.width * 0.07, -size.height * 0.055),
      radius * 0.63,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center.translate(size.width * 0.12, size.height * 0.075),
      radius * 0.34,
      Paint()..color = Colors.white,
    );
    final innerGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC9F1DF), Color(0xFFB5E7E4), Color(0xFF91D0E8)],
    ).createShader(Rect.fromCircle(
      center: center.translate(size.width * 0.13, -size.height * 0.04),
      radius: radius * 0.28,
    ));
    canvas.drawCircle(
      center.translate(size.width * 0.13, -size.height * 0.04),
      radius * 0.28,
      Paint()..shader = innerGradient,
    );
  }

  @override
  bool shouldRepaint(covariant _OrahLogoPainter oldDelegate) => false;
}
