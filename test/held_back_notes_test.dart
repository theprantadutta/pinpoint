import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/home_screen/local_only_banner.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/sync/held_back_notes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notes the free plan's sync limit kept back are marked "Only on this
/// phone" until the server accepts them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final when = DateTime.utc(2026, 11, 1);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HeldBackNotes.reset();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
    getIt.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    getIt.unregister<AppDatabase>();
    await db.close();
  });

  test('held back notes are added, accepted ones leave', () {
    final next = HeldBackNotes.apply({'a', 'b'}, rejected: ['c'], accepted: ['a']);
    expect(next, {'b', 'c'});
  });

  test('a note held back again stays marked once', () {
    expect(HeldBackNotes.apply({'a'}, rejected: ['a'], accepted: const []), {'a'});
  });

  test('recording persists, and loading drops notes deleted since', () async {
    await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
        uuid: 'kept', content: 'x', createdAt: when, updatedAt: when));
    await HeldBackNotes.record(rejected: ['kept', 'gone'], accepted: const []);
    expect(HeldBackNotes.contains('kept'), isTrue);

    HeldBackNotes.reset();
    await HeldBackNotes.load();

    expect(HeldBackNotes.notifier.value, {'kept'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(HeldBackNotes.prefsKey), ['kept']);
  });

  test('a held-back note moved to the trash stops counting', () async {
    await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
        uuid: 'n', content: 'x', createdAt: when, updatedAt: when));
    await HeldBackNotes.record(rejected: ['n'], accepted: const []);
    expect(HeldBackNotes.contains('n'), isTrue);

    await (db.update(db.textNotesV2)..where((t) => t.uuid.equals('n')))
        .write(const TextNotesV2Companion(isDeleted: Value(true)));
    await HeldBackNotes.record(rejected: const [], accepted: const []);

    expect(HeldBackNotes.contains('n'), isFalse);
  });

  Widget app(Widget child) => MaterialApp(
        theme: PinpointTheme.light(),
        locale: const Locale('en'),
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('a held-back card says so; others do not', (tester) async {
    await tester.pumpWidget(app(const Column(children: [
      NoteCard(title: 'Trip', localOnly: true),
      NoteCard(title: 'Groceries'),
    ])));
    expect(find.text('Only on this phone'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('the banner shows the count, hides on dismiss, returns when more are held back',
      (tester) async {
    await tester.runAsync(() async {
      for (final u in ['a', 'b', 'c']) {
        await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
            uuid: u, content: u, createdAt: when, updatedAt: when));
      }
    });
    await tester.pumpWidget(app(const LocalOnlyBanner()));
    expect(find.textContaining('only on this phone'), findsNothing);

    await tester.runAsync(() => HeldBackNotes.record(rejected: ['a', 'b'], accepted: const []));
    await tester.pump();
    expect(find.text('2 notes are only on this phone'), findsOneWidget);

    await tester.runAsync(HeldBackNotes.dismissBanner);
    await tester.pump();
    expect(find.text('2 notes are only on this phone'), findsNothing);

    await tester.runAsync(() => HeldBackNotes.record(rejected: ['c'], accepted: const []));
    await tester.pump();
    expect(find.text('3 notes are only on this phone'), findsOneWidget);

    // Everything backed up: gone, and the next time it happens it shows again.
    await tester.runAsync(() => HeldBackNotes.record(rejected: const [], accepted: ['a', 'b', 'c']));
    await tester.pump();
    expect(find.textContaining('only on this phone'), findsNothing);
    expect(HeldBackNotes.dismissedAt.value, 0);
  });
}
