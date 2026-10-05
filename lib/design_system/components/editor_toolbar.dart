import 'package:flutter/material.dart';

import '../animations.dart';
import '../colors.dart';
import '../elevations.dart';
import '../spacing.dart';
import '../typography.dart';
import 'sketch/sketch_pressable.dart';

/// One tool on the [EditorToolbar]: an icon or a short text glyph ("B",
/// "H1"). Active tools sit in a 42px on-inverse circle.
@immutable
class EditorToolbarItem {
  const EditorToolbarItem({
    required this.semanticLabel,
    required this.onPressed,
    this.icon,
    this.glyph,
    this.glyphStyle,
    this.active = false,
  }) : assert(icon != null || glyph != null);

  final String semanticLabel;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// A short text glyph drawn instead of an icon. Formatting glyphs (B, I, U,
  /// S, H1) are universal, so they are not localized; [semanticLabel] is.
  final String? glyph;

  /// Merged over the toolbar's 16/700 glyph style (italic for "I", etc.).
  final TextStyle? glyphStyle;
  final bool active;
}

/// The Sketchbook editor toolbar: a 58px inverse stadium floating above the
/// keyboard, with the note-colour dot on the start side and the tools in a
/// horizontal scroller (it scrolls when the tools overflow the width).
///
/// Purely presentational — it knows nothing about the document. The
/// rich-text editor builds the [items] (see `MarkdownToolbar`).
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.items,
    required this.semanticLabel,
    this.color,
    this.colorLabel,
    this.onColorPressed,
  });

  static const double height = 58;

  /// The inset from the screen edges and from the bottom (keyboard closed).
  static const double inset = 16;
  static const double bottomGap = 30;

  final List<EditorToolbarItem> items;

  /// Announced for the toolbar as a whole ("Formatting").
  final String semanticLabel;

  /// The colour dot's fill: the note's pastel, or null for the pen colour
  /// (no note colour).
  final Color? color;
  final String? colorLabel;
  final VoidCallback? onColorPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        height: height,
        decoration: ShapeDecoration(
          color: s.inverse,
          shape: const StadiumBorder(),
          shadows: SketchShadows.dock,
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsetsDirectional.only(start: 6, end: 4),
        child: Row(
          children: [
            if (onColorPressed != null)
              _ColorDot(
                color: color,
                label: colorLabel ?? '',
                onPressed: onColorPressed!,
              ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(start: 6, end: 4),
                child: Row(
                  children: [
                    for (final item in items) _ToolButton(item: item),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 22px dot with an inverse gap ring and an on-inverse outer ring.
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final Color? color;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final fill = color ?? s.pen;
    return SketchPressable(
      onTap: onPressed,
      semanticLabel: label,
      child: SizedBox(
        width: 44,
        height: EditorToolbar.height,
        child: Center(
          child: Container(
            width: 29,
            height: 29,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: s.onInverse, width: SketchStroke.outline),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                // A pastel keeps its ink outline (visible on the cream dark
                // toolbar); the pen colour stands on its own.
                border: color == null
                    ? null
                    : Border.all(
                        color: SketchPastels.onPastel,
                        width: SketchStroke.pastel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.item});

  final EditorToolbarItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final active = item.active;
    final fg = active ? s.inverse : s.onInverse;
    final dur = SketchMotion.of(context, SketchMotion.fast);

    final Widget glyph = item.glyph != null
        ? Text(
            item.glyph!,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: t.button
                .copyWith(color: fg, height: 1, decorationColor: fg)
                .merge(item.glyphStyle),
          )
        : Icon(item.icon, size: 20, color: fg);

    return SketchPressable(
      onTap: item.onPressed,
      semanticLabel: item.semanticLabel,
      selected: active,
      enabled: item.onPressed != null,
      child: SizedBox(
        width: 42,
        height: EditorToolbar.height,
        child: Center(
          child: AnimatedContainer(
            duration: dur,
            curve: SketchMotion.enter,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active ? s.onInverse : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(child: glyph),
          ),
        ),
      ),
    );
  }
}

/// Positions an [EditorToolbar] the way the editor floats it: inset 16 from
/// the sides, 30 from the bottom with the keyboard closed, 8 above it when
/// open. Width is capped so it stays a pill on tablets.
///
/// [keyboardOpen] is passed in rather than read here: inside a resizing
/// [Scaffold] body the keyboard inset has already been removed from the
/// [MediaQuery].
class EditorToolbarDock extends StatelessWidget {
  const EditorToolbarDock({
    super.key,
    required this.child,
    this.keyboardOpen = false,
  });

  final Widget child;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = keyboardOpen
        ? 8.0
        : (mq.padding.bottom + 8 > EditorToolbar.bottomGap
            ? mq.padding.bottom + 8
            : EditorToolbar.bottomGap);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          EditorToolbar.inset, 0, EditorToolbar.inset, bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: SketchSpace.maxContentWidth - 40),
          child: child,
        ),
      ),
    );
  }
}
