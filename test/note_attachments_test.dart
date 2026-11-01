import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/create_note_screen/note_attachments_section.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/backup/local_backup_service.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:pinpoint/services/note_attachments/attachment_sync.dart';
import 'package:pinpoint/services/note_attachments/note_attachment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

/// Note attachments (images and any other file): offline first, synced by
/// FileRunner id inside the note's encrypted payload, kept in backups.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase db;
  final key = enc.Key.fromSecureRandom(32);
  final when = DateTime.utc(2026, 11, 1, 9);

  setUpAll(() {
    dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
''');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SecureEncryptionService.debugInitializeWithKey(key);
    temp = await Directory.systemTemp.createTemp('pp_attachments_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
    getIt.registerSingleton<AppDatabase>(db);
    await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
        uuid: 'note-1', content: 'Trip', createdAt: when, updatedAt: when, isSynced: const Value(true)));
  });

  tearDown(() async {
    getIt.unregister<AppDatabase>();
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<void> attach(String uuid, {String? remoteId, String? path, String mime = 'image/jpeg'}) =>
      db.into(db.noteAttachmentsV2).insert(NoteAttachmentsV2Companion.insert(
            uuid: uuid,
            noteUuid: 'note-1',
            noteType: 'text',
            fileName: '$uuid.jpg',
            mimeType: mime,
            sizeBytes: 3,
            localPath: Value(path),
            remoteId: Value(remoteId),
            createdAt: when,
          ));

  Future<Set<String>> uuids() async =>
      {for (final a in await NoteAttachmentService.forNote('note-1')) a.uuid};

  test('only uploaded attachments go into the payload', () async {
    await attach('up', remoteId: 'r-1');
    await attach('pending');

    final payload = await AttachmentSync.payloadFor('note-1');

    expect(payload.map((p) => p['id']), ['up']);
    expect(payload.single['remoteId'], 'r-1');
  });

  test('a payload from an older version (no attachments key) changes nothing', () async {
    await attach('up', remoteId: 'r-1');

    await AttachmentSync.applyFromPayload('note-1', 'text', null);

    expect(await uuids(), {'up'});
  });

  test('applying a payload adds new, drops removed, keeps not-yet-uploaded', () async {
    await attach('kept', remoteId: 'r-1');
    await attach('removed-elsewhere', remoteId: 'r-2');
    await attach('pending-here');

    await AttachmentSync.applyFromPayload('note-1', 'text', [
      {'id': 'kept', 'remoteId': 'r-1', 'name': 'kept.jpg', 'mime': 'image/jpeg', 'size': 3},
      {'id': 'from-tablet', 'remoteId': 'r-3', 'name': 'scan.pdf', 'mime': 'application/pdf', 'size': 9},
    ]);

    expect(await uuids(), {'kept', 'pending-here', 'from-tablet'});
    final added = (await NoteAttachmentService.forNote('note-1')).firstWhere((a) => a.uuid == 'from-tablet');
    expect(added.localPath, isNull, reason: 'downloaded at the next sync with a connection');
    expect(added.mimeType, 'application/pdf');
  });

  test('removing an uploaded attachment queues the server delete and re-syncs the note', () async {
    await attach('up', remoteId: 'r-1');
    final a = (await NoteAttachmentService.forNote('note-1')).single;

    await NoteAttachmentService.remove(a);

    expect(await uuids(), isEmpty);
    expect(await NoteAttachmentService.pendingRemoteDeletes(), ['r-1']);
    final note = await db.select(db.textNotesV2).getSingle();
    expect(note.isSynced, isFalse);
  });

  test('free plan holds 3 files per note, Pro is unlimited', () {
    expect(NoteAttachmentService.limitFor(isPremium: false), 3);
    expect(NoteAttachmentService.limitFor(isPremium: true), isNull);
  });

  test('file names, types and sizes', () {
    expect(NoteAttachmentService.extensionOf('Photo.JPG'), '.jpg');
    expect(NoteAttachmentService.extensionOf('noext'), '');
    expect(NoteAttachmentService.extensionOf('evil.../../x'), '');
    expect(NoteAttachmentService.mimeTypeFor('report.pdf'), 'application/pdf');
    expect(NoteAttachmentService.mimeTypeFor('mystery.zzz'), 'application/octet-stream');
    expect(formatAttachmentSize(1536 * 1024), '1.5 MB');
    expect(formatAttachmentSize(2048), '2 KB');
  });

  test('backups carry attachments, including ones never uploaded', () async {
    final file = File('${temp.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    await attach('local-only', path: file.path);
    final backup = await LocalBackupService(database: db).create(accountId: 'a');

    // A new phone, same account.
    getIt.unregister<AppDatabase>();
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    getIt.registerSingleton<AppDatabase>(db);
    await LocalBackupService(database: db).restore(backup.file);

    final restored = (await NoteAttachmentService.forNote('note-1')).single;
    expect(restored.uuid, 'local-only');
    expect(File(restored.localPath!).readAsBytesSync(), [1, 2, 3]);
    expect(restored.remoteId, isNull, reason: 'uploads at the next sync');
  });

  test('v12 → v13 adds the attachments table', () async {
    final dbFile = File('${temp.path}/v12.sqlite');
    final current = AppDatabase.forTesting(NativeDatabase(dbFile));
    await current.customSelect('SELECT 1').getSingle();
    await current.close();
    sqlite3.open(dbFile.path)
      ..execute('DROP TABLE note_attachments_v2')
      ..execute('PRAGMA user_version = 12')
      ..close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(dbFile));
    expect(await upgraded.select(upgraded.noteAttachmentsV2).get(), isEmpty);
    await upgraded.close();
  });
}
