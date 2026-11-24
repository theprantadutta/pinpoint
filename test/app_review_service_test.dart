import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/app_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';
import 'support/project_source.dart';

/// The review prompt follows success: five notes, three days of use, a
/// 90-day cooldown, and it is asked for after a saved note, not on a start.
void main() {
  final now = DateTime(2026, 11, 24, 12);
  final longAgo = now.subtract(const Duration(days: 30));

  /// Review 2026-11-01, F11: "Rate Pinpoint" on iOS opens the App Store
  /// listing, which needs the app's id; it was an empty string.
  test('the App Store id is set', () {
    expect(readProjectFile('lib/services/app_review_service.dart'),
        contains("_appStoreId = '6786222392'"));
  });

  group('shouldRequestReview', () {
    bool decide({int notes = 5, DateTime? firstUse, DateTime? lastPrompt}) =>
        AppReviewService.shouldRequestReview(
            noteCount: notes,
            firstUse: firstUse ?? longAgo,
            lastPrompt: lastPrompt,
            now: now);

    test('needs five notes', () {
      expect(decide(notes: 4), isFalse);
      expect(decide(notes: 5), isTrue);
    });

    test('needs three days since first use', () {
      expect(decide(firstUse: now.subtract(const Duration(days: 2, hours: 23))),
          isFalse);
      expect(decide(firstUse: now.subtract(const Duration(days: 3))), isTrue);
    });

    test('keeps a 90-day cooldown', () {
      expect(decide(lastPrompt: now.subtract(const Duration(days: 89))),
          isFalse);
      expect(decide(lastPrompt: now.subtract(const Duration(days: 90))), isTrue);
    });
  });

  test('notes bucket is coarse', () {
    expect(AppReviewService.notesBucket(5), '5-9');
    expect(AppReviewService.notesBucket(9), '5-9');
    expect(AppReviewService.notesBucket(10), '10-24');
    expect(AppReviewService.notesBucket(24), '10-24');
    expect(AppReviewService.notesBucket(25), '25+');
    expect(AppReviewService.notesBucket(4000), '25+');
  });

  group('stored state', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('someone with no first-use time starts the three days now', () async {
      final prefs = await SharedPreferences.getInstance();
      var counted = false;
      final due = await AppReviewService.dueNoteCount(prefs,
          countNotes: () async {
            counted = true;
            return 50;
          },
          now: now);
      expect(due, isNull);
      expect(counted, isFalse, reason: 'no database read before the gate');
      expect(prefs.getInt(AppReviewService.firstUseKey),
          now.millisecondsSinceEpoch);

      expect(
          await AppReviewService.dueNoteCount(prefs,
              countNotes: () async => 50,
              now: now.add(const Duration(days: 3))),
          50);
    });

    test('the first-use time is never moved', () async {
      final prefs = await SharedPreferences.getInstance();
      await AppReviewService.recordFirstUse(prefs, now: longAgo);
      expect(await AppReviewService.recordFirstUse(prefs, now: now), longAgo);
    });

    test('four notes after a month: not yet', () async {
      SharedPreferences.setMockInitialValues(
          {AppReviewService.firstUseKey: longAgo.millisecondsSinceEpoch});
      final prefs = await SharedPreferences.getInstance();
      expect(
          await AppReviewService.dueNoteCount(prefs,
              countNotes: () async => 4, now: now),
          isNull);
    });
  });

  group('requestIfDue', () {
    test('asks the OS once, reports a coarse bucket, then cools down',
        () async {
      SharedPreferences.setMockInitialValues(
          {AppReviewService.firstUseKey: longAgo.millisecondsSinceEpoch});
      final prefs = await SharedPreferences.getInstance();
      final a = RecordingAnalyticsFacade();
      var requests = 0;
      Future<bool> run(DateTime at) => AppReviewService.requestIfDue(prefs,
          now: at,
          countNotes: () async => 12,
          isAvailable: () async => true,
          requestReview: () async => requests++,
          analytics: a);

      expect(await run(now), isTrue);
      expect(await run(now.add(const Duration(days: 30))), isFalse);
      expect(requests, 1);
      expect(a.one('review_prompt_requested').params, {'notes_bucket': '10-24'});
    });

    test('nothing is reported when the gate fails', () async {
      SharedPreferences.setMockInitialValues({});
      final a = RecordingAnalyticsFacade();
      final asked = await AppReviewService.requestIfDue(
          await SharedPreferences.getInstance(),
          now: now,
          countNotes: () async => 40,
          isAvailable: () async => true,
          requestReview: () async {},
          analytics: a);
      expect(asked, isFalse, reason: 'first use is today');
      expect(a.events, isEmpty);
    });
  });

  test('asked after a saved note, not on a cold start', () {
    expect(readProjectFile('lib/screens/home_screen.dart'),
        isNot(contains('maybeRequestReview')));
    expect(
        readProjectFile(
            'lib/navigation/bottom-navigation/bottom_navigation_layout.dart'),
        contains('AppReviewService().maybeRequestReview()'));
  });
}
