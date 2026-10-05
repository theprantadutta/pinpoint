import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/shared_preference_keys.dart';
import '../database/database.dart';
import '../dtos/note_folder_dto.dart';
import '../models/folder_summary.dart';
import '../service_locators/init_service_locators.dart';
import '../util/folder_palette.dart';

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
    const folderNamespace =
        '6ba7b810-9dad-11d1-80b4-00c04fd430c8'; // UUID namespace for folders

    await database.batch(
      (batch) {
        batch.insertAll(
          database.noteFolders,
          _noteFolders.map(
            (folder) => NoteFoldersCompanion(
              uuid: Value(uuid.v5(folderNamespace,
                  folder)), // Deterministic UUID from folder name
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
    final existing = await database.select(database.noteFolders).get();
    final noteFolder = NoteFoldersCompanion(
      uuid: Value(uuid.v4()),
      noteFolderTitle: Value(text),
      createdAt: now,
      updatedAt: now,
      // New folders take the next pastel in the round-robin.
      color: Value(FolderPalette.nameForNewFolder(existing.length)),
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
          .write(NoteFoldersCompanion(
        noteFolderTitle: Value(newTitle),
        // Folder sync is last-write-wins on updatedAt; without the bump a
        // rename never reached the server.
        updatedAt: Value(DateTime.now()),
      ));
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

  // ============================================
  // Sketchbook: live folders, colours, order
  // ============================================

  /// Every folder, re-emitted on each change (unlike
  /// [watchAllNoteFoldersStream], which reads once).
  static Stream<List<NoteFolder>> watchFolders() {
    final database = getIt<AppDatabase>();
    return database.select(database.noteFolders).watch();
  }

  /// Sets a folder's pastel ('yellow' | 'lavender' | 'mint' | 'sky' | 'pink').
  static Future<void> setFolderColor(int folderId, String colorName) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.noteFolders)
          ..where((tbl) => tbl.noteFolderId.equals(folderId)))
        .write(NoteFoldersCompanion(
      color: Value(colorName),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Persists a manual order: [orderedIds] first to last.
  static Future<void> setFolderOrder(List<int> orderedIds) async {
    final database = getIt<AppDatabase>();
    final now = DateTime.now();
    await database.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          database.noteFolders,
          NoteFoldersCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          where: (tbl) => tbl.noteFolderId.equals(orderedIds[i]),
        );
      }
    });
  }

  /// One row per (folder, live note). Text and reminder notes fall back to
  /// the start of their body when they have no title.
  static const String _folderNotesSql = '''
      SELECT r.folder_id AS folder_id, n.id AS note_id, 'text' AS type,
             COALESCE(NULLIF(TRIM(n.title), ''), SUBSTR(n.content, 1, 80)) AS title,
             n.color AS color, n.updated_at AS updated_at
        FROM text_note_folder_relations_v2 r
        JOIN text_notes_v2 n ON n.id = r.text_note_id
       WHERE n.is_archived = 0 AND n.is_deleted = 0
      UNION ALL
      SELECT r.folder_id, n.id, 'voice', COALESCE(n.title, ''), n.color, n.updated_at
        FROM voice_note_folder_relations_v2 r
        JOIN voice_notes_v2 n ON n.id = r.voice_note_id
       WHERE n.is_archived = 0 AND n.is_deleted = 0
      UNION ALL
      SELECT r.folder_id, n.id, 'todo', COALESCE(n.title, ''), n.color, n.updated_at
        FROM todo_list_note_folder_relations_v2 r
        JOIN todo_list_notes_v2 n ON n.id = r.todo_list_note_id
       WHERE n.is_archived = 0 AND n.is_deleted = 0
      UNION ALL
      SELECT r.folder_id, n.id, 'reminder',
             COALESCE(NULLIF(TRIM(n.title), ''), SUBSTR(n.description, 1, 80)),
             n.color, n.updated_at
        FROM reminder_note_folder_relations_v2 r
        JOIN reminder_notes_v2 n ON n.id = r.reminder_note_id
       WHERE n.is_archived = 0 AND n.is_deleted = 0
      ORDER BY updated_at DESC
  ''';

  /// Folders in display order, each with its colour, live note counts and
  /// its most recently edited notes. Re-emits whenever a folder, a note or a
  /// folder membership changes.
  static Stream<List<FolderSummary>> watchFolderSummaries() {
    final database = getIt<AppDatabase>();

    final rows = database.customSelect(_folderNotesSql, readsFrom: {
      database.textNotesV2,
      database.voiceNotesV2,
      database.todoListNotesV2,
      database.reminderNotesV2,
      database.textNoteFolderRelationsV2,
      database.voiceNoteFolderRelationsV2,
      database.todoListNoteFolderRelationsV2,
      database.reminderNoteFolderRelationsV2,
    }).watch();
    final folders = watchFolders();

    // Combine the two live queries: recompute when either emits.
    late StreamController<List<FolderSummary>> controller;
    List<NoteFolder>? latestFolders;
    List<QueryRow>? latestRows;
    StreamSubscription<List<NoteFolder>>? folderSub;
    StreamSubscription<List<QueryRow>>? rowSub;

    void emit() {
      final f = latestFolders, r = latestRows;
      if (f == null || r == null) return;
      controller.add(buildSummaries(f, r.map(FolderNoteRow.fromQueryRow)));
    }

    controller = StreamController<List<FolderSummary>>(
      onListen: () {
        folderSub = folders.listen((v) {
          latestFolders = v;
          emit();
        }, onError: controller.addError);
        rowSub = rows.listen((v) {
          latestRows = v;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await folderSub?.cancel();
        await rowSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Groups [rows] (newest first) under [folders]. Pure, for testing.
  @visibleForTesting
  static List<FolderSummary> buildSummaries(
      List<NoteFolder> folders, Iterable<FolderNoteRow> rows) {
    final colors = FolderPalette.resolve(folders);
    final counts = <int, int>{};
    final voices = <int, int>{};
    final recent = <int, List<FolderNotePreview>>{};

    for (final row in rows) {
      counts[row.folderId] = (counts[row.folderId] ?? 0) + 1;
      if (row.type == 'voice') {
        voices[row.folderId] = (voices[row.folderId] ?? 0) + 1;
      }
      final list = recent.putIfAbsent(row.folderId, () => []);
      if (list.length < FolderSummary.previewLimit) {
        list.add(FolderNotePreview(
          noteId: row.noteId,
          type: row.type,
          title: row.title.split('\n').first.trim(),
          color: FolderPalette.forNote(colorName: row.color, type: row.type),
        ));
      }
    }

    return [
      for (final f in FolderPalette.ordered(folders))
        FolderSummary(
          folder: f,
          color: colors[f.noteFolderId]!,
          noteCount: counts[f.noteFolderId] ?? 0,
          voiceCount: voices[f.noteFolderId] ?? 0,
          recent: recent[f.noteFolderId] ?? const [],
        ),
    ];
  }
}

/// A row of [DriftNoteFolderService._folderNotesSql].
class FolderNoteRow {
  const FolderNoteRow({
    required this.folderId,
    required this.noteId,
    required this.type,
    required this.title,
    this.color,
  });

  factory FolderNoteRow.fromQueryRow(QueryRow row) => FolderNoteRow(
        folderId: row.read<int>('folder_id'),
        noteId: row.read<int>('note_id'),
        type: row.read<String>('type'),
        title: row.readNullable<String>('title') ?? '',
        color: row.readNullable<String>('color'),
      );

  final int folderId;
  final int noteId;
  final String type;
  final String title;
  final String? color;
}
