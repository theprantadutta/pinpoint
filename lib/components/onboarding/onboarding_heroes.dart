import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';

/// The sticker-and-doodle illustrations at the top of each onboarding page.
///
/// Each is laid out on a fixed 300×280 canvas and scaled to fit the hero
/// area — up as well as down — so the composition fills a tall phone or a
/// tablet instead of sitting at phone size in an empty field. All of it is
/// decorative: screen readers get the page headline.
class _HeroCanvas extends StatelessWidget {
  const _HeroCanvas({required this.children});

  static const Size size = Size(300, 280);

  /// Upper bound on the scale. It used to be an accidental 1.0: the canvas sat
  /// in a FittedBox under a Center, and Center hands down loose constraints, so
  /// BoxFit.contain only ever shrank it. The art was therefore 300pt wide on
  /// every device, which read as lost on a 13-inch iPad and left the space
  /// above the headline to grow with screen height on tall phones. Capped so a
  /// very large window does not blow the stickers up past the copy.
  static const double maxScale = 2.2;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = [
              box.maxWidth / size.width,
              box.maxHeight / size.height,
              maxScale,
            ].reduce((a, b) => a < b ? a : b);
            // heightFactor 1: take the art's own height rather than the whole
            // region, so the page can centre the art and the copy as one
            // group instead of the art floating in all the leftover space.
            return Center(
              heightFactor: 1,
              child: SizedBox(
                width: size.width * scale,
                height: size.height * scale,
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: size,
                    child: Stack(clipBehavior: Clip.none, children: children),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A soft placeholder line, as on a sketched note.
class _Stripe extends StatelessWidget {
  const _Stripe({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: context.sketch.soft,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Page 1 — "Write it down": a tilted mini note card ringed by a yellow ★,
/// mint ✓, sky mic and lavender clock sticker.
class WriteItDownHero extends StatelessWidget {
  const WriteItDownHero({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    Widget row(bool checked, double width) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              SketchCheckbox.mini(checked: checked),
              const SizedBox(width: 8),
              _Stripe(width: width),
            ],
          ),
        );

    final card = Container(
      width: 176,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(SketchRadius.card),
        border: Border.all(color: s.outline, width: SketchStroke.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.obSampleNoteGroceries,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cardTitle),
          row(true, 96),
          row(true, 70),
          row(false, 110),
          row(false, 84),
        ],
      ),
    );

    return _HeroCanvas(children: [
      Center(child: Transform.rotate(angle: -0.09, child: card)),
      const PositionedDirectional(
        top: 14,
        start: 16,
        child: StickerTile(
            color: SketchPastels.yellow,
            size: 62,
            angle: -10,
            icon: Icons.star_rounded),
      ),
      const PositionedDirectional(
        top: 4,
        end: 22,
        child: StickerTile(
            color: SketchPastels.mint,
            size: 52,
            angle: 9,
            icon: Icons.check_rounded),
      ),
      const PositionedDirectional(
        bottom: 12,
        start: 8,
        child: StickerTile(
            color: SketchPastels.sky,
            size: 56,
            angle: 7,
            icon: Icons.mic_rounded),
      ),
      const PositionedDirectional(
        bottom: 4,
        end: 12,
        child: StickerTile(
            color: SketchPastels.lavender,
            size: 60,
            angle: -8,
            icon: Icons.schedule_rounded),
      ),
    ]);
  }
}

/// Page 2 — "Organized": the stacked folder, with yellow, lavender and mint
/// sheets peeking out of it, and a pin sticker.
class OrganizedHero extends StatelessWidget {
  const OrganizedHero({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final folder = SizedBox(
      width: 268,
      height: 214,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The third (mint) sheet, furthest back.
          PositionedDirectional(
            top: 34,
            start: 96,
            end: 2,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                color: SketchPastels.mint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: SketchPastels.onPastel, width: SketchStroke.pastel),
              ),
            ),
          ),
          Positioned.fill(
            top: 44,
            child: FolderPreviewCard(
              title: l10n.obSampleFolder,
              countLabel: l10n.folderNoteCount(4),
              backPastel: SketchPastels.yellow,
              frontPastel: SketchPastels.lavender,
              entries: [
                FolderPreviewEntry(
                    title: l10n.obSampleNoteGroceries,
                    color: SketchPastels.mint),
                FolderPreviewEntry(
                    title: l10n.obSampleNoteTrip, color: SketchPastels.sky),
                FolderPreviewEntry(
                    title: l10n.obSampleNoteBooks,
                    color: SketchPastels.lavender),
                FolderPreviewEntry(
                    title: l10n.obSampleNoteGifts, color: SketchPastels.yellow),
              ],
            ),
          ),
        ],
      ),
    );

    return _HeroCanvas(children: [
      Center(child: Transform.rotate(angle: -0.05, child: folder)),
      const PositionedDirectional(
        top: 8,
        start: 4,
        child: StickerTile(
            color: SketchPastels.pink,
            size: 54,
            angle: -11,
            icon: Icons.push_pin_rounded),
      ),
    ]);
  }
}

/// Page 3 — "Private": a big lavender lock sticker with the pin sticker.
class PrivateHero extends StatelessWidget {
  const PrivateHero({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HeroCanvas(children: [
      Center(
        child: StickerTile(
          color: SketchPastels.lavender,
          size: 132,
          angle: -6,
          shadowOffset: 4,
          icon: Icons.lock_rounded,
        ),
      ),
      PositionedDirectional(
        top: 30,
        end: 44,
        child: BrandSticker(size: 66, angle: 10, shadow: true),
      ),
      PositionedDirectional(
        bottom: 34,
        start: 46,
        child: StickerTile(
            color: SketchPastels.mint,
            size: 46,
            angle: -12,
            icon: Icons.check_rounded),
      ),
    ]);
  }
}
