import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../design_system/design_system.dart';

/// A walkthrough coach-mark tooltip in the Sketchbook style: an outlined
/// surface card with a tilted sticker, a title, a line of copy and an inverse
/// Next pill.
class WalkthroughTooltip extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onNext;
  final bool showNextButton;

  /// Null means "use the default label", resolved at build time — a default
  /// parameter value cannot read Localizations.
  final String? nextButtonText;

  const WalkthroughTooltip({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.onNext,
    this.showNextButton = true,
    this.nextButtonText,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(SketchRadius.group),
        border: Border.all(color: s.outline, width: SketchStroke.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StickerTile(color: s.highlight, size: 40, angle: -8, icon: icon),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: t.cardTitleLarge)),
            ],
          ),
          const SizedBox(height: 12),
          Text(description,
              style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted)),
          if (showNextButton) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PillButton(
                label: nextButtonText ?? AppL10n.of(context).commonNext,
                onPressed: onNext,
                expand: false,
                height: 44,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
