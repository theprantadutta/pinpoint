import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Google "G", painted so it needs no image asset (there is none in the
/// bundle — the old `google_logo.png` reference always fell back to an icon).
///
/// These four colours are Google's brand colours, which its sign-in branding
/// guidelines require on the mark. They are third-party brand values, not
/// Sketchbook UI colours, and must not be reused anywhere else.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _GoogleGPainter()),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.18;
    final r = (s - stroke) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    double rad(double deg) => deg * math.pi / 180;

    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Angles run clockwise from 3 o'clock; the opening is at the upper right.
    canvas.drawArc(rect, rad(-40), rad(-110), false, arc(_red));
    canvas.drawArc(rect, rad(150), rad(60), false, arc(_yellow));
    canvas.drawArc(rect, rad(45), rad(105), false, arc(_green));
    canvas.drawArc(rect, rad(0), rad(45), false, arc(_blue));
    // The crossbar.
    canvas.drawRect(
      Rect.fromLTRB(c.dx - stroke * 0.1, c.dy - stroke / 2,
          c.dx + r + stroke / 2, c.dy + stroke / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => false;
}
