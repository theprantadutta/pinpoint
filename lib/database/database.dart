import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pinpoint/services/logger_service.dart';

import '../entities/note.dart';
import '../entities/note_attachments.dart';
import '../entities/note_folder.dart';
import '../entities/note_folder_relations.dart';
import '../entities/note_todo_item.dart';
import '../entities/note_tags.dart';
import '../entities/note_tag_relations.dart';

part '../generated/database/database.g.dart';

@DriftDatabase(tables: [
  NoteFolderRelations,
  NoteFolders,
  NoteTodoItems,
  Notes,
  NoteAttachments,
  NoteTags,
  NoteTagRelations,
])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Ensure full schema exists on fresh installs
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // Apply incremental migrations based on current version.
        // Use <= checks to support users skipping versions.
        if (from <= 1) {
          await m.addColumn(notes, notes.isArchived);
        }
        if (from <= 2) {
          await m.addColumn(notes, notes.isDeleted);
        }
        if (from <= 3) {
          // Create new tables added in schema v4
          await m.createTable(noteTags);
          await m.createTable(noteTagRelations);
        }
      },
      beforeOpen: (details) async {
        // When adding new tables to an existing database, some environments
        // may still not have them due to past failed migrations. Guard-create.
        if (details.wasCreated) return;

        // Create noteTags if it doesn't exist
        try {
          await customStatement(
              'CREATE TABLE IF NOT EXISTS note_tags (id INTEGER PRIMARY KEY AUTOINCREMENT, tag_title TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
          log.d('[DB] ensured table note_tags exists');
        } catch (e, st) {
          log.w('[DB] guard-create note_tags failed', e, st);
        }
        // Create relation table if it doesn't exist
        try {
          await customStatement(
              'CREATE TABLE IF NOT EXISTS note_tag_relations (id INTEGER PRIMARY KEY AUTOINCREMENT, note_id INTEGER NOT NULL, tag_id INTEGER NOT NULL)');
          log.d('[DB] ensured table note_tag_relations exists');
        } catch (e, st) {
          log.w('[DB] guard-create note_tag_relations failed', e, st);
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pinpoint',
    );
  }
}
