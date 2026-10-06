import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../services/logout_service.dart';

/// Covers the app while signing out, so the screen behind it never shows
/// notes being cleared away. Lists the three steps and where it is.
///
/// Opened with [SigningOutOverlay.show]; it cannot be dismissed by the user
/// and is closed by the caller once the sign-in screen is up.
class SigningOutOverlay extends StatelessWidget {
  const SigningOutOverlay({super.key, required this.phase});

  final ValueListenable<LogoutPhase> phase;

  /// Push the overlay on the root navigator. Returns a function that closes
  /// it; safe to call after navigation has already removed it.
  static VoidCallback show(BuildContext context, ValueListenable<LogoutPhase> phase) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = RawDialogRoute<void>(
      barrierDismissible: false,
      barrierColor: context.sketch.scrim,
      transitionDuration: SketchMotion.fast,
      pageBuilder: (_, __, ___) => SigningOutOverlay(phase: phase),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    navigator.push(route);
    return () {
      if (route.isActive) navigator.removeRoute(route);
    };
  }

  /// Which of the three steps a phase belongs to, 0–2; 3 once finished.
  static int stepOf(LogoutPhase phase) => switch (phase) {
        LogoutPhase.validating || LogoutPhase.syncing => 0,
        LogoutPhase.signingOut => 1,
        LogoutPhase.cleaningData => 2,
        LogoutPhase.completed => 3,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final s = context.sketch;
    final steps = [l10n.signOutStepSave, l10n.signOutStepAccount, l10n.signOutStepDevice];

    return PopScope(
      canPop: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: SketchCard(
                color: s.surface,
                radius: SketchRadius.group,
                padding: const EdgeInsets.all(SketchSpace.cardPadLg),
                child: ValueListenableBuilder<LogoutPhase>(
                  valueListenable: phase,
                  builder: (context, value, _) {
                    final current = stepOf(value);
                    return Semantics(
                      liveRegion: true,
                      label: current < steps.length ? steps[current] : l10n.signOutTitle,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const StickerTile(
                            color: SketchPastels.lavender,
                            size: 52,
                            angle: -6,
                            icon: Icons.logout_rounded,
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.signOutTitle, style: t.sheetTitle),
                          const SizedBox(height: 6),
                          Text(l10n.signOutBody,
                              style: t.bodySmall.copyWith(color: s.muted)),
                          const SizedBox(height: 20),
                          for (var i = 0; i < steps.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _StepRow(
                              label: steps[i],
                              state: i < current
                                  ? _StepState.done
                                  : i == current
                                      ? _StepState.active
                                      : _StepState.pending,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = context.sketch;
    const size = 22.0;

    final Widget marker = switch (state) {
      _StepState.done => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: SketchPastels.mint,
            shape: BoxShape.circle,
            border: Border.all(color: s.outline, width: 1.5),
          ),
          child: const Icon(Icons.check_rounded,
              size: 14, color: SketchPastels.onPastel),
        ),
      _StepState.active => SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2.2, color: s.ink),
          ),
        ),
      _StepState.pending => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: s.hairline, width: 1.5),
          ),
        ),
    };

    return Row(
      children: [
        marker,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: t.body.copyWith(
              color: state == _StepState.pending ? s.muted : s.ink,
            ),
          ),
        ),
      ],
    );
  }
}
