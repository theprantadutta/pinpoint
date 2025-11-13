import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Ensure full schema exists on fresh installs
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // Migration from v6 to v7: Add UUID columns
        if (from < 7) {
          debugPrint('🔄 [Database Migration] Migrating from v$from to v$to');
          await _migrateToV7(m);
        }
      },
    );
  }

  /// Migrate from v6 to v7: Add UUID support
  Future<void> _migrateToV7(Migrator m) async {
    debugPrint('📦 [Database Migration] Adding UUID columns...');

    // Step 1: Add UUID columns to all tables
    await m.addColumn(notes, notes.uuid);
    await m.addColumn(noteFolders, noteFolders.uuid);
    await m.addColumn(noteTodoItems, noteTodoItems.uuid);
    await m.addColumn(noteTodoItems, noteTodoItems.noteUuid);

    debugPrint('✅ [Database Migration] UUID columns added');

    // Step 2: Backfill UUIDs for existing records
    await _backfillUuids();

    debugPrint('✅ [Database Migration] Migration to v7 completed');
  }

  /// Backfill UUIDs for all existing records
  Future<void> _backfillUuids() async {
    final uuid = const Uuid();
    debugPrint('🔄 [Database Migration] Backfilling UUIDs...');

    // Backfill notes
    final existingNotes = await select(notes).get();
    debugPrint('   - Backfilling ${existingNotes.length} notes');

    for (final note in existingNotes) {
      final noteUuid = uuid.v4();
      await (update(notes)..where((t) => t.id.equals(note.id)))
          .write(NotesCompanion(uuid: Value(noteUuid)));

      // Also update todo items that belong to this note
      await (update(noteTodoItems)..where((t) => t.noteId.equals(note.id)))
          .write(NoteTodoItemsCompanion(noteUuid: Value(noteUuid)));
    }

    // Backfill folders
    final existingFolders = await select(noteFolders).get();
    debugPrint('   - Backfilling ${existingFolders.length} folders');

    for (final folder in existingFolders) {
      await (update(noteFolders)
            ..where((t) => t.noteFolderId.equals(folder.noteFolderId)))
          .write(NoteFoldersCompanion(uuid: Value(uuid.v4())));
    }

    // Backfill todo items (assign their own UUIDs)
    final existingTodos = await select(noteTodoItems).get();
    debugPrint('   - Backfilling ${existingTodos.length} todo items');

    for (final todo in existingTodos) {
      // Only update if UUID is null (might have been updated with parent note)
      if (todo.uuid.isEmpty) {
        await (update(noteTodoItems)..where((t) => t.id.equals(todo.id)))
            .write(NoteTodoItemsCompanion(uuid: Value(uuid.v4())));
      }
    }

    debugPrint('✅ [Database Migration] UUID backfill completed');
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pinpoint',
    );
  }
}
