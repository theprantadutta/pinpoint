import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'circle_icon_button.dart';
import 'dashed_border.dart';
import 'doodle_background.dart';
import 'pill_button.dart';
import 'sketch_pressable.dart';

/// The standard Sketchbook screen: paper background, doodles at [doodleTop],
/// a header row (back button, title, actions) and content capped to a
/// readable width on tablets.
class SketchScaffold extends StatelessWidget {
  const SketchScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.largeTitle = false,
    this.leading,
    this.showBack = true,
    this.actions = const [],
    this.doodleTop = 50,
    this.squiggle = false,
    this.floating,
    this.bottom,
    this.onBack,
    this.resizeToAvoidBottomInset = true,
    this.backgroundColor,
  });

  final Widget body;
  final String? title;
  final String? subtitle;

  /// 30/800 title under the header row ("My folders") instead of 26/800
  /// beside the back button ("Settings").
  final bool largeTitle;
  final Widget? leading;
  final bool showBack;
  final List<Widget> actions;
  final double doodleTop;
  final bool squiggle;

  /// Overlaid at the bottom (a dock, an add bar).
  final Widget? floating;

  /// Pinned below the body (a CTA).
  final Widget? bottom;
  final VoidCallback? onBack;
  final bool resizeToAvoidBottomInset;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    final lead = leading ??
        (showBack ? CircleIconButton.back(context, onPressed: onBack) : null);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(SketchSpace.screenX - 1,
          SketchSpace.headerTop, SketchSpace.screenX - 1, 0),
      child: Row(
        children: [
          if (lead != null) lead,
          if (!largeTitle && title != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.sheetTitle),
              ),
            ),
          ] else
            const Spacer(),
          ...actions,
        ],
      ),
    );

    final titleBlock = largeTitle && title != null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
                SketchSpace.screenX, 18, SketchSpace.screenX, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                    header: true, child: Text(title!, style: t.screenTitle)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: t.bodySmall),
                ],
              ],
            ),
          )
        : null;

    return Scaffold(
      backgroundColor: backgroundColor ?? s.bg,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: DoodleBackground(
        top: doodleTop,
        squiggle: squiggle,
        child: SafeArea(
          bottom: false,
          child: SketchContentWidth(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    if (titleBlock != null) titleBlock,
                    Expanded(child: body),
                    if (bottom != null)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              SketchSpace.screenX, 8, SketchSpace.screenX, 16),
                          child: bottom,
                        ),
                      ),
                  ],
                ),
                if (floating != null) floating!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centres content and caps it at [SketchSpace.maxContentWidth] — tablets get
/// a phone-proportioned column instead of stretched cards.
class SketchContentWidth extends StatelessWidget {
  const SketchContentWidth({
    super.key,
    required this.child,
    this.maxWidth = SketchSpace.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// "My folders ——— View all": an 18/700 title with an optional trailing
/// action, baseline-aligned.
class SketchSectionHeader extends StatelessWidget {
  const SketchSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
        SketchSpace.screenX, SketchSpace.section, SketchSpace.screenX, 0),
  });

  final String title;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.type.sectionTitle),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// "APPEARANCE" — an 11/700 uppercase muted overline above a group.
class SketchOverline extends StatelessWidget {
  const SketchOverline(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 8),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: context.type.overline),
      ),
    );
  }
}

/// A grouped outline card (radius 20) whose rows are separated by 1.5px
/// hairlines — the settings pattern.
class SketchGroup extends StatelessWidget {
  const SketchGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Container(height: SketchStroke.outline, color: s.hairline));
      }
      rows.add(children[i]);
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(SketchRadius.group),
        border: Border.all(color: s.outline, width: SketchStroke.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// A 56px row inside a [SketchGroup]: label (15/600), optional subtitle
/// (11 muted), optional leading icon, and a trailing widget or value text
/// with a chevron.
class SketchRow extends StatelessWidget {
  const SketchRow({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.trailing,
    this.value,
    this.onTap,
    this.chevron,
    this.labelColor,
    this.minHeight = 56,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  /// Muted value text ("Off", "Plus Jakarta") followed by "›".
  final String? value;
  final VoidCallback? onTap;

  /// Defaults to true when [onTap] is set and there is no [trailing].
  final bool? chevron;
  final Color? labelColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final showChevron = chevron ?? (onTap != null && trailing == null);

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: labelColor ?? s.ink),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.body.copyWith(color: labelColor ?? s.ink)),
                  if (subtitle != null)
                    Text(subtitle!, style: t.caption.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (showChevron)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2),
                child:
                    Icon(Icons.chevron_right_rounded, size: 20, color: s.muted),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return SketchPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: value == null ? label : '$label, $value',
      child: ExcludeSemantics(excluding: trailing == null, child: row),
    );
  }
}

/// A dashed "add" row ("Add item", "Add a step").
class SketchDashedButton extends StatelessWidget {
  const SketchDashedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.height = 54,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return SketchPressable(
      onTap: onTap,
      semanticLabel: label,
      child: CustomPaint(
        foregroundPainter: DashedRRectPainter(color: s.outline),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: s.ink),
              const SizedBox(width: 8),
              Text(label, style: context.type.chip),
            ],
          ),
        ),
      ),
    );
  }
}

/// The yellow upgrade banner ("5 of 5 free folders used · Upgrade").
class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.pastel = SketchPastels.yellow,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final Color pastel;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: pastel,
        borderRadius: BorderRadius.circular(SketchRadius.group),
        border: Border.all(
            color: SketchPastels.onPastel, width: SketchStroke.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SketchPastels.onPastel)),
                const SizedBox(height: 2),
                Text(message,
                    style: t.caption.copyWith(color: SketchPastels.onPastel)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SketchPressable(
            onTap: onAction,
            semanticLabel: actionLabel,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: ShapeDecoration(
                color: SketchPastels.onPastel,
                shape: const StadiumBorder(),
              ),
              alignment: Alignment.center,
              child: Text(actionLabel,
                  style: t.chip
                      .copyWith(fontWeight: FontWeight.w700, color: pastel)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A coloured 8px status dot.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: SketchPastels.onPastel, width: 1),
      ),
    );
  }
}

/// The inline pink error pill (auth, unlock).
class SketchErrorPill extends StatelessWidget {
  const SketchErrorPill({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: SketchFunctional.errorFill,
          borderRadius: BorderRadius.circular(SketchRadius.card),
          border: Border.all(
              color: SketchPastels.onPastel, width: SketchStroke.pastel),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 18, color: SketchFunctional.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: context.type.chip
                      .copyWith(color: SketchFunctional.error)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width primary [PillButton] pinned above the safe area.
class SketchBottomCta extends StatelessWidget {
  const SketchBottomCta({super.key, required this.button});

  final PillButton button;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              SketchSpace.screenX, 8, SketchSpace.screenX, 16),
          child: button,
        ),
      );
}
