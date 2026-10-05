import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
import '../walkthrough/walkthrough_config.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Service responsible for managing the app walkthrough/tutorial.
/// Uses singleton pattern consistent with other services in the app.
class WalkthroughService {
  static final WalkthroughService _instance = WalkthroughService._internal();
  factory WalkthroughService() => _instance;
  WalkthroughService._internal();

  TutorialCoachMark? _tutorialCoachMark;
  bool _isShowing = false;

  /// Check if walkthrough has been completed
  Future<bool> hasCompletedWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kHasCompletedWalkthroughKey) ?? false;
  }

  /// Mark walkthrough as completed
  Future<void> markWalkthroughCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasCompletedWalkthroughKey, true);
    debugPrint('[Walkthrough] Marked as completed');
  }

  /// Reset walkthrough (for "Replay Tutorial" feature)
  Future<void> resetWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasCompletedWalkthroughKey, false);
    debugPrint('[Walkthrough] Reset - will show on next trigger');
  }

  /// Show walkthrough if not completed and all keys are mounted.
  /// Call this from the main navigation after widgets are rendered.
  Future<void> showWalkthroughIfNeeded(BuildContext context) async {
    if (_isShowing) {
      debugPrint('[Walkthrough] Already showing, skipping');
      return;
    }

    final hasCompleted = await hasCompletedWalkthrough();
    if (hasCompleted) {
      debugPrint('[Walkthrough] Already completed, skipping');
      return;
    }

    // Mark as completed FIRST to ensure persistence even if app closes
    await markWalkthroughCompleted();

    // Delay to ensure all widgets are rendered and mounted
    await Future.delayed(const Duration(milliseconds: 800));

    if (!context.mounted) {
      debugPrint('[Walkthrough] Context not mounted, skipping');
      return;
    }

    showWalkthrough(context);
  }

  /// Force show walkthrough (for replay from settings).
  /// This ignores the completion status.
  void showWalkthrough(BuildContext context) {
    if (_isShowing) {
      debugPrint('[Walkthrough] Already showing, cannot start another');
      return;
    }

    final targets = WalkthroughConfig.createTargets(context);

    // Filter out targets whose keys are not mounted
    final validTargets = targets.where((t) {
      final isValid = t.keyTarget?.currentContext != null;
      if (!isValid) {
        debugPrint('[Walkthrough] Target ${t.identify} not mounted, skipping');
      }
      return isValid;
    }).toList();

    if (validTargets.isEmpty) {
      debugPrint('[Walkthrough] No valid targets found, cannot show');
      return;
    }

    debugPrint(
        '[Walkthrough] Starting with ${validTargets.length} targets: ${validTargets.map((t) => t.identify).join(", ")}');

    _isShowing = true;

    final sketch = context.sketch;
    final skipLabel = AppL10n.of(context).obSkip;

    _tutorialCoachMark = TutorialCoachMark(
      targets: validTargets,
      colorShadow: SketchPastels.onPastel,
      opacityShadow: 0.82,
      hideSkip: false,
      textSkip: skipLabel,
      // Sketchbook: an inverse stadium, no gradient or glow.
      skipWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: ShapeDecoration(
          color: sketch.surface,
          shape: StadiumBorder(
            side: BorderSide(color: sketch.outline, width: SketchStroke.outline),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, color: sketch.ink, size: 18),
            const SizedBox(width: 6),
            Text(skipLabel, style: context.type.chip.copyWith(fontSize: 14)),
          ],
        ),
      ),
      paddingFocus: 10,
      focusAnimationDuration: const Duration(milliseconds: 300),
      pulseAnimationDuration: const Duration(milliseconds: 500),
      onFinish: () {
        _isShowing = false;
        markWalkthroughCompleted();
        debugPrint('[Walkthrough] Finished - all steps completed');
      },
      onSkip: () {
        _isShowing = false;
        markWalkthroughCompleted();
        debugPrint('[Walkthrough] Skipped by user');
        return true; // Return true to allow skip
      },
      onClickTarget: (target) {
        debugPrint('[Walkthrough] User clicked target: ${target.identify}');
      },
      onClickOverlay: (target) {
        debugPrint('[Walkthrough] User clicked overlay at: ${target.identify}');
      },
    );

    _tutorialCoachMark!.show(context: context);
  }

  /// Dismiss walkthrough if showing
  void dismiss() {
    if (_isShowing && _tutorialCoachMark != null) {
      _tutorialCoachMark!.finish();
      _isShowing = false;
      debugPrint('[Walkthrough] Dismissed programmatically');
    }
  }

  /// Check if walkthrough is currently showing
  bool get isShowing => _isShowing;
}
