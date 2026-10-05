import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/screens/create_note_screen_v2.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/services/locale_controller.dart';
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

  Widget app(String type, Brightness brightness) => MaterialApp(
        theme: PinpointTheme.light(),
        darkTheme: PinpointTheme.dark(),
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('en'),
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          ...material_ui.GlobalMaterialLocalizations.delegates,
        ],
        home: CreateNoteScreenV2(
          arguments: CreateNoteScreenArguments(noticeType: type),
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
}
