import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../../design_system/design_system.dart';
import '../../../util/localized_dates.dart';

/// The voice-note editor body, in three states:
///
/// - empty: a dashed card ("Tap the mic to record") plus the free-plan
///   length cap when one applies;
/// - recording: a pink card with the running time;
/// - recorded: a mint player card (play/pause, stop, a seekable waveform,
///   elapsed/total) and a "Record again" outline pill.
///
/// Purely presentational; the screen owns the recorder and player.
class VoiceNoteBody extends StatelessWidget {
  const VoiceNoteBody({
    super.key,
    required this.recording,
    required this.recorded,
    required this.hasAudio,
    required this.playing,
    required this.position,
    required this.total,
    required this.onRecord,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onReplace,
    required this.onSeek,
    this.freeCapSeconds,
    this.seed = 0,
  });

  final bool recording;
  final Duration recorded;
  final bool hasAudio;
  final bool playing;
  final Duration position;
  final Duration total;
  final VoidCallback onRecord;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onReplace;
  final ValueChanged<Duration> onSeek;

  /// The free plan's recording cap in seconds; null for premium.
  final int? freeCapSeconds;

  /// Seeds the decorative waveform so a note always draws the same shape.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final t = context.type;

    if (recording) {
      return SketchCard(
        pastel: SketchPastels.pink,
        radius: SketchRadius.group,
        padding: const EdgeInsets.all(SketchSpace.cardPadLg),
        semanticLabel: l10n.edRecording,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const StatusDot(color: SketchFunctional.error, size: 9),
                const SizedBox(width: 8),
                Text(l10n.edRecording,
                    style: t.chip.copyWith(color: SketchPastels.onPastel)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocalizedDates.duration(context, recorded.inSeconds),
              style: t.displayNumber.copyWith(
                color: SketchPastels.onPastel,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(l10n.edTapToStop,
                style: t.caption.copyWith(
                    color: SketchPastels.onPastel.withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    if (!hasAudio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SketchCard(
            dashed: true,
            color: Colors.transparent,
            radius: SketchRadius.group,
            onTap: onRecord,
            semanticLabel: l10n.edTapToStart,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  const StickerTile(
                    color: SketchPastels.sky,
                    size: 56,
                    angle: -6,
                    icon: Icons.mic_none_rounded,
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.edVoiceEmpty,
                      textAlign: TextAlign.center, style: t.cardTitle),
                ],
              ),
            ),
          ),
          if (freeCapSeconds != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.edVoiceFreeCap(
                  LocalizedDates.duration(context, freeCapSeconds!)),
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: s.muted),
            ),
          ],
        ],
      );
    }

    final totalMs = total.inMilliseconds;
    final fraction = totalMs <= 0
        ? 0.0
        : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SketchCard(
          pastel: SketchPastels.mint,
          radius: SketchRadius.group,
          padding: const EdgeInsets.all(SketchSpace.cardPadLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 48,
                    iconSize: 26,
                    fill: SketchPastels.onPastel,
                    iconColor: SketchPastels.mint,
                    semanticLabel:
                        playing ? l10n.edVoicePause : l10n.edVoicePlay,
                    onPressed: playing ? onPause : onPlay,
                  ),
                  const SizedBox(width: 6),
                  CircleIconButton(
                    icon: Icons.stop_rounded,
                    fill: SketchPastels.mint,
                    semanticLabel: l10n.edVoiceStop,
                    onPressed: onStop,
                  ),
                  const Spacer(),
                  Text(
                    '${LocalizedDates.duration(context, position.inSeconds)} / '
                    '${LocalizedDates.duration(context, total.inSeconds)}',
                    style: t.chip.copyWith(
                      color: SketchPastels.onPastel,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Waveform(
                fraction: fraction,
                seed: seed,
                semanticLabel: l10n.edVoicePosition,
                onSeek: (f) => onSeek(Duration(
                    milliseconds: (f * (totalMs <= 0 ? 0 : totalMs)).round())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PillButton.secondary(
          label: l10n.edRecordAgain,
          icon: Icons.refresh_rounded,
          onPressed: onReplace,
        ),
      ],
    );
  }
}

/// 3px bars: the played part in ink, the rest at 35% ink. Tap or drag to
/// seek. The shape is decorative (no amplitude data is stored), seeded per
/// note so it is stable.
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.fraction,
    required this.seed,
    required this.onSeek,
    required this.semanticLabel,
  });

  final double fraction;
  final int seed;
  final ValueChanged<double> onSeek;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, c) {
        double toFraction(Offset local) {
          final f = (local.dx / c.maxWidth).clamp(0.0, 1.0);
          return rtl ? 1 - f : f;
        }

        return Semantics(
          label: semanticLabel,
          value: '${(fraction * 100).round()}%',
          slider: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => onSeek(toFraction(d.localPosition)),
            onHorizontalDragUpdate: (d) => onSeek(toFraction(d.localPosition)),
            child: SizedBox(
              height: 44,
              width: c.maxWidth,
              child: CustomPaint(
                painter: _WavePainter(
                  fraction: fraction,
                  seed: seed,
                  rtl: rtl,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.fraction, required this.seed, required this.rtl});

  final double fraction;
  final int seed;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 3.0, gap = 3.0;
    final count = (size.width / (bar + gap)).floor();
    final rnd = math.Random(seed);
    final played = Paint()..color = SketchPastels.onPastel;
    final rest = Paint()
      ..color = SketchPastels.onPastel.withValues(alpha: 0.35);
    for (var i = 0; i < count; i++) {
      final h = size.height * (0.25 + 0.75 * rnd.nextDouble());
      final x =
          rtl ? size.width - (i + 1) * (bar + gap) + gap : i * (bar + gap);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - h) / 2, bar, h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(r, (i + 0.5) / count <= fraction ? played : rest);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.fraction != fraction || old.seed != seed || old.rtl != rtl;
}
