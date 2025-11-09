import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../entities/note.dart';
import '../entities/note_attachments.dart';
import '../entities/note_folder.dart';
import '../entities/note_folder_relations.dart';
import '../entities/note_todo_item.dart';
import '../entities/text_note.dart';
import '../entities/audio_note.dart';
import '../entities/todo_note.dart';
import '../entities/reminder_note.dart';

part '../generated/database/database.g.dart';

@DriftDatabase(tables: [
  NoteFolderRelations,
  NoteFolders,
  NoteTodoItems,
  Notes,
  NoteAttachments,
  TextNotes,
  AudioNotes,
  TodoNotes,
  ReminderNotes,
])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

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
          // Schema v4 migration - tags removed
        }
        if (from <= 4) {
          // Schema v5 migration - Restructure to table-per-type pattern
          await _migrateToSchemaV5(m);

          // Fix note_type values: convert display names to database enum values
          await _fixNoteTypeValues();
        }
      },
    );
  }

  /// Fix note_type values to use database enum values instead of display names
  Future<void> _fixNoteTypeValues() async {
    await customStatement("UPDATE notes SET note_type = 'text' WHERE note_type = 'Title Content'");
    await customStatement("UPDATE notes SET note_type = 'audio' WHERE note_type = 'Record Audio'");
    await customStatement("UPDATE notes SET note_type = 'todo' WHERE note_type = 'Todo List'");
    await customStatement("UPDATE notes SET note_type = 'reminder' WHERE note_type = 'Reminder'");
  }

  /// Migrate from schema v4 to v5
  /// This restructures the database from a single Notes table with all fields
  /// to a base Notes table + type-specific tables
  Future<void> _migrateToSchemaV5(Migrator m) async {
    // Step 1: Create new type-specific tables
    await m.createTable(textNotes);
    await m.createTable(audioNotes);
    await m.createTable(todoNotes);
    await m.createTable(reminderNotes);

    // Step 2: Add orderIndex column to NoteTodoItems
    await m.addColumn(noteTodoItems, noteTodoItems.orderIndex);

    // Step 3: Migrate existing data to new tables
    // Use raw SQL to access old columns that no longer exist in the new schema
    final existingNotes = await customSelect(
      'SELECT id, defaultNoteType, content, contentPlainText, audioFilePath, '
      'audioDuration, reminderDescription, reminderTime, createdAt FROM notes',
      readsFrom: {notes},
    ).get();

    for (final row in existingNotes) {
      final noteId = row.read<int>('id');
      final noteType = row.read<String>('defaultNoteType');

      // Migrate based on note type
      if (noteType == 'text' || noteType == 'Text') {
        // Migrate text note data
        final content = row.readNullable<String>('content');
        await customInsert(
          'INSERT INTO text_notes (note_id, content) VALUES (?, ?)',
          variables: [Variable.withInt(noteId), Variable(content)],
        );
      } else if (noteType == 'audio' || noteType == 'Audio') {
        // Migrate audio note data
        final audioFilePath = row.readNullable<String>('audioFilePath');
        final audioDuration = row.readNullable<int>('audioDuration');
        final createdAt = row.read<DateTime>('createdAt');

        if (audioFilePath != null) {
          await customInsert(
            'INSERT INTO audio_notes (note_id, audio_file_path, duration_seconds, recorded_at) '
            'VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withInt(noteId),
              Variable.withString(audioFilePath),
              Variable(audioDuration),
              Variable.withDateTime(createdAt),
            ],
          );
        }
      } else if (noteType == 'todo' || noteType == 'Todo') {
        // Migrate todo note data
        // Count existing todo items for this note
        final todoItemsResult = await customSelect(
          'SELECT COUNT(*) as total, SUM(CASE WHEN is_done = 1 THEN 1 ELSE 0 END) as completed '
          'FROM note_todo_items WHERE note_id = ?',
          variables: [Variable.withInt(noteId)],
        ).getSingle();

        final totalItems = todoItemsResult.read<int>('total');
        final completedItems = todoItemsResult.readNullable<int>('completed') ?? 0;

        await customInsert(
          'INSERT INTO todo_notes (note_id, total_items, completed_items) VALUES (?, ?, ?)',
          variables: [
            Variable.withInt(noteId),
            Variable.withInt(totalItems),
            Variable.withInt(completedItems),
          ],
        );
      } else if (noteType == 'reminder' || noteType == 'Reminder') {
        // Migrate reminder note data
        final reminderTime = row.readNullable<DateTime>('reminderTime');
        final reminderDescription = row.readNullable<String>('reminderDescription');

        if (reminderTime != null) {
          await customInsert(
            'INSERT INTO reminder_notes (note_id, reminder_time, description, is_triggered, is_recurring) '
            'VALUES (?, ?, ?, 0, 0)',
            variables: [
              Variable.withInt(noteId),
              Variable.withDateTime(reminderTime),
              Variable(reminderDescription),
            ],
          );
        }
      }
    }

    // Step 4: Rename defaultNoteType column to noteType in Notes table
    // SQLite doesn't support renaming columns directly in old versions
    // We need to use ALTER TABLE
    await customStatement('ALTER TABLE notes RENAME COLUMN default_note_type TO note_type');

    // Step 5: Drop old columns from Notes table
    // Note: SQLite doesn't support DROP COLUMN before version 3.35.0
    // We need to recreate the table with only the new columns

    // Create temporary table with new schema
    await customStatement('''
      CREATE TABLE notes_new (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        note_title TEXT,
        note_type TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Copy data to new table
    await customStatement('''
      INSERT INTO notes_new (id, note_title, note_type, is_pinned, is_archived, is_deleted, created_at, updated_at)
      SELECT id, note_title, note_type, is_pinned, is_archived, is_deleted, created_at, updated_at
      FROM notes
    ''');

    // Drop old table
    await customStatement('DROP TABLE notes');

    // Rename new table to original name
    await customStatement('ALTER TABLE notes_new RENAME TO notes');
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pinpoint',
    );
  }
}
