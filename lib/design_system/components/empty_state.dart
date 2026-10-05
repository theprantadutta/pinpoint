import 'package:flutter/material.dart';

import '../animations.dart';
import '../colors.dart';
import '../typography.dart';
import 'sketch/pill_button.dart';
import 'sketch/sticker_tile.dart';

/// The Sketchbook empty state: a cluster of tilted pastel stickers, a 22/800
/// title, a 14 muted line and at most one pill button.
///
/// [icon] is the glyph on the centre sticker; the side stickers are a star
/// and a check. Fades and rises in once (skipped under reduced motion).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Ignored — Sketchbook has no gradients. Kept for call-site compatibility.
  final Gradient? gradientHalo;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.gradientHalo,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StickerCluster(
            stickers: [
              const StickerTile(
                  color: SketchPastels.lavender, size: 44, angle: -12, icon: Icons.star_rounded),
              StickerTile(
                  color: s.highlight, size: 76, angle: -6, icon: icon),
              const StickerTile(
                  color: SketchPastels.mint, size: 42, angle: 12, icon: Icons.check_rounded),
            ],
          ),
          const SizedBox(height: 22),
          Semantics(
            header: true,
            child: Text(title, style: t.emptyTitle, textAlign: TextAlign.center),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            PillButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );

    if (!SketchMotion.enabled(context)) return Center(child: content);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: SketchMotion.enter,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 8 * (1 - v)), child: child),
        ),
        child: content,
      ),
    );
  }
}
