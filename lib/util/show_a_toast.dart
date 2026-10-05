import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../design_system/colors.dart';
import '../design_system/spacing.dart';
import '../design_system/typography.dart';

/// Sketchbook toasts: an inverse stadium at the bottom (above the dock),
/// 14/600 on-inverse text, a leading 8px status dot, an optional yellow
/// action ("Undo"). 3 seconds.
///
/// The four helpers keep their old signatures so every call site picks up
/// the new look; [showSketchToast] is the general form.
enum ToastTone { success, warning, error, info }

Color _dotFor(ToastTone tone) => switch (tone) {
      ToastTone.success => SketchPastels.mint,
      ToastTone.warning => SketchPastels.yellow,
      ToastTone.error => SketchPastels.pink,
      ToastTone.info => SketchPastels.sky,
    };

ToastificationItem showSketchToast({
  required BuildContext context,
  required String message,
  String? description,
  ToastTone tone = ToastTone.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final s = context.sketch;
  final t = context.type;
  return toastification.showCustom(
    context: context,
    alignment: Alignment.bottomCenter,
    autoCloseDuration: duration,
    animationDuration: const Duration(milliseconds: 220),
    builder: (ctx, item) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              SketchSpace.screenX, 0, SketchSpace.screenX, 96),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 10, 10),
                  decoration: ShapeDecoration(
                    color: s.inverse,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _dotFor(tone),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.body
                                  .copyWith(fontSize: 14, color: s.onInverse),
                            ),
                            if (description != null && description.isNotEmpty)
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption.copyWith(
                                    color: s.onInverse.withValues(alpha: 0.7)),
                              ),
                          ],
                        ),
                      ),
                      if (actionLabel != null && onAction != null)
                        TextButton(
                          onPressed: () {
                            toastification.dismiss(item);
                            onAction();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: SketchPastels.yellow,
                            textStyle: t.body.copyWith(fontSize: 14),
                          ),
                          child: Text(actionLabel),
                        )
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void showSuccessToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    showSketchToast(
        context: context,
        message: title,
        description: description,
        tone: ToastTone.success);

void showWarningToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    showSketchToast(
        context: context,
        message: title,
        description: description,
        tone: ToastTone.warning);

void showErrorToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    showSketchToast(
        context: context,
        message: title,
        description: description,
        tone: ToastTone.error,
        duration: const Duration(seconds: 4));

void showInfoToast({
  required BuildContext context,
  required String title,
  required String description,
}) =>
    showSketchToast(
        context: context,
        message: title,
        description: description,
        tone: ToastTone.info);
