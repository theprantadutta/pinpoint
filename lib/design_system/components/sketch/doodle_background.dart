import 'package:flutter/material.dart';

import '../../animations.dart';
import '../../colors.dart';

/// Soft marker swooshes painted behind a screen's content.
///
/// One cached [CustomPainter] in a [RepaintBoundary]: it repaints only when
/// the size, colours or offset change, never on scroll. Coordinates are for a
/// 390-wide, 200-tall band and scale with width; [top] is the band's y
/// offset (per screen, from the mocks). Mirrors in RTL.
///
/// Paints nothing when the user turned doodles off, under high contrast, or
/// when the OS asks to remove animations.
class DoodleBackground extends StatelessWidget {
  const DoodleBackground({
    super.key,
    required this.child,
    this.top = 70,
    this.squiggle = false,
    this.animate = false,
  });

  final Widget child;
  final double top;
  final bool squiggle;

  /// Draw the strokes on (splash / onboarding only), 900ms.
  final bool animate;

  /// Per-screen band offsets from the mocks.
  static const double homeTop = 70;
  static const double drawerTop = 300;
  static const double foldersTop = 60;
  static const double editorTop = 520;
  static const double todoTop = 40;
  static const double filtersTop = 40;
  static const double settingsTop = 50;
  static const double premiumTop = 50;

  static bool enabled(BuildContext context) {
    final s = context.sketch;
    final noMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hc = MediaQuery.maybeHighContrastOf(context) ?? false;
    return s.doodlesEnabled && !noMotion && !hc;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled(context)) return child;
    final s = context.sketch;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget paint(double progress) => CustomPaint(
          painter: DoodlePainter(
            color: s.doodle,
            accent: s.doodleAccent,
            top: top,
            squiggle: squiggle,
            rtl: rtl,
            progress: progress,
          ),
        );

    // Clipped: the strokes start left of x=0, run past the right edge and
    // are 16 wide, so unclipped they bleed into whatever sits beside this
    // background — on a tablet, the neighbouring pane of the split layout.
    final layer = Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: RepaintBoundary(
            child: animate
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: SketchMotion.doodleDraw,
                    curve: SketchMotion.enter,
                    builder: (_, v, __) => paint(v),
                  )
                : paint(1),
          ),
        ),
      ),
    );

    return Stack(children: [layer, child]);
  }
}

class DoodlePainter extends CustomPainter {
  DoodlePainter({
    required this.color,
    required this.accent,
    required this.top,
    required this.squiggle,
    required this.rtl,
    this.progress = 1,
  });

  final Color color;
  final Color accent;
  final double top;
  final bool squiggle;
  final bool rtl;
  final double progress;

  static Path swooshA() => Path()
    ..moveTo(-20, 70)
    ..cubicTo(60, 10, 140, 130, 220, 60)
    // "S 360 10, 420 80": reflected control of (140,130) about (220,60).
    ..cubicTo(300, -10, 360, 10, 420, 80);

  static Path swooshB() => Path()
    ..moveTo(-20, 150)
    ..cubicTo(80, 100, 170, 220, 260, 150)
    ..cubicTo(350, 80, 380, 120, 420, 170);

  static Path squigglePath() => Path()
    ..moveTo(290, 22)
    ..quadraticBezierTo(300, 8, 310, 22)
    ..quadraticBezierTo(320, 36, 330, 22)
    ..quadraticBezierTo(340, 8, 350, 22);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    canvas.save();
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.translate(0, top);
    canvas.scale(sx, sx);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    void draw(Path p, Paint paint) {
      if (progress >= 1) {
        canvas.drawPath(p, paint);
        return;
      }
      for (final m in p.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * progress), paint);
      }
    }

    draw(swooshA(), stroke);
    draw(swooshB(), stroke);
    if (squiggle) {
      draw(
        squigglePath(),
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DoodlePainter o) =>
      o.color != color ||
      o.accent != accent ||
      o.top != top ||
      o.squiggle != squiggle ||
      o.rtl != rtl ||
      o.progress != progress;
}
