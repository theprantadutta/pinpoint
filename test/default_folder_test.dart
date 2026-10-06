import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';

import 'support/project_source.dart';

/// A note always has a folder to go in. Signing out once kept the "default
/// folders created" flag while wiping the folders, so the next account had
/// none and every note save failed — silently, inside autosave.
void main() {
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

  test('with no folders at all, Random is created and reused', () async {
    expect(await db.select(db.noteFolders).get(), isEmpty);

    final first = await DriftNoteFolderService.ensureDefaultFolder();
    final again = await DriftNoteFolderService.ensureDefaultFolder();

    expect(first.title, 'Random');
    expect(again.id, first.id);
    final rows = await db.select(db.noteFolders).get();
    expect(rows, hasLength(1));
    // The same uuid every device derives, so the folders merge on sync.
    expect(rows.single.uuid, '0eb42edd-30f1-57f7-846a-c3ff6114ff3e');
  });

  test('an existing Random is used, whatever its case', () async {
    await db.into(db.noteFolders).insert(NoteFoldersCompanion.insert(
          uuid: 'x',
          noteFolderTitle: 'random',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ));
    final folder = await DriftNoteFolderService.ensureDefaultFolder();
    expect(folder.title, 'random');
    expect(await db.select(db.noteFolders).get(), hasLength(1));
  });

  test('sign-out does not keep flags describing the database it clears', () {
    final logout = readProjectFile('lib/services/logout_service.dart');
    final keep = logout.substring(logout.indexOf('final keysToKeep'), logout.indexOf('};', logout.indexOf('final keysToKeep')));
    expect(keep, isNot(contains('kDidPopulatedNoteFolder')));
    expect(keep, isNot(contains('kDidPopulatedNoteType')));
    expect(kDidPopulatedNoteFolder, isNotEmpty);
    expect(readProjectFile('lib/screens/create_note_screen_v2.dart'),
        isNot(contains("throw Exception('No folders available')")));
  });
}
