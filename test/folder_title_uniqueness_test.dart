import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';

/// Regression tests for the folder-title UNIQUE constraint.
///
/// Crashlytics reported this as a fatal error:
///
/// ```
/// SqliteException(2067): UNIQUE constraint failed: note_folders.note_folder_title
///   INSERT INTO "note_folders" (...) VALUES (?, ?, ?, ?), parameters: ..., Coro nacional, ...
///   at DriftNoteFolderService.insertNoteFolder (drift_note_folder_service.dart:115)
///   at _ShowNoteFolderBottomSheetState.build (show_note_folder_bottom_sheet.dart:99)
/// ```
///
/// Every screen guarded the insert by scanning a list of folders it was already
/// holding. That list goes stale — a folder arriving from sync, or created on
/// another screen, is not in it — and the insert then died on the index.
///
/// These run the real schema against an in-memory database, so the constraint
/// under test is the actual one, not a stand-in.
void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    if (getIt.isRegistered<AppDatabase>()) {
      getIt.unregister<AppDatabase>();
    }
    getIt.registerSingleton<AppDatabase>(database);
  });

  tearDown(() async {
    getIt.unregister<AppDatabase>();
    await database.close();
  });

  /// Writes a folder straight to the table, bypassing the service — the way a
  /// sync would.
  Future<void> insertBehindTheServicesBack(String title) async {
    final now = Value(DateTime.now());
    await database.into(database.noteFolders).insert(
          NoteFoldersCompanion(
            uuid: Value('uuid-$title'),
            noteFolderTitle: Value(title),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('the raw constraint still fires — the defect being guarded', () async {
    await insertBehindTheServicesBack('Coro nacional');

    // Proves the UNIQUE index is real and still on this column, so the tests
    // below are guarding something rather than passing vacuously.
    expect(
      () => insertBehindTheServicesBack('Coro nacional'),
      throwsA(predicate((e) =>
          '$e'.contains('UNIQUE constraint failed') &&
          '$e'.contains('note_folders.note_folder_title'))),
    );
  });

  test('a duplicate title raises FolderTitleTakenException, not a db error',
      () async {
    await DriftNoteFolderService.insertNoteFolder('Coro nacional');

    await expectLater(
      DriftNoteFolderService.insertNoteFolder('Coro nacional'),
      throwsA(isA<FolderTitleTakenException>()),
    );
  });

  test('a title created behind the service is still detected', () async {
    // The reported crash: the UI list says the name is free, the database
    // disagrees.
    await insertBehindTheServicesBack('Coro nacional');

    await expectLater(
      DriftNoteFolderService.insertNoteFolder('Coro nacional'),
      throwsA(isA<FolderTitleTakenException>()),
    );
  });

  test('duplicate detection ignores case, unlike the index itself', () async {
    // SQLite's UNIQUE uses BINARY collation and would happily accept this; the
    // app treats the two as the same folder, so the service must reject it.
    await DriftNoteFolderService.insertNoteFolder('Coro nacional');

    await expectLater(
      DriftNoteFolderService.insertNoteFolder('CORO NACIONAL'),
      throwsA(isA<FolderTitleTakenException>()),
    );
  });

  test('a distinct title still inserts', () async {
    final first = await DriftNoteFolderService.insertNoteFolder('Work');
    final second = await DriftNoteFolderService.insertNoteFolder('Personal');

    expect(first.title, 'Work');
    expect(second.title, 'Personal');
    expect(await DriftNoteFolderService.isTitleTaken('Work'), isTrue);
    expect(await DriftNoteFolderService.isTitleTaken('Nope'), isFalse);
  });

  group('renameFolder', () {
    test('renaming onto another folder throws instead of crashing', () async {
      final work = await DriftNoteFolderService.insertNoteFolder('Work');
      await DriftNoteFolderService.insertNoteFolder('Personal');

      await expectLater(
        DriftNoteFolderService.renameFolder(work.id, 'Personal'),
        throwsA(isA<FolderTitleTakenException>()),
      );
    });

    test('re-casing a folder\'s own title is allowed', () async {
      final work = await DriftNoteFolderService.insertNoteFolder('work');

      await DriftNoteFolderService.renameFolder(work.id, 'Work');

      expect(await DriftNoteFolderService.isTitleTaken('Work'), isTrue);
    });

    test('renaming to a free title succeeds', () async {
      final work = await DriftNoteFolderService.insertNoteFolder('Work');

      await DriftNoteFolderService.renameFolder(work.id, 'Archive');

      expect(await DriftNoteFolderService.isTitleTaken('Archive'), isTrue);
      expect(await DriftNoteFolderService.isTitleTaken('Work'), isFalse);
    });
  });
}
