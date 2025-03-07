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

  // static Future<List<NoteFolder>> getPrepopulatedNoteFolders() async {
  //   final now = Value(DateTime.now());

  //   final database = getIt<AppDatabase>();
  //   await database.transaction(() async {
  //     for (final noteFolder in _noteFolders) {
  //       await database.into(database.noteFolders).insert(NoteFoldersCompanion(
  //             title: Value(noteFolder),
  //             createdAt: now,
  //             updatedAt: now,
  //           ));
  //     }
  //   });
  //   return database.select(database.noteFolders).get();
  // }

  static Future<List<NoteFolder>> getPrepopulatedNoteFolders() async {
    final now = Value(DateTime.now());
    final database = getIt<AppDatabase>();

    await database.batch((batch) {
      batch.insertAll(
        database.noteFolders,
        _noteFolders.map((folder) => NoteFoldersCompanion(
              title: Value(folder),
              createdAt: now,
              updatedAt: now,
            )),
      );
    });

    // Check if the note folders were populated before using shared preferences.
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setBool(kDidPopulatedNoteFolder, true);
    return database.select(database.noteFolders).get();
  }

  static Future<List<NoteFolder>> getAllNoteFolders() async {
    try {
      final database = getIt<AppDatabase>();

      // Fetch existing note folders from the database.
      final existingNoteFolders =
          await database.select(database.noteFolders).get();

      if (existingNoteFolders.isNotEmpty) {
        return existingNoteFolders;
      }

      // Check if the note folders were populated before using shared preferences.
      final sharedPreferences = await SharedPreferences.getInstance();
      final didPopulateBefore =
          sharedPreferences.getBool(kDidPopulatedNoteFolder) ?? false;

      if (didPopulateBefore) {
        return [];
      }
      // If not populated, return prepopulated note folders.
      return await getPrepopulatedNoteFolders();
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
      title: Value(text),
      createdAt: now,
      updatedAt: now,
    );

    final id = await database.into(database.noteFolders).insert(noteFolder);
    return NoteFolderDto(id: id, title: text);
  }

  // static Future<List<int>> insertNoteFolders(List<String> folders) async {
  //   List<int> folderIds = [];
  //   final database = getIt<AppDatabase>();

  //   for (var folder in folders) {
  //     final existingFolder = await (database.select(database.noteFolders)
  //           ..where((x) => x.title.equals(folder)))
  //         .getSingleOrNull();
  //     if (existingFolder == null) {
  //       throw Exception("Something Went Wrong");
  //     }

  //   }

  //   return folderIds;
  // }
}
