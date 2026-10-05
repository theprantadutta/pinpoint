import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../spacing.dart';
import 'dashed_border.dart';
import 'sketch_pressable.dart';

/// The Sketchbook card: surface fill, 1.5px outline, radius 18.
///
/// With [pastel] it becomes a pastel card — pastel fill, ink outline and ink
/// content in BOTH themes. [OnPastel] is applied to the subtree so text and
/// icons inside pick up ink without each child having to know.
class SketchCard extends StatelessWidget {
  const SketchCard({
    super.key,
    required this.child,
    this.pastel,
    this.padding = const EdgeInsets.all(SketchSpace.cardPad),
    this.radius = SketchRadius.card,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.borderColor,
    this.borderWidth,
    this.color,
    this.dashed = false,
    this.selected,
  });

  final Widget child;
  final Color? pastel;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  /// Override the outline (e.g. hairline for a done checklist row).
  final Color? borderColor;
  final double? borderWidth;

  /// Override the fill when not a pastel (e.g. transparent).
  final Color? color;

  /// The dashed "add" affordance.
  final bool dashed;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final isPastel = pastel != null;
    final fill = pastel ?? color ?? s.surface;
    final stroke =
        borderColor ?? (isPastel ? SketchPastels.onPastel : s.outline);
    final width = borderWidth ?? SketchStroke.outline;
    final shape = BorderRadius.circular(radius);

    Widget content = Padding(padding: padding, child: child);
    if (isPastel) content = OnPastel(child: content);

    Widget card = dashed
        ? CustomPaint(
            foregroundPainter: DashedRRectPainter(
                color: stroke, strokeWidth: width, radius: radius),
            child: Container(
              decoration: BoxDecoration(color: fill, borderRadius: shape),
              child: content,
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: shape,
              border: Border.all(color: stroke, width: width),
            ),
            child: content,
          );

    if (onTap == null && onLongPress == null) {
      return semanticLabel == null
          ? card
          : Semantics(label: semanticLabel, child: card);
    }
    return SketchPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      selected: selected,
      child: card,
    );
  }
}

/// Forces ink text and icons for content drawn on a pastel. Pastels are the
/// same in both themes, so their content must not follow the theme's ink.
class OnPastel extends StatelessWidget {
  const OnPastel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(color: SketchPastels.onPastel),
      child: IconTheme.merge(
        data: const IconThemeData(color: SketchPastels.onPastel),
        child: child,
      ),
    );
  }
}

/// A small rounded pastel square — note-colour bullets, folder colour marks.
class PastelSquare extends StatelessWidget {
  const PastelSquare({
    super.key,
    required this.color,
    this.size = 13,
    this.radius = SketchRadius.bullet,
    this.borderWidth = SketchStroke.pastel,
  });

  final Color color;
  final double size;
  final double radius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SketchPastels.onPastel, width: borderWidth),
      ),
    );
  }
}

/// Up to [max] overlapping pastel squares (folder tiles: the colours of the
/// notes inside). Overlap mirrors in RTL.
class PastelStack extends StatelessWidget {
  const PastelStack({
    super.key,
    required this.colors,
    this.size = 20,
    this.overlap = 6,
    this.max = 3,
  });

  final List<Color> colors;
  final double size;
  final double overlap;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = colors.take(max).toList();
    if (shown.isEmpty) return SizedBox(height: size);
    return SizedBox(
      height: size,
      width: size + (shown.length - 1) * (size - overlap),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: i * (size - overlap),
              top: 0,
              child: PastelSquare(color: shown[i], size: size, radius: 6),
            ),
        ],
      ),
    );
  }
}
