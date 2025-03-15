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

  static get firstNoteFolder {
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

  static Future<bool> insertNoteFoldersWithNote(
      List<NoteFolderDto> folders, int noteId) async {
    try {
      final database = getIt<AppDatabase>();

      await database.batch((batch) {
        batch.insertAll(
          database.noteFolderRelations,
          folders
              .map((folder) => NoteFolderRelationsCompanion.insert(
                    noteId: noteId,
                    noteFolderId: folder.id,
                  ))
              .toList(),
        );
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Something went wrong when inserting note folders: $e');
      }
      return false;
    }
  }
}
