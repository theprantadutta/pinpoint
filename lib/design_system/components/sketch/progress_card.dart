import 'package:flutter/material.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'sketch_card.dart';

/// The mint progress card for a checklist: a label, "{done} of {total} done",
/// a big percentage that counts up, and a segmented bar.
///
/// Strings come in already localized; the card only lays them out.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.done,
    required this.total,
    required this.label,
    required this.summary,
    this.compact = false,
    this.pastel = SketchPastels.mint,
    this.onTap,
    this.maxSegments = 12,
  });

  final int done;
  final int total;

  /// "Progress".
  final String label;

  /// "2 of 4 done".
  final String summary;

  /// The h72 group header used on the Todo screen.
  final bool compact;
  final Color pastel;
  final VoidCallback? onTap;

  /// Above this many items the bar becomes one continuous track.
  final int maxSegments;

  double get fraction => total == 0 ? 0 : done / total;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final dur = SketchMotion.of(context, const Duration(milliseconds: 420));
    final percent = (fraction * 100).round();

    final number = TweenAnimationBuilder<int>(
      tween: IntTween(end: percent),
      duration: dur,
      curve: SketchMotion.enter,
      builder: (_, v, __) => Text(
        '$v%',
        style:
            (compact ? t.displayNumber.copyWith(fontSize: 28) : t.displayNumber)
                .copyWith(color: SketchPastels.onPastel),
      ),
    );

    return SketchCard(
      pastel: pastel,
      radius: SketchRadius.group,
      onTap: onTap,
      semanticLabel: '$label, $summary, $percent%',
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              t.chip.copyWith(color: SketchPastels.onPastel)),
                      const SizedBox(height: 2),
                      Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.cardTitleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: SketchPastels.onPastel)),
                    ],
                  ),
                ),
                number,
              ],
            ),
            SizedBox(height: compact ? 10 : 12),
            SegmentedProgressBar(
              done: done,
              total: total,
              maxSegments: maxSegments,
              height: compact ? 8 : 10,
            ),
          ],
        ),
      ),
    );
  }
}

/// N segments, ink-filled when done and ink-outlined otherwise. Collapses to
/// a single track once there are more than [maxSegments] items.
class SegmentedProgressBar extends StatelessWidget {
  const SegmentedProgressBar({
    super.key,
    required this.done,
    required this.total,
    this.maxSegments = 12,
    this.height = 10,
    this.color = SketchPastels.onPastel,
  });

  final int done;
  final int total;
  final int maxSegments;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(height / 2);
    final dur = SketchMotion.of(context, SketchMotion.base);
    Widget seg(bool filled) => AnimatedContainer(
          duration: dur,
          height: height,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: r,
            border: Border.all(color: color, width: SketchStroke.outline),
          ),
        );

    if (total <= 0) return seg(false);

    if (total > maxSegments) {
      return LayoutBuilder(
        builder: (_, c) => Stack(
          children: [
            seg(false),
            AnimatedContainer(
              duration: dur,
              width: c.maxWidth * (done / total).clamp(0.0, 1.0),
              height: height,
              decoration: BoxDecoration(color: color, borderRadius: r),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(child: seg(i < done)),
        ],
      ],
    );
  }
}

/// A plain usage bar: soft track, ink fill (Settings usage cards).
class UsageBar extends StatelessWidget {
  const UsageBar({
    super.key,
    required this.fraction,
    this.height = 6,
    this.fill,
    this.track,
    this.outlined = false,
  });

  final double fraction;
  final double height;
  final Color? fill;
  final Color? track;

  /// Outline track (drawer plan card) instead of a soft fill.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final r = BorderRadius.circular(height / 2);
    final f = fraction.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : (track ?? s.soft),
        borderRadius: r,
        border: outlined
            ? Border.all(color: s.outline, width: SketchStroke.pastel)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: f,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill ?? s.ink,
              borderRadius: r,
              border: outlined && f > 0 && f < 1
                  ? BorderDirectional(
                      end: BorderSide(
                          color: s.outline, width: SketchStroke.pastel))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
