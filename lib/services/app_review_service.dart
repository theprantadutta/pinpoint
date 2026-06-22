import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for the native in-app review prompt (Google Play / App Store).
///
/// Follows the platform guidance for `in_app_review`:
/// - `requestReview()` is quota-limited by the OS (it may show nothing). It
///   must be triggered after the user has used the app enough to give useful
///   feedback — never from a button. We gate it behind an engagement count +
///   a long cooldown so we ask at most occasionally, at a natural moment.
/// - `openStoreListing()` has no quota and is the right call for an explicit
///   "Rate this app" button.
class AppReviewService {
  static final AppReviewService _instance = AppReviewService._internal();
  factory AppReviewService() => _instance;
  AppReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  // Tuning knobs for the automatic prompt.
  static const int _minEngagementsBeforePrompt = 4;
  static const Duration _cooldown = Duration(days: 90);

  // SharedPreferences keys.
  static const String _kEngagementCount = 'review_engagement_count';
  static const String _kLastPromptMs = 'review_last_prompt_ms';

  /// iOS App Store ID (fill in once the app is on the App Store). Only needed
  /// for `openStoreListing` on iOS/macOS; Android ignores it.
  static const String _appStoreId = '';

  /// Record one engagement (e.g. a returning launch or a completed action) and,
  /// once the user has engaged enough and the cooldown has passed, ask the OS
  /// to maybe show the review prompt. Safe to call often; cheap and self-gating.
  Future<void> maybeRequestReview() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_kEngagementCount) ?? 0) + 1;
      await prefs.setInt(_kEngagementCount, count);

      if (count < _minEngagementsBeforePrompt) {
        debugPrint(
            '⭐ [AppReviewService] Engagement $count/$_minEngagementsBeforePrompt — not prompting yet');
        return;
      }

      final lastMs = prefs.getInt(_kLastPromptMs) ?? 0;
      if (lastMs > 0) {
        final since = DateTime.now().millisecondsSinceEpoch - lastMs;
        if (since < _cooldown.inMilliseconds) {
          debugPrint('⭐ [AppReviewService] Within cooldown — not prompting');
          return;
        }
      }

      if (!await _inAppReview.isAvailable()) {
        debugPrint('⭐ [AppReviewService] Review not available on this device');
        return;
      }

      debugPrint('⭐ [AppReviewService] Requesting in-app review');
      await _inAppReview.requestReview();
      // The OS decides whether the dialog actually showed; record the attempt
      // either way so we respect the cooldown and don't pester the user.
      await prefs.setInt(
          _kLastPromptMs, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('❌ [AppReviewService] requestReview failed: $e');
      // Never block the app for a review prompt.
    }
  }

  /// Open the store listing directly (no quota) — for an explicit
  /// "Rate this app" action in Settings.
  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(appStoreId: _appStoreId);
    } catch (e) {
      debugPrint('❌ [AppReviewService] openStoreListing failed: $e');
    }
  }
}
