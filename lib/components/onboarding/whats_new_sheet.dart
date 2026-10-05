import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/design_system.dart';
import '../../services/onboarding_version.dart';

/// The one-time "What's new" sheet for people who finished an older
/// onboarding: a sticker collage and three rows.
class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key});

  /// Shows the sheet if this install owes it (see [OnboardingVersion]) and
  /// waits for it to close. The seen version is recorded *before* showing,
  /// so it appears at most once even if the app is killed mid-sheet.
  ///
  /// Returns whether the sheet was shown.
  static Future<bool> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (OnboardingVersion.read(prefs) != OnboardingAction.whatsNew) {
      return false;
    }
    await OnboardingVersion.markSeen(prefs);
    if (!context.mounted) return false;
    await showSketchSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const WhatsNewSheet(),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    return SketchSheet(
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(child: _Collage()),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: HighlightedText(l10n.obWhatsNewTitle, style: t.sheetTitle),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.obWhatsNewBody,
            style: t.bodyRegular
                .copyWith(fontSize: 14, height: 1.5, color: s.muted),
          ),
        ],
      ),
      footer: PillButton(
        label: l10n.obWhatsNewCta,
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            color: s.highlight,
            icon: Icons.auto_awesome_rounded,
            title: l10n.obWhatsNewLookTitle,
            body: l10n.obWhatsNewLookBody,
          ),
          _Row(
            color: SketchPastels.lavender,
            icon: Icons.dark_mode_rounded,
            title: l10n.obWhatsNewDarkTitle,
            body: l10n.obWhatsNewDarkBody,
          ),
          _Row(
            color: SketchPastels.mint,
            icon: Icons.folder_rounded,
            title: l10n.obWhatsNewFoldersTitle,
            body: l10n.obWhatsNewFoldersBody,
          ),
        ],
      ),
    );
  }
}

/// Brand sticker plus a few tilted pastel stickers.
class _Collage extends StatelessWidget {
  const _Collage();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 96,
      width: 236,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 4,
            top: 10,
            child: BrandSticker(size: 74, shadow: true),
          ),
          PositionedDirectional(
            start: 96,
            top: 0,
            child: StickerTile(
                color: SketchPastels.lavender,
                size: 46,
                angle: 9,
                icon: Icons.star_rounded),
          ),
          PositionedDirectional(
            start: 104,
            top: 54,
            child: StickerTile(
                color: SketchPastels.pink, size: 38, angle: -10, glyph: 'Aa'),
          ),
          PositionedDirectional(
            start: 160,
            top: 18,
            child: StickerTile(
                color: SketchPastels.mint,
                size: 50,
                angle: -6,
                icon: Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}

/// A bullet row: a small pastel sticker with an icon, a 15/700 title and a
/// muted line.
class _Row extends StatelessWidget {
  const _Row({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StickerTile(color: color, size: 40, angle: -4, icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.cardTitle),
                  const SizedBox(height: 2),
                  Text(body, style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
