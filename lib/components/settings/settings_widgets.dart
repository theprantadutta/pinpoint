import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// The "selected" mark on a settings list row: an ink check in a 24px mint
/// circle with an ink outline. An icon, not a "✓" character — the bundled
/// UI fonts have no such glyph.
class SelectedCheck extends StatelessWidget {
  const SelectedCheck({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SketchPastels.mint,
        shape: BoxShape.circle,
        border: Border.all(
            color: SketchPastels.onPastel, width: SketchStroke.pastel),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check_rounded,
          size: size * 0.64, color: SketchPastels.onPastel),
    );
  }
}

/// A row in a single-choice settings list (theme mode, accent, font,
/// language): label, optional subtitle, and [SelectedCheck] when chosen.
class SketchChoiceRow extends StatelessWidget {
  const SketchChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.labelStyle,
    this.labelDirection,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  /// Shown when not selected (e.g. a "PRO" tag).
  final Widget? trailing;
  final TextStyle? labelStyle;

  /// Lay the label out in its own script's direction (endonyms).
  final TextDirection? labelDirection;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    Widget name = Text(label, style: labelStyle ?? t.body);
    if (labelDirection != null) {
      name = Directionality(textDirection: labelDirection!, child: name);
    }

    return SketchPressable(
      onTap: onTap,
      selected: selected,
      scale: 0.985,
      semanticLabel: subtitle == null ? label : '$label, $subtitle',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      if (subtitle != null)
                        Text(subtitle!,
                            style: t.caption.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  const SelectedCheck()
                else if (trailing != null)
                  trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short muted value ("Off", "On") for the trailing slot of a [SketchRow].
///
/// SketchRow's own `value` shares the row's width with the label, which
/// wraps a long label ("Zero-knowledge mode") around a one-word value; as a
/// trailing widget the value keeps its natural width and the label gets the
/// rest. Pair it with `chevron: true`.
class SettingsValue extends StatelessWidget {
  const SettingsValue(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        style: context.type.bodyRegular
            .copyWith(fontSize: 14, color: context.sketch.muted),
      );
}

/// A short bulleted line: a 6px ink dot and wrapped text.
class SketchBulletLine extends StatelessWidget {
  const SketchBulletLine({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final fg = color ?? context.sketch.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: t.bodyRegular.copyWith(fontSize: 13.5, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
