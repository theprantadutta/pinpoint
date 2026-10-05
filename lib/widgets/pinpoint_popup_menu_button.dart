import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../services/crash_breadcrumbs.dart';

/// A [PopupMenuButton] replacement that anchors its menu **once**, when the
/// menu opens.
///
/// ## Why this exists
///
/// `PopupMenuButton` positions its menu through a `LayoutBuilder` whose
/// `_positionBuilder` callback re-runs on every relayout of the *open* menu.
/// Each run calls `button.localToGlobal(...)` on the button's render object.
/// Its guard is incomplete (popup_menu.dart):
///
/// ```dart
/// if (button == null || overlay == null || !button.attached || !overlay.attached) {
///   return _getDefaultPosition(constraints);
/// }
/// ```
///
/// It checks `attached` but never whether the box was laid out. A button can be
/// attached and yet unmeasured — it sits under a `RenderTransform` or
/// `RenderFractionalTranslation` belonging to a page transition, or inside an
/// offstage branch of the shell's `IndexedStack`. `localToGlobal` then walks
/// into `RenderTransform._effectiveTransform`, reads `size`, and throws:
///
/// ```
/// Bad state: RenderBox was not laid out: RenderTransform#b91c5
///   at PopupMenuButtonState._positionBuilder (popup_menu.dart:1671)
/// ```
///
/// The crash lands in a frame's layout phase, so it is fatal, and the stack
/// names a render object rather than a screen — which is why
/// [CrashBreadcrumbs.popupMenuOpened] exists to tag reports with the menu.
///
/// ## The fix
///
/// Compute the anchor rect once, at open time — when the button is by
/// definition on screen and laid out — and hand `showMenu` a fixed
/// [RelativeRect]. `showMenu` never consults the button again, so no later
/// relayout, transition, or tab switch can reach an unmeasured render object.
/// The menu no longer follows the button if it moves while open, which is the
/// correct trade for not crashing: the button is behind a modal barrier and
/// cannot be interacted with anyway.
///
/// Anything that cannot be measured is treated as "do not open" rather than
/// opened at a guessed position.
class PinpointPopupMenuButton<T> extends StatelessWidget {
  const PinpointPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.icon,
    this.iconSize,
    this.padding,
    this.tooltip,
    this.shape,
    this.color,
    this.elevation,
    this.offset = Offset.zero,
    this.onSelected,
    this.onOpened,
    this.onCanceled,
    this.dividers = true,
    this.size = SketchSpace.minTap,
  });

  /// Builds the entries. Called once per open, like `PopupMenuButton`'s.
  final List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder;

  /// The trigger glyph. Defaults to a "⋯".
  final Widget? icon;
  final double? iconSize;

  /// Kept for call-site compatibility; the trigger is a fixed 44px target.
  final EdgeInsetsGeometry? padding;

  /// Also the trigger's screen-reader label.
  final String? tooltip;

  /// Overrides the Sketchbook menu (surface, 1.5px outline, radius 18).
  final ShapeBorder? shape;
  final Color? color;
  final double? elevation;

  /// Shifts the menu relative to the button, matching `PopupMenuButton.offset`.
  final Offset offset;

  final void Function(T value)? onSelected;
  final VoidCallback? onOpened;
  final VoidCallback? onCanceled;

  /// Separate adjacent rows with a hairline.
  final bool dividers;

  /// The trigger's tap target.
  final double size;

  /// A 44px menu row: an optional leading icon and a 15/600 label.
  /// [destructive] paints both in the error colour.
  static PopupMenuItem<T> item<T>(
    BuildContext context, {
    required T value,
    required String label,
    IconData? icon,
    bool destructive = false,
    bool enabled = true,
  }) {
    final s = context.sketch;
    final fg = destructive ? SketchFunctional.error : s.ink;
    return PopupMenuItem<T>(
      value: value,
      enabled: enabled,
      height: SketchSpace.minTap,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.body.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final label =
        tooltip ?? MaterialLocalizations.of(context).showMenuTooltip;
    return SketchPressable(
      onTap: () => _open(context),
      semanticLabel: label,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: ExcludeSemantics(
            child: IconTheme.merge(
              data: IconThemeData(color: s.ink, size: iconSize ?? 22),
              child: icon ?? const Icon(Icons.more_horiz_rounded),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final position = _anchorOf(context);
    if (position == null) return;

    final built = itemBuilder(context);
    if (built.isEmpty) return;
    final items = dividers ? _withHairlines(built) : built;

    onOpened?.call();

    final s = context.sketch;
    final selected = await showMenu<T>(
      context: context,
      position: position,
      items: items,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SketchRadius.card),
            side: BorderSide(color: s.outline, width: SketchStroke.outline),
          ),
      color: color ?? s.surface,
      elevation: elevation ?? 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: SketchMotion.enabled(context)
          ? null
          : AnimationStyle.noAnimation,
    );

    if (selected == null) {
      onCanceled?.call();
    } else {
      onSelected?.call(selected);
    }
  }

  /// A hairline between two adjacent rows; existing dividers are kept and
  /// never doubled.
  static List<PopupMenuEntry<T>> _withHairlines<T>(
      List<PopupMenuEntry<T>> entries) {
    final out = <PopupMenuEntry<T>>[];
    for (final e in entries) {
      final prevIsRow = out.isNotEmpty && out.last is! PopupMenuDivider;
      if (prevIsRow && e is! PopupMenuDivider) {
        out.add(const PopupMenuDivider(height: SketchStroke.outline));
      }
      out.add(e);
    }
    return out;
  }

  /// The button's rect in overlay space, or null if it cannot be measured.
  ///
  /// Mirrors `PopupMenuButton`'s own arithmetic, plus the `hasSize` checks the
  /// framework omits. Wrapped in a try/catch because a menu failing to open is
  /// always preferable to a fatal error during layout — the exact failure this
  /// class exists to prevent.
  RelativeRect? _anchorOf(BuildContext context) {
    try {
      final button = context.findRenderObject() as RenderBox?;
      final overlay =
          Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;

      if (button == null ||
          overlay == null ||
          !button.attached ||
          !overlay.attached ||
          !button.hasSize ||
          !overlay.hasSize) {
        CrashBreadcrumbs.log('popup menu skipped: anchor not measurable');
        return null;
      }

      return RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(offset, ancestor: overlay),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero) + offset,
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      );
    } catch (e) {
      CrashBreadcrumbs.log('popup menu anchor failed: $e');
      return null;
    }
  }
}
