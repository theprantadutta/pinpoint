import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/shared_preference_keys.dart';
import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../service_locators/init_service_locators.dart';

class DriftNoteFolderService {
  DriftNoteFolderService._();

  static final _noteFolders = [
    'Random',
    'HomeWork',
    'Workout',
    'Office',
    'Sports',
  ];

  static NoteFolderDto get firstNoteFolder {
    return NoteFolderDto(
      id: 1,
      title: _noteFolders.first,
    );
  }

  static Stream<List<NoteFolder>> getPrepopulatedNoteFoldersStream() async* {
    final sharedPreferences = await SharedPreferences.getInstance();
    final didPopulateBefore =
        sharedPreferences.getBool(kDidPopulatedNoteFolder) ?? false;

    if (didPopulateBefore) {
      yield [];
      return;
    }

    final now = Value(DateTime.now());
    final database = getIt<AppDatabase>();

    await database.batch(
      (batch) {
        batch.insertAll(
          database.noteFolders,
          _noteFolders.map(
            (folder) => NoteFoldersCompanion(
              noteFolderTitle: Value(folder),
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
      },
    );

    await sharedPreferences.setBool(kDidPopulatedNoteFolder, true);
    yield await database.select(database.noteFolders).get();
  }

  static Stream<List<NoteFolder>> watchAllNoteFoldersStream() async* {
    try {
      final database = getIt<AppDatabase>();

      // Fetch existing note folders from the database.
      final existingNoteFolders =
          await database.select(database.noteFolders).get();

      if (existingNoteFolders.isNotEmpty) {
        yield existingNoteFolders;
        return;
      }

      // Check if the note folders were populated before using shared preferences.
      final sharedPreferences = await SharedPreferences.getInstance();
      final didPopulateBefore =
          sharedPreferences.getBool(kDidPopulatedNoteFolder) ?? false;

      if (didPopulateBefore) {
        yield [];
        return;
      }

      // If not populated, yield prepopulated note folders.
      yield* getPrepopulatedNoteFoldersStream();
    } catch (e) {
      // Log the error if in debug mode.
      if (kDebugMode) {
        print('Something went wrong when getting note folders: $e');
      }
      // Rethrow the exception to handle it in the calling function.
      rethrow;
    }
  }

  static Future<NoteFolderDto> insertNoteFolder(String text) async {
    final database = getIt<AppDatabase>();

    final now = Value(DateTime.now());
    final noteFolder = NoteFoldersCompanion(
      noteFolderTitle: Value(text),
      createdAt: now,
      updatedAt: now,
    );

    final id = await database.into(database.noteFolders).insert(noteFolder);
    return NoteFolderDto(id: id, title: text);
  }

  static Future<void> renameFolder(int folderId, String newTitle) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.noteFolders)
          ..where((tbl) => tbl.noteFolderId.equals(folderId)))
        .write(NoteFoldersCompanion(noteFolderTitle: Value(newTitle)));
  }

  static Future<void> deleteFolder(int folderId) async {
    final database = getIt<AppDatabase>();
    await database.transaction(() async {
      await (database.delete(database.noteFolderRelations)
            ..where((tbl) => tbl.noteFolderId.equals(folderId)))
          .go();
      await (database.delete(database.noteFolders)
            ..where((tbl) => tbl.noteFolderId.equals(folderId)))
          .go();
    });
  }

  static Future<bool> upsertNoteFoldersWithNote(
      List<NoteFolderDto> folders, int noteId) async {
    try {
      final database = getIt<AppDatabase>();

      // Get current relations
      final existingRelations =
          await (database.select(database.noteFolderRelations)
                ..where((tbl) => tbl.noteId.equals(noteId)))
              .get();

      final existingFolderIds =
          existingRelations.map((r) => r.noteFolderId).toSet();
      final newFolderIds = folders.map((f) => f.id).toSet();

      await database.batch((batch) {
        // Delete relations that are no longer needed
        final toDelete = existingRelations
            .where((r) => !newFolderIds.contains(r.noteFolderId));

        for (final relation in toDelete) {
          batch.deleteWhere(
            database.noteFolderRelations,
            (tbl) =>
                tbl.noteId.equals(noteId) &
                tbl.noteFolderId.equals(relation.noteFolderId),
          );
        }

        // Insert only new relations that don't exist
        final toInsert = folders
            .where((f) => !existingFolderIds.contains(f.id))
            .map((folder) => NoteFolderRelationsCompanion.insert(
                  noteId: noteId,
                  noteFolderId: folder.id,
                ));

        batch.insertAll(database.noteFolderRelations, toInsert);
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to upsert note folders: $e');
      }
      return false;
    }
  }
}
