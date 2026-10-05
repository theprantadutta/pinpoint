import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../animations.dart';
import '../../colors.dart';
import '../../elevations.dart';
import '../../spacing.dart';
import 'sketch_card.dart';

/// A tilted pastel sticker: rounded square, ink outline, hard offset shadow,
/// with a centred glyph or short label (★, ✓, ∞, Aa, OCR).
///
/// Pressed, the shadow collapses and the tile shifts by the offset, as if
/// pushed down onto the page. Decorative unless [semanticLabel] is given.
class StickerTile extends StatefulWidget {
  const StickerTile({
    super.key,
    required this.color,
    this.size = 56,
    this.height,
    this.angle = 0,
    this.glyph,
    this.icon,
    this.child,
    this.shadowOffset = 3,
    this.onTap,
    this.semanticLabel,
    this.radiusFactor = 0.27,
    this.glyphStyle,
  });

  final Color color;
  final double size;

  /// Height when the sticker is not square (the "Aa" and "OCR" tiles).
  final double? height;

  /// Rotation in degrees (−12…+12 in the system).
  final double angle;
  final String? glyph;
  final IconData? icon;
  final Widget? child;
  final double shadowOffset;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double radiusFactor;
  final TextStyle? glyphStyle;

  @override
  State<StickerTile> createState() => _StickerTileState();
}

class _StickerTileState extends State<StickerTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = widget.height ?? widget.size;
    final side = math.min(w, h);
    final radius = (side * widget.radiusFactor).clamp(8.0, 30.0);
    final off = _down ? 0.0 : widget.shadowOffset;
    final dur = SketchMotion.of(context, SketchMotion.fast);

    final content = widget.child ??
        (widget.icon != null
            ? Icon(widget.icon,
                size: side * 0.42, color: SketchPastels.onPastel)
            : Text(
                widget.glyph ?? '',
                maxLines: 1,
                style: (widget.glyphStyle ??
                        TextStyle(
                          fontSize: side * 0.38,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ))
                    .copyWith(color: SketchPastels.onPastel),
              ));

    Widget tile = AnimatedContainer(
      duration: dur,
      width: w,
      height: h,
      transform: Matrix4.translationValues(
          widget.shadowOffset - off, widget.shadowOffset - off, 0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: SketchPastels.onPastel,
          width: side > 80 ? 2 : SketchStroke.outline,
        ),
        boxShadow: off == 0 ? const [] : SketchShadows.sticker(off),
      ),
      alignment: Alignment.center,
      child: OnPastel(child: content),
    );

    tile = Transform.rotate(angle: widget.angle * math.pi / 180, child: tile);

    if (widget.onTap != null) {
      tile = GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: tile,
      );
    }

    return widget.semanticLabel == null
        ? ExcludeSemantics(child: tile)
        : Semantics(
            label: widget.semanticLabel,
            button: widget.onTap != null,
            child: ExcludeSemantics(child: tile),
          );
  }
}

/// The brand mark: a yellow rounded square (r12), 1.5px ink outline, rotated
/// −7°, with the ink pin centred. 40px in the header, larger on splash.
///
/// [statusDot] adds the optional 8px sync dot (mint synced, yellow syncing,
/// pink error).
class BrandSticker extends StatelessWidget {
  const BrandSticker({
    super.key,
    this.size = 40,
    this.color,
    this.statusDot,
    this.angle = -7,
    this.shadow = false,
  });

  final double size;
  final Color? color;
  final Color? statusDot;
  final double angle;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? context.sketch.highlight;
    final r = size * 0.3;
    final tile = Transform.rotate(
      angle: angle * math.pi / 180,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(
            color: SketchPastels.onPastel,
            width: size >= 80 ? 2.5 : SketchStroke.outline,
          ),
          boxShadow: shadow ? SketchShadows.sticker(size / 28) : null,
        ),
        padding: EdgeInsets.all(size * 0.2),
        child: Image.asset(
          'assets/images/brand/pin-ink.png',
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
    if (statusDot == null) return tile;
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: tile),
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusDot,
                shape: BoxShape.circle,
                border: Border.all(
                    color: SketchPastels.onPastel, width: SketchStroke.pastel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pink initials avatar.
class SketchAvatar extends StatelessWidget {
  const SketchAvatar({
    super.key,
    required this.name,
    this.size = 46,
    this.color = SketchPastels.pink,
    this.imageUrl,
  });

  final String? name;
  final double size;
  final Color color;
  final String? imageUrl;

  static String initialsOf(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '·';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
            color: SketchPastels.onPastel, width: SketchStroke.outline),
        image: imageUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: imageUrl != null
          ? null
          : Text(
              initialsOf(name),
              style: TextStyle(
                fontSize: size * 0.33,
                fontWeight: FontWeight.w800,
                color: SketchPastels.onPastel,
                height: 1,
              ),
            ),
    );
  }
}

/// A cluster of 2–3 tilted stickers for empty states.
class StickerCluster extends StatelessWidget {
  const StickerCluster({super.key, required this.stickers, this.height = 120});

  /// Typically three [StickerTile]s; laid out left, centre (largest), right.
  final List<Widget> stickers;
  final double height;

  @override
  Widget build(BuildContext context) {
    final aligns = const [
      AlignmentDirectional(-0.75, 0.35),
      AlignmentDirectional(0, -0.2),
      AlignmentDirectional(0.75, 0.45),
    ];
    return SizedBox(
      height: height,
      width: height * 1.9,
      child: Stack(
        children: [
          for (var i = 0; i < stickers.length && i < 3; i++)
            Align(alignment: aligns[i], child: stickers[i]),
        ],
      ),
    );
  }
}
