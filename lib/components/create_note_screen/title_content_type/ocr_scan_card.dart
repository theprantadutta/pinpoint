import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../../design_system/design_system.dart';

/// The scan card in the text editor: the picked image in an r16 outline
/// card, diagonal placeholder stripes while it decodes, a muted caption and
/// the sky "Extract text" pill.
///
/// The image is only a staging area for OCR — it is never attached to the
/// note (the editor has no attachment storage), which the caption says.
class OcrScanCard extends StatelessWidget {
  const OcrScanCard({
    super.key,
    required this.imagePath,
    required this.pillLabel,
    required this.onExtract,
    required this.onDiscard,
    this.busy = false,
  });

  final String imagePath;

  /// "Extract text", "Extract text · 18/20" near the free limit, or
  /// "Reading…" while busy.
  final String pillLabel;
  final VoidCallback? onExtract;
  final VoidCallback onDiscard;
  final bool busy;

  static const double height = 150;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.outline, width: SketchStroke.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const StripedPlaceholder(),
          LayoutBuilder(
            builder: (context, c) => Semantics(
              image: true,
              label: l10n.edOcrImage,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                // Decode at display size: a full-resolution photo here is
                // exactly the kind of decode that caused OOM crashes.
                cacheWidth: (c.maxWidth * dpr).round(),
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
                  opacity: sync || frame != null ? 1 : 0,
                  duration: SketchMotion.of(context, SketchMotion.base),
                  child: child,
                ),
              ),
            ),
          ),
          if (busy) const StripedPlaceholder(opacity: 0.55),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: CircleIconButton(
              icon: Icons.close_rounded,
              size: 32,
              iconSize: 16,
              fill: s.surface,
              semanticLabel: l10n.edOcrDiscard,
              onPressed: busy ? null : onDiscard,
            ),
          ),
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 10,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.edOcrCaption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(fontSize: 11, color: s.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ExtractPill(
                  label: pillLabel,
                  busy: busy,
                  onTap: busy ? null : onExtract,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtractPill extends StatelessWidget {
  const _ExtractPill({required this.label, required this.busy, this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return SketchPressable(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SketchSpace.minTap),
        child: Align(
          alignment: AlignmentDirectional.bottomEnd,
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SketchPastels.sky,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: SketchPastels.onPastel, width: SketchStroke.pastel),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: SketchPastels.onPastel,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: t.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SketchPastels.onPastel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diagonal soft stripes (135°, 8px on / 8px off): the Sketchbook loading
/// placeholder for images.
class StripedPlaceholder extends StatelessWidget {
  const StripedPlaceholder({super.key, this.opacity = 1});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _StripesPainter(
            color: context.sketch.soft.withValues(alpha: opacity)),
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  _StripesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8 / 1.4142
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Lines at 45° every 16px along the x axis.
    const step = 16.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripesPainter old) => old.color != color;
}
