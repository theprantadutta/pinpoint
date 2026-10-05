import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../util/localized_dates.dart';

/// The editor's voice button: a 48px surface circle with an outline and a mic
/// (placed by the screen at bottom 104, end 22). While recording it turns
/// pink, pulses (unless the OS asks for reduced motion) and shows an inverse
/// timer chip beside it.
class VoiceFab extends StatefulWidget {
  const VoiceFab({
    super.key,
    required this.recording,
    required this.elapsed,
    required this.onPressed,
    required this.semanticLabel,
  });

  final bool recording;
  final Duration elapsed;
  final VoidCallback onPressed;
  final String semanticLabel;

  static const double size = 48;
  static const double bottom = 104;
  static const double end = 22;

  @override
  State<VoiceFab> createState() => _VoiceFabState();
}

class _VoiceFabState extends State<VoiceFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(VoiceFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final animate = widget.recording && SketchMotion.enabled(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final recording = widget.recording;

    final circle = SketchPressable(
      onTap: widget.onPressed,
      semanticLabel: widget.semanticLabel,
      haptic: true,
      child: SizedBox(
        width: VoiceFab.size + 20,
        height: VoiceFab.size + 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (recording)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final v = Curves.easeOut.transform(_pulse.value);
                  return Container(
                    width: VoiceFab.size * (1 + 0.38 * v),
                    height: VoiceFab.size * (1 + 0.38 * v),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          SketchPastels.pink.withValues(alpha: 0.55 * (1 - v)),
                    ),
                  );
                },
              ),
            AnimatedContainer(
              duration: SketchMotion.of(context, SketchMotion.base),
              curve: SketchMotion.enter,
              width: VoiceFab.size,
              height: VoiceFab.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recording ? SketchPastels.pink : s.surface,
                border: Border.all(
                  color: recording ? SketchPastels.onPastel : s.outline,
                  width: SketchStroke.outline,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                size: 22,
                color: recording ? SketchPastels.onPastel : s.ink,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: SketchMotion.of(context, SketchMotion.base),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SizeTransition(
              sizeFactor: a,
              axis: Axis.horizontal,
              alignment: AlignmentDirectional.centerEnd,
              child: child,
            ),
          ),
          child: recording
              ? Container(
                  key: const ValueKey('timer'),
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: ShapeDecoration(
                      color: s.inverse, shape: const StadiumBorder()),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SketchPastels.pink,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        LocalizedDates.duration(
                            context, widget.elapsed.inSeconds),
                        style: t.chip.copyWith(
                          color: s.onInverse,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('none')),
        ),
        circle,
      ],
    );
  }
}
