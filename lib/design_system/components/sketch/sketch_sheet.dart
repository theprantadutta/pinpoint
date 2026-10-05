import 'package:flutter/material.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'pill_button.dart';

/// Shows a Sketchbook bottom sheet: surface, top radius 34, 1.5px top
/// outline, a 40×5 handle, over the scrim. The route animates with the
/// sheet spring (ratio 0.85, stiffness 400).
Future<T?> showSketchSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  final s = context.sketch;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: s.scrim,
    elevation: 0,
    routeSettings: routeSettings,
    sheetAnimationStyle: AnimationStyle(
      duration: SketchMotion.of(context, const Duration(milliseconds: 320)),
      reverseDuration:
          SketchMotion.of(context, const Duration(milliseconds: 220)),
      curve: SketchMotion.enter,
      reverseCurve: SketchMotion.exit,
    ),
    builder: builder,
  );
}

/// The sheet body. Use as the root of a [showSketchSheet] builder.
///
/// Lays out handle, title row (26/800 plus an optional underlined action),
/// the [child], and an optional pinned [footer] (usually a [PillButton]).
/// Padding is 12/22/30 and follows the keyboard.
class SketchSheet extends StatelessWidget {
  const SketchSheet({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.action,
    this.footer,
    this.scrollable = true,
    this.maxHeightFactor = 0.9,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 30),
  });

  final Widget child;
  final String? title;

  /// Replaces [title] for a custom header (e.g. a sticker plus title).
  final Widget? titleWidget;

  /// Trailing header action, usually a [SketchTextAction] ("Reset").
  final Widget? action;
  final Widget? footer;
  final bool scrollable;
  final double maxHeightFactor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;

    final header = (title != null || titleWidget != null || action != null)
        ? Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: titleWidget ??
                      Semantics(
                        header: true,
                        child: Text(title ?? '', style: t.sheetTitle),
                      ),
                ),
                if (action != null) action!,
              ],
            ),
          )
        : const SizedBox(height: 14);

    final body = scrollable
        ? Flexible(child: SingleChildScrollView(child: child))
        : Flexible(child: child);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * maxHeightFactor,
        maxWidth: SketchSpace.maxContentWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: s.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SketchRadius.sheet)),
          border: Border(
            top: BorderSide(color: s.outline, width: SketchStroke.outline),
          ),
        ),
        child: Padding(
          padding: padding.copyWith(
              bottom: padding.bottom + bottomInset + mq.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: s.hairline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              header,
              body,
              if (footer != null) ...[const SizedBox(height: 18), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

/// The confirm-sheet pattern: title 22/800, a body line, a destructive
/// outline pill and an inverse Cancel. Returns true when confirmed.
Future<bool> showSketchConfirm({
  required BuildContext context,
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
  Widget? sticker,
}) async {
  final result = await showSketchSheet<bool>(
    context: context,
    builder: (ctx) => SketchSheet(
      scrollable: false,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sticker != null) ...[sticker, const SizedBox(height: 14)],
          Semantics(
            header: true,
            child: Text(title, style: ctx.type.emptyTitle),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message,
                style: ctx.type.bodyRegular
                    .copyWith(fontSize: 14, color: ctx.sketch.muted)),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillButton(
            label: confirmLabel,
            variant: destructive
                ? PillButtonVariant.destructive
                : PillButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: 10),
          PillButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
