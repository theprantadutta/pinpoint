import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service_locators/init_service_locators.dart';
import 'analytics/analytics_facade.dart';
import 'drift_note_service.dart';

/// Service for the native in-app review prompt (Google Play / App Store).
///
/// Follows the platform guidance for `in_app_review`:
/// - `requestReview()` is quota-limited by the OS (it may show nothing). It
///   must follow real use and never come from a button, and is never preceded
///   by a "do you like it?" question (store policy).
/// - `openStoreListing()` has no quota and is the right call for an explicit
///   "Rate this app" button.
///
/// **When.** Only at a success moment: the home shell calls
/// [maybeRequestReview] right after the person has saved a new note and is
/// back from the editor, never on a cold start. And only for someone who has
/// clearly found a use for the app: at least [minNotes] notes, at least
/// [minAge] since first use, and not within [cooldown] of the last request.
class AppReviewService {
  static final AppReviewService _instance = AppReviewService._internal();
  factory AppReviewService() => _instance;
  AppReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  // Tuning knobs for the automatic prompt.
  static const int minNotes = 5;
  static const Duration minAge = Duration(days: 3);
  static const Duration cooldown = Duration(days: 90);

  // SharedPreferences keys.
  @visibleForTesting
  static const String firstUseKey = 'review_first_use_ms';
  @visibleForTesting
  static const String lastPromptKey = 'review_last_prompt_ms';

  /// Pinpoint's iOS App Store ID (apps.apple.com/app/id6786222392). Only
  /// needed for `openStoreListing` on iOS/macOS; Android ignores it.
  static const String _appStoreId = '6786222392';

  /// Pure: whether to ask the OS for the review prompt.
  static bool shouldRequestReview({
    required int noteCount,
    required DateTime firstUse,
    required DateTime? lastPrompt,
    required DateTime now,
  }) {
    if (noteCount < minNotes) return false;
    if (now.difference(firstUse) < minAge) return false;
    if (lastPrompt != null && now.difference(lastPrompt) < cooldown) {
      return false;
    }
    return true;
  }

  /// Coarse note count for analytics: '5-9' | '10-24' | '25+'.
  static String notesBucket(int noteCount) => noteCount >= 25
      ? '25+'
      : noteCount >= 10
          ? '10-24'
          : '5-9';

  /// Stores the first-use time if there is none yet, and returns it. Runs on
  /// every home start; people who used the app before this existed get
  /// "now", so they too wait [minAge] from here.
  static Future<DateTime> recordFirstUse(SharedPreferences prefs,
      {DateTime? now}) async {
    final ms = prefs.getInt(firstUseKey);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    final at = now ?? DateTime.now();
    await prefs.setInt(firstUseKey, at.millisecondsSinceEpoch);
    return at;
  }

  /// The note count if the prompt is due, else null. Counts notes only when
  /// the time gates already pass.
  @visibleForTesting
  static Future<int?> dueNoteCount(
    SharedPreferences prefs, {
    required Future<int> Function() countNotes,
    required DateTime now,
  }) async {
    final firstUse = await recordFirstUse(prefs, now: now);
    final lastMs = prefs.getInt(lastPromptKey);
    final lastPrompt =
        lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
    bool due(int n) => shouldRequestReview(
        noteCount: n, firstUse: firstUse, lastPrompt: lastPrompt, now: now);
    if (!due(minNotes)) return null;
    final count = await countNotes();
    return due(count) ? count : null;
  }

  /// Call at a success moment (a new note saved, back on home). Cheap and
  /// self-gating; the OS still decides whether anything shows.
  Future<void> maybeRequestReview() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      await requestIfDue(
        await SharedPreferences.getInstance(),
        now: DateTime.now(),
        countNotes: DriftNoteService.countNotes,
        isAvailable: _inAppReview.isAvailable,
        requestReview: _inAppReview.requestReview,
        analytics: getIt<AnalyticsFacade>(),
      );
    } catch (e) {
      debugPrint('❌ [AppReviewService] requestReview failed: $e');
      // Never block the app for a review prompt.
    }
  }

  /// The body of [maybeRequestReview], with the platform calls passed in.
  /// Returns whether the OS was asked.
  @visibleForTesting
  static Future<bool> requestIfDue(
    SharedPreferences prefs, {
    required DateTime now,
    required Future<int> Function() countNotes,
    required Future<bool> Function() isAvailable,
    required Future<void> Function() requestReview,
    required AnalyticsFacade analytics,
  }) async {
    final count = await dueNoteCount(prefs, countNotes: countNotes, now: now);
    if (count == null) return false;

    if (!await isAvailable()) {
      debugPrint('⭐ [AppReviewService] Review not available on this device');
      return false;
    }

    debugPrint('⭐ [AppReviewService] Requesting in-app review');
    analytics.trackReviewPromptRequested(notesBucket: notesBucket(count));
    await requestReview();
    // The OS decides whether the dialog actually showed; record the attempt
    // either way so we respect the cooldown and don't pester the user.
    await prefs.setInt(lastPromptKey, now.millisecondsSinceEpoch);
    return true;
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
