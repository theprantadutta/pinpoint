import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'sketch_pressable.dart';

enum PillButtonVariant {
  /// Inverse fill — the one primary action on a screen.
  primary,

  /// 1.5px outline, transparent.
  secondary,

  /// Pastel fill with ink outline (pass [PillButton.pastel]).
  pastel,

  /// Outline with error-coloured text (Sign out, destructive confirm).
  destructive,
}

/// The Sketchbook pill button. Height 56, 16/700.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.icon,
    this.leading,
    this.pastel,
    this.loading = false,
    this.expand = true,
    this.height = 56,
    this.semanticLabel,
  });

  const PillButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.loading = false,
    this.expand = true,
    this.height = 56,
    this.semanticLabel,
  })  : variant = PillButtonVariant.secondary,
        pastel = null;

  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final IconData? icon;

  /// A custom leading widget (e.g. a provider logo). Wins over [icon].
  final Widget? leading;
  final Color? pastel;
  final bool loading;
  final bool expand;
  final double height;
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    final (Color fill, Color fg, Color? stroke) = switch (variant) {
      PillButtonVariant.primary => (s.inverse, s.onInverse, null),
      PillButtonVariant.secondary => (Colors.transparent, s.ink, s.outline),
      PillButtonVariant.pastel => (
          pastel ?? s.highlight,
          SketchPastels.onPastel,
          SketchPastels.onPastel
        ),
      PillButtonVariant.destructive => (
          Colors.transparent,
          SketchFunctional.error,
          s.outline
        ),
    };

    final child = Container(
      height: height,
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: ShapeDecoration(
        color: fill,
        shape: StadiumBorder(
          side: stroke == null
              ? BorderSide.none
              : BorderSide(color: stroke, width: SketchStroke.outline),
        ),
      ),
      alignment: Alignment.center,
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 10),
                ] else if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.button.copyWith(color: fg),
                  ),
                ),
              ],
            ),
    );

    return SketchPressable(
      onTap: _enabled ? onPressed : null,
      enabled: _enabled,
      semanticLabel: semanticLabel ?? label,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: ExcludeSemantics(child: child),
      ),
    );
  }
}

/// An underlined text action ("View all", "Reset", "Restore").
class SketchTextAction extends StatelessWidget {
  const SketchTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.style,
    this.muted = false,
    this.underline = true,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final TextStyle? style;
  final bool muted;
  final bool underline;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final fg = color ?? (muted ? s.muted : s.ink);
    return SketchPressable(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SketchSpace.minTap),
        child: Align(
          widthFactor: 1,
          child: ExcludeSemantics(
            child: Text(
              label,
              style: (style ?? context.type.chip).copyWith(
                color: fg,
                decoration: underline ? TextDecoration.underline : null,
                decorationColor: fg,
                decorationThickness: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
