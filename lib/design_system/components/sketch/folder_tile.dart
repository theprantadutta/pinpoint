import 'package:flutter/material.dart';

import '../../colors.dart';
import '../../spacing.dart';
import '../../typography.dart';
import 'sketch_card.dart';
import 'sketch_pressable.dart';

/// Paints a folder silhouette — a tab joined to a body — as one path, so the
/// tab and body share a single unbroken outline. Mirrors in RTL.
class _FolderShapePainter extends CustomPainter {
  _FolderShapePainter({
    required this.fill,
    required this.stroke,
    required this.tabWidth,
    required this.tabTop,
    required this.bodyTop,
    required this.tabRadius,
    required this.bodyRadius,
    required this.rtl,
  });

  final Color fill;
  final Color stroke;
  final double tabWidth;
  final double tabTop;
  final double bodyTop;
  final double tabRadius;
  final double bodyRadius;
  final bool rtl;

  Path _path(Size size, double inset) {
    final w = size.width - inset, h = size.height - inset;
    final l = inset, tt = tabTop + inset, bt = bodyTop + inset;
    final tw = tabWidth, rt = tabRadius, rb = bodyRadius;
    return Path()
      ..moveTo(l, tt + rt)
      ..arcToPoint(Offset(l + rt, tt), radius: Radius.circular(rt))
      ..lineTo(tw - rt, tt)
      ..arcToPoint(Offset(tw, tt + rt), radius: Radius.circular(rt))
      ..lineTo(tw, bt)
      ..lineTo(w - rb, bt)
      ..arcToPoint(Offset(w, bt + rb), radius: Radius.circular(rb))
      ..lineTo(w, h - rb)
      ..arcToPoint(Offset(w - rb, h), radius: Radius.circular(rb))
      ..lineTo(l + rb, h)
      ..arcToPoint(Offset(l, h - rb), radius: Radius.circular(rb))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final path = _path(size, SketchStroke.outline / 2);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = SketchStroke.outline
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FolderShapePainter o) =>
      o.fill != fill ||
      o.stroke != stroke ||
      o.tabWidth != tabWidth ||
      o.rtl != rtl ||
      o.bodyTop != bodyTop;
}

/// A pastel sheet peeking out of a folder.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: SketchPastels.onPastel, width: SketchStroke.outline),
      ),
    );
  }
}

/// The My-folders grid tile: a pastel sheet peeking above a folder with a
/// tab. Shows the title, a count line, an optional "⋯" menu and up to three
/// overlapping squares for the colours of the notes inside.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.pastel,
    this.noteColors = const [],
    this.onTap,
    this.onLongPress,
    this.menu,
    this.height = 150,
  });

  final String title;
  final String subtitle;
  final Color pastel;
  final List<Color> noteColors;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Usually a [PinpointPopupMenuButton] showing "⋯". Laid out in a 44px
  /// square at the top end of the body.
  final Widget? menu;
  final double height;

  static const double _bodyTop = 36;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return SketchPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: '$title, $subtitle',
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            PositionedDirectional(
              top: 0,
              start: 30,
              end: 10,
              height: 56,
              child: const SizedBox.expand().withSheet(pastel, 12),
            ),
            Positioned.fill(
              top: 12,
              child: CustomPaint(
                painter: _FolderShapePainter(
                  fill: s.surface,
                  stroke: s.outline,
                  tabWidth: 72,
                  tabTop: 0,
                  bodyTop: _bodyTop - 12,
                  tabRadius: 12,
                  bodyRadius: SketchRadius.folderBody,
                  rtl: rtl,
                ),
              ),
            ),
            Positioned.fill(
              top: _bodyTop,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.cardTitleLarge,
                            ),
                          ),
                        ),
                        // The menu itself sits on top of the tile (below),
                        // so its 44px target is not clipped by this row.
                        if (menu != null) const SizedBox(width: 30),
                      ],
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption,
                    ),
                    const Spacer(),
                    PastelStack(colors: noteColors),
                  ],
                ),
              ),
            ),
            if (menu != null)
              PositionedDirectional(
                top: _bodyTop + 2,
                end: 2,
                width: SketchSpace.minTap,
                height: SketchSpace.minTap,
                child: Center(child: menu),
              ),
          ],
        ),
      ),
    );
  }
}

/// The dashed "New folder" tile that ends the folders grid.
class NewFolderTile extends StatelessWidget {
  const NewFolderTile({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 138,
  });

  final String label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: height,
        child: SketchCard(
          dashed: true,
          color: Colors.transparent,
          radius: SketchRadius.folderBody,
          onTap: onTap,
          semanticLabel: label,
          padding: EdgeInsets.zero,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: ShapeDecoration(
                    shape: CircleBorder(
                      side: BorderSide(
                          color: s.outline, width: SketchStroke.outline),
                    ),
                  ),
                  child: Icon(Icons.add_rounded, size: 20, color: s.ink),
                ),
                const SizedBox(height: 8),
                Text(label, style: context.type.chip),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line inside the home folder preview: a pastel bullet and a title.
class FolderPreviewEntry {
  const FolderPreviewEntry({required this.title, required this.color});

  final String title;
  final Color color;
}

/// The larger home-screen folder preview: two pastel sheets (back and front),
/// a tab, and a body listing up to four notes in a 2×2 grid.
class FolderPreviewCard extends StatelessWidget {
  const FolderPreviewCard({
    super.key,
    required this.title,
    required this.countLabel,
    required this.entries,
    required this.backPastel,
    required this.frontPastel,
    this.onTap,
    this.emptyLabel,
    this.height = 164,
  });

  final String title;
  final String countLabel;
  final List<FolderPreviewEntry> entries;
  final Color backPastel;
  final Color frontPastel;
  final VoidCallback? onTap;

  /// Shown in place of the grid when [entries] is empty.
  final String? emptyLabel;
  final double height;

  static const double _bodyTop = 52;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final shown = entries.take(4).toList();

    Widget entry(FolderPreviewEntry e) => Row(
          children: [
            PastelSquare(color: e.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyRegular.copyWith(fontSize: 13, height: 1.3),
              ),
            ),
          ],
        );

    return SketchPressable(
      onTap: onTap,
      semanticLabel: '$title, $countLabel',
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            PositionedDirectional(
              top: 4,
              start: 70,
              end: 12,
              height: 60,
              child: const SizedBox.expand().withSheet(backPastel, 14),
            ),
            PositionedDirectional(
              top: 16,
              start: 46,
              end: 24,
              height: 60,
              child: const SizedBox.expand().withSheet(frontPastel, 14),
            ),
            Positioned.fill(
              top: 24,
              child: CustomPaint(
                painter: _FolderShapePainter(
                  fill: s.surface,
                  stroke: s.outline,
                  tabWidth: 108,
                  tabTop: 0,
                  bodyTop: _bodyTop - 24,
                  tabRadius: SketchRadius.folderTab,
                  bodyRadius: SketchRadius.card,
                  rtl: rtl,
                ),
              ),
            ),
            Positioned.fill(
              top: _bodyTop,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.cardTitleLarge),
                        ),
                        const SizedBox(width: 8),
                        Text(countLabel, style: t.caption),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (shown.isEmpty && emptyLabel != null)
                      Text(emptyLabel!, style: t.bodySmall)
                    else
                      Expanded(
                        child: Column(
                          children: [
                            for (var r = 0; r < 2; r++)
                              if (r * 2 < shown.length)
                                Padding(
                                  padding:
                                      EdgeInsets.only(bottom: r == 0 ? 9 : 0),
                                  child: Row(
                                    children: [
                                      Expanded(child: entry(shown[r * 2])),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: r * 2 + 1 < shown.length
                                            ? entry(shown[r * 2 + 1])
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget withSheet(Color color, double radius) =>
      _Sheet(color: color, radius: radius);
}
