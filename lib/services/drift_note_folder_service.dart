import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/shared_preference_keys.dart';
import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../service_locators/init_service_locators.dart';

/// Thrown when a folder title is already taken.
///
/// `NoteFolders.noteFolderTitle` is `UNIQUE`, so violating it raises a raw
/// `SqliteException(2067)` that, left alone, reaches Crashlytics as a fatal
/// error. Callers get this instead: an expected, presentable outcome.
class FolderTitleTakenException implements Exception {
  const FolderTitleTakenException(this.title);

  final String title;

  @override
  String toString() => 'FolderTitleTakenException: "$title" is already used';
}

class DriftNoteFolderService {
  DriftNoteFolderService._();

  /// Whether a raw database error is the folder-title uniqueness violation.
  ///
  /// Matched on the message rather than by importing `sqlite3` for its
  /// exception type: the message carries the offending column, so this cannot
  /// mistake a different UNIQUE index (`uuid`, say) for this one.
  static bool _isDuplicateTitle(Object error) {
    final text = error.toString();
    return text.contains('UNIQUE constraint failed') &&
        text.contains('note_folders.note_folder_title');
  }

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
    const uuid = Uuid();

    // CRITICAL: Use deterministic UUIDs based on folder name
    // This ensures the same folder name always gets the same UUID across devices/reinstalls
    // Using UUID v5 with a namespace ensures consistency
    const folderNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'; // UUID namespace for folders

    await database.batch(
      (batch) {
        batch.insertAll(
          database.noteFolders,
          _noteFolders.map(
            (folder) => NoteFoldersCompanion(
              uuid: Value(uuid.v5(folderNamespace, folder)), // Deterministic UUID from folder name
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

  /// Whether [title] is already used, ignoring case.
  ///
  /// The database is the only authority here. Callers used to check a list of
  /// folders they were holding, which goes stale the moment a folder arrives
  /// from sync or is created on another screen — and the insert then died on
  /// the UNIQUE index.
  ///
  /// Note the deliberate mismatch with SQLite: the column's UNIQUE index uses
  /// BINARY collation and so treats "Work" and "work" as different, while the
  /// app treats them as the same folder. This check is the stricter of the two,
  /// which is what users expect.
  static Future<bool> isTitleTaken(String title, {int? excludingId}) async {
    final database = getIt<AppDatabase>();
    final query = database.select(database.noteFolders)
      ..where((tbl) => tbl.noteFolderTitle.lower().equals(title.toLowerCase()));
    if (excludingId != null) {
      query.where((tbl) => tbl.noteFolderId.equals(excludingId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  /// Creates a folder.
  ///
  /// Throws [FolderTitleTakenException] if the title is in use.
  static Future<NoteFolderDto> insertNoteFolder(String text) async {
    final database = getIt<AppDatabase>();

    if (await isTitleTaken(text)) {
      throw FolderTitleTakenException(text);
    }

    final now = Value(DateTime.now());
    const uuid = Uuid();
    final noteFolder = NoteFoldersCompanion(
      uuid: Value(uuid.v4()),
      noteFolderTitle: Value(text),
      createdAt: now,
      updatedAt: now,
    );

    try {
      final id = await database.into(database.noteFolders).insert(noteFolder);
      return NoteFolderDto(id: id, title: text);
    } catch (e) {
      // The check above closes the common case; this closes the race, where a
      // sync writes the same title between the check and the insert.
      if (_isDuplicateTitle(e)) throw FolderTitleTakenException(text);
      rethrow;
    }
  }

  /// Renames a folder.
  ///
  /// Throws [FolderTitleTakenException] if another folder already uses
  /// [newTitle]. Renaming a folder to a different casing of its own title is
  /// allowed.
  static Future<void> renameFolder(int folderId, String newTitle) async {
    final database = getIt<AppDatabase>();

    if (await isTitleTaken(newTitle, excludingId: folderId)) {
      throw FolderTitleTakenException(newTitle);
    }

    try {
      await (database.update(database.noteFolders)
            ..where((tbl) => tbl.noteFolderId.equals(folderId)))
          .write(NoteFoldersCompanion(noteFolderTitle: Value(newTitle)));
    } catch (e) {
      if (_isDuplicateTitle(e)) throw FolderTitleTakenException(newTitle);
      rethrow;
    }
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

  /// Narrows [folders] to the ones that still exist in `note_folders`.
  ///
  /// Folder pickers hold a list read earlier in the session, so a folder
  /// deleted in the meantime leaves a stale id behind. While foreign keys went
  /// unenforced that produced a dangling relation row nobody ever rendered
  /// (every read inner-joins the folder). Now it would fail the note save
  /// outright, so drop the stale entries instead and keep saving.
  static Future<List<NoteFolderDto>> existingFolders(
      List<NoteFolderDto> folders) async {
    if (folders.isEmpty) return folders;

    final database = getIt<AppDatabase>();
    final ids = folders.map((f) => f.id).toList();
    final live = await (database.select(database.noteFolders)
          ..where((f) => f.noteFolderId.isIn(ids)))
        .get();
    final liveIds = live.map((f) => f.noteFolderId).toSet();

    return folders.where((f) => liveIds.contains(f.id)).toList();
  }

  static Future<bool> upsertNoteFoldersWithNote(
      List<NoteFolderDto> foldersRequested, int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      final folders = await existingFolders(foldersRequested);

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
