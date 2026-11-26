import 'package:drift/native.dart';
import 'package:fleather/fleather.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen_v2.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/services/text_note_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';

/// A new note must survive every way out of the editor.
///
/// Device test of 4.4.0 (A24, 24 Nov 2026): the blank note that opens after
/// onboarding was typed into and left with system BACK about a second later.
/// Nothing was saved. Only the app-bar arrow saved; system back popped the
/// route, and dispose cancelled the 2-second autosave that held the text.
/// The same test showed "Edited" and a date on a new, untouched editor: autosave
/// counted the empty document's JSON (`[{"insert":"\n"}]`) as content, so
/// tapping the body and waiting created an empty note.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;

  const channels = [
    MethodChannel('xyz.luan/audioplayers'),
    MethodChannel('xyz.luan/audioplayers.global'),
    MethodChannel('com.llfbandit.record/messages'),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
    getIt.registerSingleton<AppDatabase>(database);
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    getIt.registerSingleton<AnalyticsFacade>(RecordingAnalyticsFacade());
    for (final c in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(c, (_) async => null);
    }
  });

  tearDown(() async {
    for (final c in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(c, null);
    }
    getIt.unregister<AnalyticsFacade>();
    getIt.unregister<AppDatabase>();
    await database.close();
  });

  const typed = 'Buy bread and eggs';

  Widget shell(Widget home) => MaterialApp(
        theme: PinpointTheme.light(),
        locale: const Locale('en'),
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: home,
      );

  /// Lets real-async database work (drift isolates, timers) finish.
  Future<void> settleDb(WidgetTester tester, [int ms = 100]) async {
    await tester
        .runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }

  /// Home with the editor pushed on top, as `NewNote.open` does (the
  /// onboarding blank note and the Create button pass the same arguments).
  Future<void> openNewNote(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    await tester
        .runAsync(() => DriftNoteFolderService.insertNoteFolder('Random'));
    await tester.pumpWidget(shell(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const CreateNoteScreenV2(
                arguments:
                    CreateNoteScreenArguments(noticeType: 'Title Content'),
              ),
            )),
            child: const Text('home'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    await settleDb(tester);
  }

  /// Types into the body the way the IME does: through the editor's
  /// selection delegate, which applies the diff to the document.
  Future<void> typeBody(WidgetTester tester, String text) async {
    await tester.tap(find.byType(FleatherEditor));
    await tester.pump();
    final editor =
        tester.state(find.byType(RawEditor)) as TextSelectionDelegate;
    editor.userUpdateTextEditingValue(
      TextEditingValue(
        text: '$text\n',
        selection: TextSelection.collapsed(offset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
  }

  Future<List<TextNoteEntity>> textNotes(WidgetTester tester) async =>
      (await tester
          .runAsync(() => database.select(database.textNotesV2).get()))!;

  /// Waits for saves that outlive the editor, then tears down.
  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await settleDb(tester);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  Future<void> expectSaved(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await settleDb(tester);
    }
    final notes = await textNotes(tester);
    expect(notes, hasLength(1), reason: 'exactly one note, never a duplicate');
    expect(notes.single.content, contains(typed));
  }

  testWidgets('system back right after typing saves the note', (tester) async {
    await openNewNote(tester);
    await typeBody(tester, typed);

    // Well inside the 2-second autosave debounce.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await settleDb(tester);
    await tester.pumpAndSettle();

    await expectSaved(tester);
    expect(find.text('home'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('back twice in quick succession saves once and leaves once',
      (tester) async {
    await openNewNote(tester);
    await typeBody(tester, typed);

    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await settleDb(tester);
    await tester.pumpAndSettle();
    await settleDb(tester);
    await tester.pumpAndSettle();

    await expectSaved(tester);
    // The second back must not pop the home route under the editor.
    expect(find.text('home'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Navigator.maybePop right after typing saves the note',
      (tester) async {
    await openNewNote(tester);
    await typeBody(tester, typed);

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pump();
    await settleDb(tester);
    await tester.pumpAndSettle();

    await expectSaved(tester);
    await finish(tester);
  });

  testWidgets('the app-bar back arrow right after typing saves the note',
      (tester) async {
    await openNewNote(tester);
    await typeBody(tester, typed);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    await settleDb(tester, 300);
    await tester.pumpAndSettle();

    await expectSaved(tester);
    expect(find.text('home'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('going to the background right after typing saves the note',
      (tester) async {
    await openNewNote(tester);
    await typeBody(tester, typed);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settleDb(tester);

    await expectSaved(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await finish(tester);
  });

  testWidgets('the route removed without a back press still saves the note',
      (tester) async {
    await openNewNote(tester);
    await typeBody(tester, typed);

    // Navigator.pop skips PopScope, like a redirect or a replaced route.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await expectSaved(tester);
    await finish(tester);
  });

  testWidgets('a blank new note that was only tapped is not saved',
      (tester) async {
    await openNewNote(tester);
    await tester.tap(find.byType(FleatherEditor));
    await tester.pump();
    // The blank page under a one-line body: it moves the caret to the end,
    // which notifies the controller and starts the autosave timer.
    await tester.tapAt(const Offset(195, 560));
    await tester.pump();

    // Past the autosave debounce.
    await tester.pump(const Duration(seconds: 3));
    await settleDb(tester);
    await tester.pump();

    expect(find.textContaining('Edited'), findsNothing);
    expect(await textNotes(tester), isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await settleDb(tester);
    expect(await textNotes(tester), isEmpty);
    expect(find.text('home'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('autosave saves a body-only note once the debounce passes',
      (tester) async {
    await openNewNote(tester);
    await typeBody(tester, typed);

    await tester.pump(const Duration(seconds: 3));
    await settleDb(tester);
    await tester.pump();

    await expectSaved(tester);
    expect(find.textContaining('Edited'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the tablet detail pane saves pending edits when it closes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester
        .runAsync(() => DriftNoteFolderService.insertNoteFolder('Random'));
    await tester.pumpWidget(shell(const Scaffold(
      body: CreateNoteScreenV2(
        embedded: true,
        arguments: CreateNoteScreenArguments(noticeType: 'Title Content'),
      ),
    )));
    await settleDb(tester);
    await typeBody(tester, typed);

    // Selecting another note swaps the pane's editor out.
    await tester.pumpWidget(shell(const Scaffold(body: SizedBox())));

    await expectSaved(tester);
    await finish(tester);
  });

  testWidgets('closing an existing note before it loads leaves it intact',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final folder = (await tester
        .runAsync(() => DriftNoteFolderService.insertNoteFolder('Random')))!;
    final id = (await tester.runAsync(() => TextNoteService.createTextNote(
          title: 'Kept',
          content: '[{"insert":"Old text\\n"}]',
          folders: [folder],
        )))!;
    final now = DateTime.now();
    await tester.pumpWidget(shell(Scaffold(
      body: CreateNoteScreenV2(
        embedded: true,
        arguments: CreateNoteScreenArguments(
          noticeType: 'Title Content',
          existingNote: NoteWithDetails(
              note: Note(
                id: id,
                uuid: 'existing',
                noteTitle: 'Kept',
                noteType: 'text',
                isPinned: false,
                createdAt: now,
                updatedAt: now,
                isArchived: false,
                isDeleted: false,
                isSynced: false,
              ),
              folders: [folder],
              attachments: const [],
              todoItems: const []),
        ),
      ),
    )));
    // Gone before the database answered the load.
    await tester.pumpWidget(shell(const Scaffold(body: SizedBox())));
    for (var i = 0; i < 5; i++) {
      await settleDb(tester);
    }

    final notes = await textNotes(tester);
    expect(notes.single.content, contains('Old text'));
    expect(notes.single.title, 'Kept');
    await finish(tester);
  });

  testWidgets('clearing an existing note saves the cleared text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final folder = (await tester
        .runAsync(() => DriftNoteFolderService.insertNoteFolder('Random')))!;
    final id = (await tester.runAsync(() => TextNoteService.createTextNote(
          title: '',
          content: '[{"insert":"Old text\\n"}]',
          folders: [folder],
        )))!;
    final now = DateTime.now().subtract(const Duration(days: 2));
    final row = Note(
      id: id,
      uuid: 'existing',
      noteTitle: '',
      noteType: 'text',
      isPinned: false,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isDeleted: false,
      isSynced: false,
    );

    await tester.pumpWidget(shell(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CreateNoteScreenV2(
              arguments: CreateNoteScreenArguments(
                noticeType: 'Title Content',
                existingNote: NoteWithDetails(
                    note: row,
                    folders: [folder],
                    attachments: const [],
                    todoItems: const []),
              ),
            ),
          )),
          child: const Text('home'),
        ),
      ),
    )));
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    await settleDb(tester);
    await tester.pumpAndSettle();

    await typeBody(tester, '');
    await tester.binding.handlePopRoute();
    await tester.pump();
    await settleDb(tester);
    await tester.pumpAndSettle();
    await settleDb(tester);

    final notes = await textNotes(tester);
    expect(notes, hasLength(1));
    expect(notes.single.content, isNot(contains('Old text')));
    await finish(tester);
  });
}
