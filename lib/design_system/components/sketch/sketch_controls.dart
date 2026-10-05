import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'sketch_pressable.dart';

/// The Sketchbook toggle: a 48×28 stadium. On, an inverse track with a 22px
/// mint knob at the end; off, an outlined track with a 19px ink knob at the
/// start. Mirrors in RTL.
class SketchToggle extends StatelessWidget {
  const SketchToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final dur = SketchMotion.of(context, SketchMotion.base);
    final enabled = onChanged != null;

    final track = AnimatedContainer(
      duration: dur,
      curve: SketchMotion.enter,
      width: 48,
      height: 28,
      // On, the border matches the fill, so the knob gets the extra 1.5px:
      // 22px on vs 19px off, as specced.
      padding: EdgeInsets.all(value ? 1.5 : 3),
      decoration: BoxDecoration(
        color: value ? s.inverse : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? s.inverse : s.outline,
          width: SketchStroke.outline,
        ),
      ),
      child: AnimatedAlign(
        duration: dur,
        curve: SketchMotion.enter,
        alignment: value
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: AnimatedContainer(
          duration: dur,
          curve: SketchMotion.enter,
          width: value ? 22 : 19,
          height: value ? 22 : 19,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? SketchPastels.mint : s.ink,
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        toggled: value,
        label: semanticLabel,
        enabled: enabled,
        child: SketchPressable(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onChanged!(!value);
                }
              : null,
          child: SizedBox(
            width: 52,
            height: SketchSpace.minTap,
            child: Center(
              child: Opacity(opacity: enabled ? 1 : 0.4, child: track),
            ),
          ),
        ),
      ),
    );
  }
}

/// One option of a [SketchSegmentedControl].
class SketchSegment<T> {
  const SketchSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// An outlined stadium with 2px padding; the selected segment is an inverse
/// pill. Text 12/600.
class SketchSegmentedControl<T> extends StatelessWidget {
  const SketchSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
    this.expand = false,
  });

  /// Fill the available width with equal segments (a tab bar), instead of
  /// hugging the labels (an inline switch).
  final bool expand;

  final List<SketchSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final dur = SketchMotion.of(context, SketchMotion.base);

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: ShapeDecoration(
          shape: StadiumBorder(
              side: BorderSide(color: s.outline, width: SketchStroke.outline)),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (final seg in segments)
              _maybeExpanded(SketchPressable(
                onTap: () {
                  if (seg.value == selected) return;
                  HapticFeedback.selectionClick();
                  onChanged(seg.value);
                },
                selected: seg.value == selected,
                semanticLabel: seg.label,
                child: AnimatedContainer(
                  duration: dur,
                  curve: SketchMotion.enter,
                  constraints: BoxConstraints(minHeight: expand ? 36 : 30),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        seg.value == selected ? s.inverse : Colors.transparent,
                    borderRadius: BorderRadius.circular(expand ? 18 : 13),
                  ),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Text(
                      seg.label,
                      style: t.chip.copyWith(
                        fontSize: expand ? 13 : 12,
                        color: seg.value == selected ? s.onInverse : s.ink,
                      ),
                    ),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _maybeExpanded(Widget child) =>
      expand ? Expanded(child: child) : child;
}
