import 'dart:io';

import 'package:drift/native.dart';
import 'package:fleather/fleather.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen_v2.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/widgets/markdown_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';

/// Builds the real editor screen for every note type against an in-memory
/// database, so a layout error in the Sketchbook editor (slivers, overlays,
/// the floating toolbar) fails here rather than on a device.
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

  Widget app(String type, Brightness brightness, {String? initialText}) =>
      MaterialApp(
        theme: PinpointTheme.light(),
        darkTheme: PinpointTheme.dark(),
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('en'),
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: CreateNoteScreenV2(
          arguments: CreateNoteScreenArguments(
              noticeType: type, initialText: initialText),
        ),
      );

  for (final type in [
    'Title Content',
    'Todo List',
    'Record Audio',
    'Reminder'
  ]) {
    for (final b in Brightness.values) {
      testWidgets('$type editor builds (${b.name})', (tester) async {
        tester.view.physicalSize = const Size(390, 844) * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        // audioplayers opens event streams with random channel names, so they
        // cannot be mocked one by one; their missing-plugin noise is not what
        // this test is about.
        final onError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exception is MissingPluginException) return;
          onError?.call(details);
        };
        await tester
            .runAsync(() => DriftNoteFolderService.insertNoteFolder('Random'));

        await tester.pumpWidget(app(type, b));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('More options'), findsOneWidget);
        expect(find.text('Random'), findsOneWidget);

        // Tear down inside the test so drift's stream timers settle.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        FlutterError.onError = onError;
      });
    }
  }

  // Review 2026-11-01, F10: the other note types are reachable from a blank
  // new text note, not only by long-pressing Create.
  Future<void> open(WidgetTester tester, String type) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester
        .runAsync(() => DriftNoteFolderService.insertNoteFolder('Random'));
    await tester.pumpWidget(app(type, Brightness.light));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  // Crashlytics, Nov 2026 (157 of 165 events): pasting from the toolbar calls
  // bringIntoView a frame later, which reads the editor's scroll controller.
  // A non-scrollable editor must be given one that is attached to something,
  // or ScrollController.position throws "Bad state: No element".
  // The toolbar floats over the page. With the keyboard open the page must end
  // above it, or the line being typed is revealed behind the toolbar.
  testWidgets('the page ends above the floating toolbar while typing',
      (tester) async {
    await open(tester, 'Title Content');
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(tester.getBottomLeft(find.byType(CustomScrollView)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(MarkdownToolbar)).dy));
    await close(tester);
  });

  testWidgets('text from the share sheet starts the note', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester
        .runAsync(() => DriftNoteFolderService.insertNoteFolder('Random'));
    await tester.pumpWidget(app('Title Content', Brightness.light,
        initialText: 'https://example.com/shared'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('https://example.com/shared', findRichText: true),
        findsOneWidget);
    await close(tester);
  });

  testWidgets('revealing the caret after a paste does not throw',
      (tester) async {
    await open(tester, 'Title Content');

    final editor = tester.state(find.byType(RawEditor)) as TextSelectionDelegate;
    editor.bringIntoView(const TextPosition(offset: 0));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('a blank new text note offers checklist, voice and reminder',
      (tester) async {
    await open(tester, 'Title Content');

    expect(find.text('Or start a'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);

    // Once there is something to lose, the row goes away.
    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.pump();
    expect(find.text('Or start a'), findsNothing);

    await close(tester);
  });

  testWidgets('other note types do not show the start-as row', (tester) async {
    await open(tester, 'Todo List');
    expect(find.text('Or start a'), findsNothing);
    await close(tester);
  });

  test('the editor no longer advertises encrypted sharing', () {
    // Not built; a disabled "Share Encrypted · SOON" item promised it.
    final source =
        File('lib/screens/create_note_screen_v2.dart').readAsStringSync();
    expect(source.contains("'share_encrypted'"), isFalse);
  });
}
