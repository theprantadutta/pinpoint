import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../colors.dart';
import '../typography.dart';
import 'sketch/pill_button.dart';
import 'sketch/sketch_sheet.dart';
import 'sketch/sticker_tile.dart';

/// The Sketchbook confirm sheet: an optional sticker, a 22/800 title, a body
/// line, the confirming action (an outline pill — error text when
/// destructive) and an inverse Cancel.
class ConfirmSheet extends StatelessWidget {
  final String title;
  final String? message;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool isDestructive;
  final IconData? icon;

  /// Ignored — Sketchbook has no gradients. Kept for call-site compatibility.
  final Gradient? headerGradient;

  const ConfirmSheet({
    super.key,
    required this.title,
    this.message,
    this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
    this.isDestructive = false,
    this.icon,
    this.headerGradient,
  });

  /// Show the confirm sheet. Resolves to true when confirmed.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String? message,
    String? primaryLabel,
    String? secondaryLabel,
    bool isDestructive = false,
    IconData? icon,
    Gradient? headerGradient,
  }) {
    return showSketchSheet<bool>(
      context: context,
      builder: (ctx) => ConfirmSheet(
        title: title,
        message: message,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        isDestructive: isDestructive,
        icon: icon,
        onPrimary: () => Navigator.of(ctx).pop(true),
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    return SketchSheet(
      scrollable: false,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            StickerTile(
              color: isDestructive ? SketchPastels.pink : s.highlight,
              size: 52,
              angle: -6,
              icon: icon,
            ),
            const SizedBox(height: 16),
          ],
          Semantics(header: true, child: Text(title, style: t.emptyTitle)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!,
                style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted)),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillButton(
            label: primaryLabel ??
                (isDestructive ? l10n.commonDelete : l10n.dsConfirm),
            variant: isDestructive
                ? PillButtonVariant.destructive
                : PillButtonVariant.primary,
            onPressed: onPrimary,
          ),
          const SizedBox(height: 10),
          PillButton(
            label: secondaryLabel ?? l10n.commonCancel,
            variant: isDestructive
                ? PillButtonVariant.primary
                : PillButtonVariant.secondary,
            onPressed: onSecondary,
          ),
        ],
      ),
    );
  }
}
