import 'package:flutter/material.dart';

import '../../spacing.dart';

/// Paints a dashed rounded-rect outline — the "add" affordance
/// (New folder, Add item, Add a step). Dash 6, gap 4, 1.5px.
class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({
    required this.color,
    this.strokeWidth = SketchStroke.outline,
    this.radius = SketchRadius.card,
    this.dash = SketchStroke.dashLength,
    this.gap = SketchStroke.dashGap,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}
