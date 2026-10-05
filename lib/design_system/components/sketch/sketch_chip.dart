import 'package:flutter/material.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'sketch_pressable.dart';

/// The Sketchbook chip: a stadium with a 1.5px outline, 13/600 label.
///
/// - unselected: transparent
/// - selected, no [pastel]: inverse fill, on-inverse text (single-select)
/// - selected, with [pastel]: pastel fill, ink outline, a leading check, 700
///   (a check icon rather than "✓": the UI fonts have no such glyph)
///   (multi-select)
class SketchChip extends StatelessWidget {
  const SketchChip({
    super.key,
    required this.label,
    this.selected = false,
    this.pastel,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.semanticLabel,
    this.textStyle,
  });

  final String label;
  final bool selected;
  final Color? pastel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final TextStyle? textStyle;

  /// The filter sheet's slightly taller chip (9×14).
  static const EdgeInsets filterPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 9);

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    final Color fill;
    final Color fg;
    final Color stroke;
    if (selected && pastel != null) {
      fill = pastel!;
      fg = SketchPastels.onPastel;
      stroke = SketchPastels.onPastel;
    } else if (selected) {
      fill = s.inverse;
      fg = s.onInverse;
      stroke = s.inverse;
    } else {
      fill = Colors.transparent;
      fg = s.ink;
      stroke = s.outline;
    }

    final base = (textStyle ?? t.chip).copyWith(
      color: fg,
      fontWeight: selected && pastel != null ? FontWeight.w700 : null,
    );

    final checked = selected && pastel != null;

    return SketchPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: SketchMotion.of(context, const Duration(milliseconds: 150)),
        curve: SketchMotion.enter,
        constraints: const BoxConstraints(minHeight: 36),
        padding: padding,
        decoration: ShapeDecoration(
          color: fill,
          shape: StadiumBorder(
            side: BorderSide(color: stroke, width: SketchStroke.outline),
          ),
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: fg, size: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (checked && leading == null) ...[
                const Icon(Icons.check_rounded, size: 15),
                const SizedBox(width: 4),
              ],
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: SketchMotion.of(
                      context, const Duration(milliseconds: 150)),
                  style: base,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // The pressable announces it; the text is the label.
                    semanticsLabel: semanticLabel == null ? label : null,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small outlined pill used as a tag ("Pinned", "Auto-saved", "PRO").
class SketchTag extends StatelessWidget {
  const SketchTag({
    super.key,
    required this.label,
    this.pastel,
    this.inverse = false,
    this.icon,
    this.dense = true,
    this.textColor,
  });

  final String label;
  final Color? pastel;
  final bool inverse;
  final IconData? icon;

  /// 3×9 padding, 11/600 when dense; 6×12, 12/700 otherwise.
  final bool dense;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final Color fg = textColor ??
        (inverse
            ? (pastel ?? s.onInverse)
            : pastel != null
                ? SketchPastels.onPastel
                : s.ink);
    final Color fill = inverse ? s.inverse : (pastel ?? Colors.transparent);
    final Color stroke = inverse
        ? s.inverse
        : (pastel != null ? SketchPastels.onPastel : s.outline);
    final style = (dense
            ? t.chip.copyWith(fontSize: 11)
            : t.chip.copyWith(fontSize: 12, fontWeight: FontWeight.w700))
        .copyWith(color: fg, height: 1.2);

    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: fill,
        shape: StadiumBorder(
            side: BorderSide(color: stroke, width: SketchStroke.pastel)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}
