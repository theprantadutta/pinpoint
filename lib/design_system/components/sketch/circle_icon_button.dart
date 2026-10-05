import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../spacing.dart';
import 'sketch_pressable.dart';

/// A 42px outlined circle with an icon. The hit area is padded to 44.
///
/// [semanticLabel] is required: an icon-only button is invisible to a screen
/// reader without one. [fill] gives the filled variant — a pastel (ink icon,
/// ink outline) or `context.sketch.inverse` (on-inverse icon, no outline).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.fill,
    this.size = 42,
    this.iconSize = 20,
    this.iconColor,
    this.child,
    this.onLongPress,
    this.haptic = false,
    this.selected,
  });

  final IconData? icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color? fill;
  final double size;
  final double iconSize;
  final Color? iconColor;

  /// Custom content instead of [icon] (e.g. a text glyph).
  final Widget? child;
  final VoidCallback? onLongPress;
  final bool haptic;
  final bool? selected;

  /// The standard back button. Mirrors in RTL.
  static Widget back(BuildContext context, {VoidCallback? onPressed}) {
    return CircleIconButton(
      icon: Icons.arrow_back_rounded,
      semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }

  /// The standard close button.
  static Widget close(BuildContext context, {VoidCallback? onPressed}) {
    return CircleIconButton(
      icon: Icons.close_rounded,
      size: 40,
      semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final isInverse = fill != null && fill == s.inverse;
    final isPastel = fill != null && !isInverse && fill != Colors.transparent;
    final fg = iconColor ??
        (isInverse
            ? s.onInverse
            : isPastel
                ? SketchPastels.onPastel
                : s.ink);
    final stroke = isInverse
        ? null
        : BorderSide(
            color: isPastel ? SketchPastels.onPastel : s.outline,
            width: SketchStroke.outline,
          );

    final tap = (size < SketchSpace.minTap) ? SketchSpace.minTap : size + 2;

    return SketchPressable(
      onTap: onPressed,
      onLongPress: onLongPress,
      haptic: haptic,
      semanticLabel: semanticLabel,
      selected: selected,
      enabled: onPressed != null,
      child: SizedBox(
        width: tap,
        height: tap,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: ShapeDecoration(
              color: fill ?? Colors.transparent,
              shape: CircleBorder(side: stroke ?? BorderSide.none),
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: IconTheme.merge(
                data: IconThemeData(color: fg, size: iconSize),
                child: child ??
                    Icon(
                      icon,
                      // Directional glyphs (arrows) flip in RTL.
                      textDirection: Directionality.of(context),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
