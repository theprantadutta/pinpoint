import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pinpoint/components/shared/notification_prompt.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/services/note_saved_moment.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';
import 'support/project_source.dart';
import 'support/sketch_harness.dart';

/// The notification ask waits for success (a second note), can be put off
/// once for a week, and never stands between a reminder and its permission.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 24, 12);

  group('shouldAsk', () {
    test('not before the second note', () {
      for (final n in [0, 1]) {
        expect(
            NotificationPrompt.shouldAsk(
                asked: false, deferredAt: null, noteCount: n, now: now),
            isFalse);
      }
      expect(
          NotificationPrompt.shouldAsk(
              asked: false, deferredAt: null, noteCount: 2, now: now),
          isTrue);
    });

    test('never again once asked, however many notes', () {
      expect(
          NotificationPrompt.shouldAsk(
              asked: true, deferredAt: null, noteCount: 500, now: now),
          isFalse);
    });

    test('"not now" waits seven days before the one re-ask', () {
      final deferred = now.subtract(const Duration(days: 6, hours: 23));
      expect(
          NotificationPrompt.shouldAsk(
              asked: false, deferredAt: deferred, noteCount: 9, now: now),
          isFalse);
      expect(
          NotificationPrompt.shouldAsk(
              asked: false,
              deferredAt: now.subtract(const Duration(days: 7)),
              noteCount: 9,
              now: now),
          isTrue);
    });
  });

  group('stored state', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('someone the old version asked is never asked, and notes are not '
        'even counted', () async {
      SharedPreferences.setMockInitialValues(
          {'notification_permission_requested': true});
      final prefs = await SharedPreferences.getInstance();
      var counted = false;
      final due = await NotificationPrompt.isDue(prefs,
          countNotes: () async {
            counted = true;
            return 10;
          },
          now: now);
      expect(due, isFalse);
      expect(counted, isFalse);
    });

    test('a newcomer with one note is not asked; with two, is', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
          await NotificationPrompt.isDue(prefs,
              countNotes: () async => 1, now: now),
          isFalse);
      expect(
          await NotificationPrompt.isDue(prefs,
              countNotes: () async => 2, now: now),
          isTrue);
    });

    test('not now, a week, not now again: never asked a third time', () async {
      final prefs = await SharedPreferences.getInstance();
      Future<bool> due(DateTime at) => NotificationPrompt.isDue(prefs,
          countNotes: () async => 3, now: at);

      await NotificationPrompt.recordAnswer(prefs, enabled: false, now: now);
      expect(prefs.getBool(NotificationPrompt.askedKey), isNull);
      expect(await due(now.add(const Duration(days: 3))), isFalse);
      expect(await due(now.add(const Duration(days: 7))), isTrue);

      await NotificationPrompt.recordAnswer(prefs,
          enabled: false, now: now.add(const Duration(days: 7)));
      expect(prefs.getBool(NotificationPrompt.askedKey), isTrue);
      expect(await due(now.add(const Duration(days: 400))), isFalse);
    });

    test('turn on ends the asking whatever the system says', () async {
      final prefs = await SharedPreferences.getInstance();
      await NotificationPrompt.recordAnswer(prefs, enabled: true, now: now);
      expect(prefs.getBool(NotificationPrompt.askedKey), isTrue);
      expect(prefs.containsKey(NotificationPrompt.deferredAtKey), isFalse);
    });
  });

  group('the sheet', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<bool?> openFromButton(WidgetTester tester, RecordingAnalyticsFacade a,
        {required int notes,
        Future<bool> Function()? requestPermission,
        Future<void> Function(String, String)? scheduleNudge}) async {
      bool? shown;
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(sketchApp(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            shown = await NotificationPrompt.showIfNeeded(context,
                countNotes: () async => notes,
                analytics: a,
                requestPermission: requestPermission,
                scheduleNudge: scheduleNudge);
          },
          child: const Text('go'),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return shown;
    }

    testWidgets('is not shown with one note', (tester) async {
      final a = RecordingAnalyticsFacade();
      final shown = await openFromButton(tester, a, notes: 1);
      expect(shown, isFalse);
      expect(find.byType(NotificationPromptSheet), findsNothing);
      expect(a.events, isEmpty);
    });

    testWidgets('can be dismissed, which counts as "not now" and is reported '
        'as dismissed', (tester) async {
      final a = RecordingAnalyticsFacade();
      await openFromButton(tester, a, notes: 2);
      expect(find.byType(NotificationPromptSheet), findsOneWidget);
      expect(a.one('notification_prompt_shown').params,
          {'attempt': 'first', 'trigger': 'note_saved'});

      // A tap on the barrier above the sheet.
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationPromptSheet), findsNothing);
      expect(a.one('notification_permission_result').params,
          {'granted': 'false', 'outcome': 'dismissed'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(NotificationPrompt.deferredAtKey), isTrue);
      expect(prefs.getBool(NotificationPrompt.askedKey), isNull);
    });

    testWidgets('"Not now" is reported apart from a dismissal, and the re-ask '
        'is marked as one', (tester) async {
      SharedPreferences.setMockInitialValues({
        NotificationPrompt.deferredAtKey:
            DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
      });
      final a = RecordingAnalyticsFacade();
      await openFromButton(tester, a, notes: 4);
      expect(a.one('notification_prompt_shown').params['attempt'], 'reask');

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(a.one('notification_permission_result').params,
          {'granted': 'false', 'outcome': 'not_now'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationPrompt.askedKey), isTrue);
    });
  });

  testWidgets('turn on with the nudge: the system answer and the nudge are '
      'reported', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final a = RecordingAnalyticsFacade();
    var nudges = 0;
    bool? shown;
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(sketchApp(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          shown = await NotificationPrompt.showIfNeeded(context,
              countNotes: () async => 2,
              analytics: a,
              requestPermission: () async => true,
              scheduleNudge: (title, body) async => nudges++);
        },
        child: const Text('go'),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SketchToggle));
    await tester.pump();
    await tester.tap(find.text('Turn on notifications').last);
    await tester.pumpAndSettle();

    expect(shown, isTrue);
    expect(nudges, 1);
    expect(a.names, [
      'notification_prompt_shown',
      'nudge_scheduled',
      'notification_permission_result',
    ]);
    expect(a.one('nudge_scheduled').params, isEmpty);
    expect(a.one('notification_permission_result').params,
        {'granted': 'true', 'outcome': 'enabled'});
  });

  group('reminders', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('notifications off: the system is asked, the answer reported, and '
        'the sheet will not repeat the question', () async {
      final a = RecordingAnalyticsFacade();
      var asked = 0;
      final on = await NotificationPrompt.requestForReminder(
        areEnabled: () async => false,
        request: () async {
          asked++;
          return true;
        },
        analytics: a,
      );
      expect(on, isTrue);
      expect(asked, 1);
      expect(a.one('reminder_permission_requested').params,
          {'granted': 'true'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationPrompt.askedKey), isTrue);
    });

    test('notifications already on: nothing is asked or reported', () async {
      final a = RecordingAnalyticsFacade();
      var asked = 0;
      final on = await NotificationPrompt.requestForReminder(
        areEnabled: () async => true,
        request: () async {
          asked++;
          return true;
        },
        analytics: a,
      );
      expect(on, isTrue);
      expect(asked, 0);
      expect(a.events, isEmpty);
    });

    test('the reminder editor asks before the reminder is set', () {
      final source = readProjectFile(
          'lib/components/create_note_screen/reminder_type/reminder_type_content.dart');
      final ask = source.indexOf('NotificationPrompt.requestForReminder()');
      expect(ask, isNonNegative);
      expect(ask,
          lessThan(source.indexOf('widget.onReminderDateTimeChanged(selectedDateTime)')));
    });
  });

  group('wiring', () {
    test('the sheet is no longer an intro; it follows a saved note', () {
      final shell = readProjectFile(
          'lib/navigation/bottom-navigation/bottom_navigation_layout.dart');
      final intros = shell.substring(shell.indexOf('Future<void> _runIntros()'));
      expect(intros.substring(0, intros.indexOf('void _goBranch')),
          isNot(contains('NotificationPrompt.showIfNeeded')));
      expect(shell, contains('NoteSavedMoment.pending.addListener'));
    });

    test('the full-screen editor raises the moment on a new note', () {
      expect(readProjectFile('lib/screens/create_note_screen_v2.dart'),
          contains('if (!widget.embedded) NoteSavedMoment.noteCreated();'));
    });

    test('a moment is taken once', () {
      NoteSavedMoment.noteCreated();
      expect(NoteSavedMoment.take(), isTrue);
      expect(NoteSavedMoment.take(), isFalse);
    });
  });

  group('countNotes', () {
    late AppDatabase db;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
      getIt.registerSingleton<AppDatabase>(db);
    });
    tearDown(() async {
      getIt.unregister<AppDatabase>();
      await db.close();
    });

    test('counts every type, archived included, trash excluded', () async {
      final t = DateTime(2026, 11, 1);
      expect(await DriftNoteService.countNotes(), 0);
      await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
          uuid: 'a', content: 'x', createdAt: t, updatedAt: t));
      await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
          uuid: 'b', content: 'x', isArchived: const Value(true),
          createdAt: t, updatedAt: t));
      await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
          uuid: 'c', content: 'x', isDeleted: const Value(true),
          createdAt: t, updatedAt: t));
      await db.into(db.todoListNotesV2).insert(TodoListNotesV2Companion.insert(
          uuid: 'd', createdAt: t, updatedAt: t));
      await db.into(db.reminderNotesV2).insert(ReminderNotesV2Companion.insert(
          uuid: 'e', reminderTime: t, createdAt: t, updatedAt: t));
      await db.into(db.voiceNotesV2).insert(VoiceNotesV2Companion.insert(
          uuid: 'f', audioFilePath: '/x.m4a', createdAt: t, updatedAt: t));
      expect(await DriftNoteService.countNotes(), 5);
    });
  });
}
