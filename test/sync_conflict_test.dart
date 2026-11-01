import 'dart:ui' show Locale;
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:pinpoint/sync/api_sync_service.dart';
import 'package:pinpoint/sync/note_revisions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/project_source.dart';

/// Review 2026-11-01, F1: when the server refuses an upload because another
/// device replaced the note first, this device takes the newer copy and keeps
/// its own edit as a conflict copy. Neither version is lost.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
'''));

  setUp(() {
    SharedPreferences.setMockInitialValues({'locale_key': 'en'});
    SecureEncryptionService.debugInitializeWithKey(enc.Key.fromSecureRandom(32));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
    getIt.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    getIt.unregister<AppDatabase>();
    await db.close();
  });

  final t0 = DateTime.utc(2026, 11, 1, 9);

  Map<String, dynamic> serverNote(String uuid, String content, {bool deleted = false}) => {
        'client_note_uuid': uuid,
        'encrypted_data': SecureEncryptionService.encrypt(jsonEncode({
          'uuid': uuid, 'noteTitle': 'Plan', 'noteType': 'text', 'content': content,
          'isPinned': false, 'isArchived': false, 'isDeleted': deleted,
          'createdAt': t0.toIso8601String(), 'updatedAt': t0.add(const Duration(minutes: 5)).toIso8601String(),
          'folderUuids': <String>[],
        })),
        'updated_at': t0.add(const Duration(minutes: 5)).toIso8601String(),
        'server_updated_ms': 1798794000123,
      };

  Future<void> localNote(String content, {bool deleted = false}) => db.into(db.textNotesV2).insert(
        TextNotesV2Companion.insert(
          uuid: 'n', title: const Value('Plan'), content: content, isDeleted: Value(deleted),
          createdAt: t0, updatedAt: t0.add(const Duration(minutes: 2)),
        ),
      );

  ApiSyncService sync() => ApiSyncService(apiService: ApiService(), database: db);

  test('the newer copy is taken and this device\'s edit kept as a conflict copy', () async {
    await localNote('my offline edit');

    await sync().resolveConflict(serverNote('n', 'their newer edit'));

    final notes = {for (final n in await db.select(db.textNotesV2).get()) n.uuid: n};
    expect(notes, hasLength(2));
    expect(notes['n']!.content, 'their newer edit');
    final copy = notes.values.firstWhere((n) => n.uuid != 'n');
    expect(copy.content, 'my offline edit');
    expect(copy.title, 'Plan (conflict copy)');
    expect(copy.isSynced, isFalse, reason: 'the copy goes up to the cloud too');
    expect((await NoteRevisions.all())['n'], 1798794000123);
  });

  test('a local deletion that lost just gives way: the note comes back, no copy', () async {
    await localNote('old', deleted: true);

    await sync().resolveConflict(serverNote('n', 'edited elsewhere'));

    final notes = await db.select(db.textNotesV2).get();
    expect(notes, hasLength(1));
    expect(notes.single.isDeleted, isFalse);
    expect(notes.single.content, 'edited elsewhere');
  });

  test('conflict copies are titled in the user\'s language', () async {
    final pt = await AppL10n.delegate.load(const Locale('pt'));
    expect(conflictCopyTitle('Compras', pt), 'Compras (cópia em conflito)');
    expect(conflictCopyTitle('  ', pt), 'Cópia em conflito');
  });

  test('wired: every upload carries the base it was made on', () {
    final src = readProjectFile('lib/sync/api_sync_service.dart');
    expect(src, contains("encryptedNote['base_server_ms'] = base"));
    expect(src, contains("response['conflict_notes']"));
    expect(src, contains('NoteRevisions.record({clientNoteUuid: serverMs})'));
  });
}
