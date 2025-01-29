import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/shared_preference_keys.dart';
import '../database/database.dart';
import '../service_locators/init_service_locators.dart';

class DriftNoteFolderService {
  DriftNoteFolderService._();

  static final _noteFolders = ['HomeWork', 'Workout', 'Office', 'Sports'];

  static List<NoteFolder> getPrepopulatedNoteFolders() {
    final now = DateTime.now();

    // Use `map` for a cleaner and functional style, with indexing handled properly.
    return List.generate(
      _noteFolders.length,
      (index) => NoteFolder(
        id: index + 1,
        title: _noteFolders[index],
        createdAt: now,
        updatedAt: now,
      ),
    );
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
      return getPrepopulatedNoteFolders();
    } catch (e) {
      // Log the error if in debug mode.
      if (kDebugMode) {
        print('Something went wrong when getting note folders: $e');
      }
      // Rethrow the exception to handle it in the calling function.
      rethrow;
    }
  }
}
