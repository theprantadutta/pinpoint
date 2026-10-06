import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/backup/backup_archive.dart';
import 'package:pinpoint/services/backup/drive_backup_service.dart';
import 'package:pinpoint/services/backup/local_backup_service.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Drive backups, end to end on the device side: everything on the
/// phone goes into one file encrypted with the account key, and comes back by
/// merging, onto a phone signed in to the same account only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late AppDatabase db;
  final keyA = enc.Key.fromSecureRandom(32);
  final keyB = enc.Key.fromSecureRandom(32);

  setUpAll(() {
    // ApiSyncService constructs ApiService, which reads dotenv. Nothing here
    // talks to a server.
    dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
''');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SecureEncryptionService.debugInitializeWithKey(keyA);
    temp = await Directory.systemTemp.createTemp('pp_backup_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
    getIt.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    getIt.unregister<AppDatabase>();
    await db.close();
    await temp.delete(recursive: true);
  });

  /// A new phone, signed in to the same account: empty database.
  Future<void> freshPhone() async {
    getIt.unregister<AppDatabase>();
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    getIt.registerSingleton<AppDatabase>(db);
  }

  final edited = DateTime.utc(2026, 10, 6, 9);

  Future<void> seed() async {
    final folderId = await db.into(db.noteFolders).insert(NoteFoldersCompanion.insert(
        uuid: 'folder-work', noteFolderTitle: 'Work', createdAt: edited, updatedAt: edited));
    final textId = await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
        uuid: 'text-1', title: const Value('Plan'), content: 'Ship the backups',
        createdAt: edited, updatedAt: edited, isSynced: const Value(true)));
    await db.into(db.textNoteFolderRelationsV2).insert(
        TextNoteFolderRelationsV2Companion.insert(textNoteId: textId, folderId: folderId));

    final audio = File('${temp.path}/voice_note_1.m4a')..writeAsBytesSync([7, 7, 7, 1, 2, 3]);
    await db.into(db.voiceNotesV2).insert(VoiceNotesV2Companion.insert(
        uuid: 'voice-1', title: const Value('Memo'), audioFilePath: audio.path,
        createdAt: edited, updatedAt: edited, isSynced: const Value(true)));
  }

  LocalBackupService local() => LocalBackupService(database: db);

  test('a backup holds every note, folder and recording, and restores onto a new phone', () async {
    await seed();
    final backup = await local().create(accountId: 'account-a', device: 'Test phone');
    expect(backup.manifest.noteCount, 2);
    expect(backup.manifest.recordingCount, 1);

    // Nothing readable in the file: notes and recordings are ciphertext.
    final raw = String.fromCharCodes(backup.file.readAsBytesSync());
    expect(raw, isNot(contains('Ship the backups')));

    await freshPhone();
    final summary = await local().restore(backup.file);
    expect(summary.notesAdded, 2);
    expect(summary.foldersAdded, 1);
    expect(summary.recordingsRestored, 1);

    final text = await (db.select(db.textNotesV2)..where((t) => t.uuid.equals('text-1'))).getSingle();
    expect(text.content, 'Ship the backups');
    expect(text.isSynced, isFalse, reason: 'restored notes go up to the cloud too');
    final relations = await db.select(db.textNoteFolderRelationsV2).get();
    final folder = await db.select(db.noteFolders).getSingle();
    expect(folder.noteFolderTitle, 'Work');
    expect(relations.single.folderId, folder.noteFolderId);

    final voice = await (db.select(db.voiceNotesV2)..where((t) => t.uuid.equals('voice-1'))).getSingle();
    expect(File(voice.audioFilePath).readAsBytesSync(), [7, 7, 7, 1, 2, 3]);
    expect(voice.audioFilePath, isNot(contains('voice_note_1')), reason: 'placed in the audio folder');
  });

  test('restoring merges: nothing newer on the phone is overwritten, nothing is deleted', () async {
    await seed();
    final backup = await local().create(accountId: 'account-a');

    // Edited on the phone after the backup, plus a note the backup never saw.
    await (db.update(db.textNotesV2)..where((t) => t.uuid.equals('text-1'))).write(TextNotesV2Companion(
        content: const Value('Edited later'), updatedAt: Value(edited.add(const Duration(hours: 1)))));
    await db.into(db.textNotesV2).insert(TextNotesV2Companion.insert(
        uuid: 'text-2', content: 'Only here', createdAt: edited, updatedAt: edited));

    final summary = await local().restore(backup.file);
    expect(summary.notesAdded, 0);
    expect(summary.notesSkipped, 2);
    final notes = {for (final n in await db.select(db.textNotesV2).get()) n.uuid: n.content};
    expect(notes, {'text-1': 'Edited later', 'text-2': 'Only here'});
  });

  test('a folder whose name is taken here is merged into that folder', () async {
    await seed();
    final backup = await local().create(accountId: 'account-a');
    await freshPhone();
    await db.into(db.noteFolders).insert(NoteFoldersCompanion.insert(
        uuid: 'another-uuid', noteFolderTitle: 'work', createdAt: edited, updatedAt: edited));

    final summary = await local().restore(backup.file);
    expect(summary.foldersAdded, 0);
    final folders = await db.select(db.noteFolders).get();
    expect(folders, hasLength(1));
    final relation = await db.select(db.textNoteFolderRelationsV2).getSingle();
    expect(relation.folderId, folders.single.noteFolderId);
  });

  test('only the account whose key made it can restore it', () async {
    await seed();
    final backup = await local().create(accountId: 'account-a');
    await freshPhone();

    SecureEncryptionService.debugInitializeWithKey(keyB);
    await expectLater(
      local().restore(backup.file),
      throwsA(isA<BackupFormatException>().having((e) => e.code, 'code', BackupProblem.otherAccount)),
    );
    expect(await db.select(db.textNotesV2).get(), isEmpty, reason: 'nothing touched');
  });

  test('a file that is not a backup is refused before anything is touched', () async {
    final junk = File('${temp.path}/junk.pinpoint-backup')..writeAsStringSync('not a zip');
    await expectLater(
      local().restore(junk),
      throwsA(isA<BackupFormatException>().having((e) => e.code, 'code', BackupProblem.notABackup)),
    );
  });

  test('a backup from a newer app is refused', () {
    expect(
      () => BackupManifest.fromJson({
        'format_version': BackupArchive.formatVersion + 1,
        'created_at': '2026-10-06T09:00:00Z',
        'key_check': 'x',
      }),
      throwsA(isA<BackupFormatException>().having((e) => e.code, 'code', BackupProblem.tooNew)),
    );
  });

  test('file names say what and where from', () {
    expect(
      DriveBackupService.fileNameFor(device: 'samsung SM-A245F', at: DateTime(2026, 10, 6, 15, 30, 5)),
      'pinpoint-backup-20261006-153005-samsung-sm-a245f.pinpoint-backup',
    );
  });
}
