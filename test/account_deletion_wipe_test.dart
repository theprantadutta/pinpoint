import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/google_sign_in_service.dart';
import 'package:pinpoint/services/logout_service.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';

/// Tests for what "Delete Account" actually destroys, against the production
/// schema.
///
/// A user reported that the button did not delete her account. It did — on the
/// server — but the client made that impossible to tell and left most of her
/// data behind:
///
///   * `BackendAuthService` flipped `isAuthenticated` immediately after the
///     server call, which rebuilt the Settings account section and disposed the
///     widget still running the deletion. Neither the success nor the failure
///     toast could fire, and a cleanup error skipped the navigation too.
///   * The local wipe deleted `notes` and `note_folders` only, trusting
///     cascades that nothing enforced, so note bodies, checklist items,
///     attachments and every V2 note table survived.
///   * Audio sweeping read the legacy `audio_notes` table, while every
///     recording the shipping editor makes lands in `voice_notes_v2`.
///
/// [AppDatabase] is the real one here, opened in memory, so the schema and the
/// `beforeOpen` foreign-key hook under test are the shipping ones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeBackendAuth auth;
  late FakeGoogleSignIn google;
  late LogoutService logoutService;
  late Directory audioDir;

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  final now = DateTime.utc(2026, 9, 2);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);

    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = FakeBackendAuth(db);
    google = FakeGoogleSignIn();
    audioDir = await Directory.systemTemp.createTemp('pinpoint_audio_test');

    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    getIt.registerSingleton<AnalyticsFacade>(RecordingAnalyticsFacade());

    logoutService = LogoutService(
      database: db,
      syncManager: SyncManager(),
      backendAuthService: auth,
      googleSignInService: google,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    getIt.unregister<AnalyticsFacade>();
    await db.close();
    if (audioDir.existsSync()) {
      audioDir.deleteSync(recursive: true);
    }
  });

  Future<int> countOf(String table) async {
    final row =
        await db.customSelect('SELECT COUNT(*) AS c FROM "$table"').getSingle();
    return row.read<int>('c');
  }

  /// Every table that a real account has rows in, populated so that a wipe
  /// missing any one of them is visible.
  Future<void> seedEveryTable() async {
    final folderId = await db.into(db.noteFolders).insert(
          NoteFoldersCompanion.insert(
            uuid: 'folder-1',
            noteFolderTitle: 'Groceries',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Legacy unified note plus one row in each of its child tables.
    final noteId = await db.into(db.notes).insert(
          NotesCompanion.insert(
            uuid: 'note-1',
            noteType: 'text',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.textNotes).insert(TextNotesCompanion.insert(
        noteId: Value(noteId), content: const Value('private body text')));
    await db.into(db.todoNotes).insert(
          TodoNotesCompanion.insert(noteId: Value(noteId)),
        );
    await db.into(db.reminderNotes).insert(
          ReminderNotesCompanion.insert(
              noteId: Value(noteId), reminderTime: now),
        );
    await db.into(db.noteTodoItems).insert(
          NoteTodoItemsCompanion.insert(
            uuid: 'item-1',
            noteId: noteId,
            noteUuid: 'note-1',
            todoTitle: 'buy milk',
          ),
        );
    await db.into(db.noteAttachments).insert(
          NoteAttachmentsCompanion.insert(
            noteId: noteId,
            attachmentName: 'receipt.png',
            attachmentPath: '/tmp/receipt.png',
          ),
        );
    await db.into(db.noteFolderRelations).insert(
          NoteFolderRelationsCompanion.insert(
            noteId: noteId,
            noteFolderId: folderId,
          ),
        );

    // The V2 families the shipping editor actually writes.
    final textId = await db.into(db.textNotesV2).insert(
          TextNotesV2Companion.insert(
            uuid: 'text-1',
            content: 'diary entry',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.textNoteFolderRelationsV2).insert(
        TextNoteFolderRelationsV2Companion.insert(
            textNoteId: textId, folderId: folderId));

    final listId = await db.into(db.todoListNotesV2).insert(
          TodoListNotesV2Companion.insert(
            uuid: 'list-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.todoItemsV2).insert(
          TodoItemsV2Companion.insert(
            uuid: 'v2-item-1',
            todoListNoteId: listId,
            todoListNoteUuid: 'list-1',
            content: 'call the bank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.todoListNoteFolderRelationsV2).insert(
        TodoListNoteFolderRelationsV2Companion.insert(
            todoListNoteId: listId, folderId: folderId));

    final reminderId = await db.into(db.reminderNotesV2).insert(
          ReminderNotesV2Companion.insert(
            uuid: 'reminder-1',
            reminderTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.reminderNoteFolderRelationsV2).insert(
        ReminderNoteFolderRelationsV2Companion.insert(
            reminderNoteId: reminderId, folderId: folderId));
  }

  /// Writes a real file on disk and registers it as a recording in [table].
  Future<File> seedRecording(String name, {required bool legacy}) async {
    final file = File('${audioDir.path}/$name')
      ..writeAsStringSync('fake audio');

    if (legacy) {
      final noteId = await db.into(db.notes).insert(
            NotesCompanion.insert(
              uuid: 'legacy-voice-$name',
              noteType: 'audio',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.audioNotes).insert(AudioNotesCompanion.insert(
          noteId: Value(noteId), audioFilePath: file.path));
    } else {
      await db.into(db.voiceNotesV2).insert(
            VoiceNotesV2Companion.insert(
              uuid: 'voice-$name',
              audioFilePath: file.path,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    return file;
  }

  group('AppDatabase.wipeAllData', () {
    test('empties every table, not just notes and folders', () async {
      await seedEveryTable();

      final deleted = await db.wipeAllData();

      expect(deleted, greaterThan(0));
      for (final table in db.allTables) {
        expect(await countOf(table.actualTableName), 0,
            reason: '${table.actualTableName} still has rows after the wipe');
      }
    });

    test('leaves note bodies and checklist items nowhere on the device',
        () async {
      await seedEveryTable();

      await db.wipeAllData();

      // The precise regression: these tables survived the old wipe because it
      // deleted `notes` and trusted an unenforced cascade for the rest.
      expect(await countOf('text_notes'), 0);
      expect(await countOf('note_todo_items'), 0);
      expect(await countOf('note_attachments'), 0);
      expect(await countOf('text_notes_v2'), 0);
      expect(await countOf('todo_items_v2'), 0);
    });

    test('leaves the schema intact and usable', () async {
      await seedEveryTable();
      await db.wipeAllData();

      final id = await db.into(db.notes).insert(
            NotesCompanion.insert(
              uuid: 'after-wipe',
              noteType: 'text',
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(id, greaterThan(0));
      expect(await countOf('notes'), 1);
    });
  });

  group('LogoutService.performAccountDeletion', () {
    test('deletes on the server and wipes every local table', () async {
      await seedEveryTable();

      final result = await logoutService.performAccountDeletion();

      expect(result, isTrue);
      expect(auth.serverDeletions, 1);
      for (final table in db.allTables) {
        expect(await countOf(table.actualTableName), 0,
            reason: '${table.actualTableName} survived account deletion');
      }
    });

    test('deletes recordings from both the legacy and the V2 table', () async {
      final legacy = await seedRecording('old.m4a', legacy: true);
      final current = await seedRecording('new.m4a', legacy: false);

      await logoutService.performAccountDeletion();

      expect(legacy.existsSync(), isFalse);
      // The one that used to be left behind: every recording the shipping
      // editor makes is a voice_notes_v2 row.
      expect(current.existsSync(), isFalse,
          reason: 'voice_notes_v2 recordings were left on disk');
    });

    test('resets auth state only after the local wipe has finished', () async {
      await seedEveryTable();

      await logoutService.performAccountDeletion();

      expect(auth.resets, 1);
      // Flipping isAuthenticated mid-flow is what tore the Settings account
      // section — and the Delete Account row driving the deletion — out of the
      // tree, swallowing both the success and the failure toast. A zero here
      // means the wipe had already completed when listeners were notified.
      expect(auth.notesRowsWhenReset, 0,
          reason: 'auth state was reset while the wipe was still running');
    });

    test('signs out of the identity provider', () async {
      await logoutService.performAccountDeletion();
      expect(google.signOuts, 1);
    });

    test('still succeeds when the local wipe fails', () async {
      await seedEveryTable();
      // A closed database makes _clearDatabase throw the way a locked or
      // corrupt file would on a device.
      await db.close();

      final result = await logoutService.performAccountDeletion();

      // The account is already gone server-side, so reporting failure would
      // strand the user on a signed-in screen for an account that no longer
      // exists.
      expect(result, isTrue);
      expect(auth.serverDeletions, 1);
      expect(auth.resets, 1);
    });

    test('fails loudly when the server deletion fails, changing nothing',
        () async {
      await seedEveryTable();
      auth.failServerDeletion = true;

      await expectLater(
        logoutService.performAccountDeletion(),
        throwsA(isA<Exception>()),
      );

      // Nothing local may be destroyed for an account that still exists.
      expect(auth.resets, 0);
      expect(await countOf('notes'), greaterThan(0));
      expect(await countOf('text_notes_v2'), greaterThan(0));
    });
  });
}

/// Stands in for the process-wide [BackendAuthService] singleton, whose private
/// constructor rules out subclassing. Only the two members the deletion flow
/// touches are implemented; anything else is a test bug and throws.
class FakeBackendAuth implements BackendAuthService {
  FakeBackendAuth(this._db);

  final AppDatabase _db;

  int serverDeletions = 0;
  int resets = 0;
  bool failServerDeletion = false;

  /// How many notes were still on the device when auth state was reset.
  int? notesRowsWhenReset;

  @override
  Future<void> deleteAccountOnServer() async {
    if (failServerDeletion) {
      throw Exception('backend refused the deletion');
    }
    serverDeletions++;
  }

  @override
  Future<void> resetLocalAuthState() async {
    resets++;
    try {
      final row =
          await _db.customSelect('SELECT COUNT(*) AS c FROM notes').getSingle();
      notesRowsWhenReset = row.read<int>('c');
    } catch (_) {
      // The closed-database test cannot observe the count; the other
      // assertions cover that case.
      notesRowsWhenReset = null;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the [GoogleSignInService] singleton, which reaches Firebase
/// and the platform channel in its constructor.
class FakeGoogleSignIn implements GoogleSignInService {
  int signOuts = 0;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
