import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'sketch_pressable.dart';

/// The Sketchbook checkbox: 24×24, radius 8, 2px ink stroke. Checked, it
/// fills mint with an ink outline and the check stroke draws in (180ms).
class SketchCheckbox extends StatelessWidget {
  const SketchCheckbox({
    super.key,
    required this.checked,
    this.onChanged,
    this.size = 24,
    this.radius = SketchRadius.checkbox,
    this.semanticLabel,
  });

  /// The 12px card-preview checkbox.
  const SketchCheckbox.mini({
    super.key,
    required this.checked,
    this.semanticLabel,
  })  : onChanged = null,
        size = 12,
        radius = SketchRadius.checkboxSmall;

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final double size;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final dur = SketchMotion.of(context, SketchMotion.check);
    final small = size < 16;

    final box = AnimatedContainer(
      duration: dur,
      curve: SketchMotion.enter,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? SketchPastels.mint : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: checked ? SketchPastels.onPastel : s.ink,
          width: small ? SketchStroke.outline : SketchStroke.checkbox,
        ),
      ),
      child: small
          ? null
          : TweenAnimationBuilder<double>(
              tween: Tween(end: checked ? 1 : 0),
              duration: dur,
              curve: SketchMotion.enter,
              builder: (_, t, __) => CustomPaint(
                painter: _CheckPainter(progress: t),
              ),
            ),
    );

    if (onChanged == null) {
      return Semantics(checked: checked, label: semanticLabel, child: box);
    }
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        label: semanticLabel,
        child: SketchPressable(
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged!(!checked);
          },
          child: SizedBox(
            width: SketchSpace.minTap,
            height: SketchSpace.minTap,
            child: Center(child: box),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.26, h * 0.52)
      ..lineTo(w * 0.43, h * 0.68)
      ..lineTo(w * 0.74, h * 0.34);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = SketchPastels.onPastel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// A checklist row: 58 tall, radius 18. Open rows sit on surface with an
/// outline; done rows drop the fill, take a hairline border, mute the text
/// and strike it through.
///
/// [child] replaces the label when the row is editable (a TextField).
class ChecklistRow extends StatelessWidget {
  const ChecklistRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
    this.child,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.leading,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final Widget? child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// A drag handle, shown in reorder mode.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final dur = SketchMotion.of(context, SketchMotion.base);

    final text = AnimatedDefaultTextStyle(
      duration: dur,
      style: t.bodyLarge.copyWith(
        fontWeight: checked ? FontWeight.w500 : FontWeight.w600,
        height: 1.35,
        color: checked ? s.muted : s.ink,
        decoration: checked ? TextDecoration.lineThrough : null,
        decorationColor: s.muted,
        decorationThickness: 1.5,
      ),
      child: child ?? Text(label, maxLines: 3, overflow: TextOverflow.ellipsis),
    );

    final row = AnimatedContainer(
      duration: dur,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
      decoration: BoxDecoration(
        color: checked ? Colors.transparent : s.surface,
        borderRadius: BorderRadius.circular(SketchRadius.card),
        border: Border.all(
          color: checked ? s.hairline : s.outline,
          width: SketchStroke.outline,
        ),
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          SketchCheckbox(
            checked: checked,
            onChanged: onChanged,
            semanticLabel: label,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: text,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap == null && onLongPress == null) return row;
    return SketchPressable(onTap: onTap, onLongPress: onLongPress, child: row);
  }
}

/// A one-line checklist preview for note cards (12px box, 12px text).
class ChecklistPreviewLine extends StatelessWidget {
  const ChecklistPreviewLine({
    super.key,
    required this.label,
    required this.checked,
    this.onPastel = false,
  });

  final String label;
  final bool checked;
  final bool onPastel;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final ink = onPastel ? SketchPastels.onPastel : s.ink;
    final muted =
        onPastel ? SketchPastels.onPastel.withValues(alpha: 0.6) : s.muted;
    return Row(
      children: [
        _MiniBox(checked: checked, ink: ink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(
              color: checked ? muted : ink,
              decoration: checked ? TextDecoration.lineThrough : null,
              decorationColor: muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBox extends StatelessWidget {
  const _MiniBox({required this.checked, required this.ink});

  final bool checked;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: checked ? SketchPastels.mint : Colors.transparent,
        borderRadius: BorderRadius.circular(SketchRadius.checkboxSmall),
        border: Border.all(
          color: checked ? SketchPastels.onPastel : ink,
          width: SketchStroke.outline,
        ),
      ),
    );
  }
}
