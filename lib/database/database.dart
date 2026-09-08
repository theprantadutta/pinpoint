import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'secure_database.dart';

import '../entities/note.dart';
import '../entities/note_attachments.dart';
import '../entities/note_folder.dart';
import '../entities/note_folder_relations.dart';
import '../entities/note_todo_item.dart';
import '../entities/text_note.dart';
import '../entities/audio_note.dart';
import '../entities/todo_note.dart';
import '../entities/reminder_note.dart';
// NEW ENTITIES (Architecture V8): Independent note types
import '../entities/text_note_entity.dart';
import '../entities/voice_note_entity.dart';
import '../entities/todo_list_note_entity.dart';
import '../entities/todo_item_entity.dart';
import '../entities/reminder_note_entity.dart';
import '../entities/text_note_folder_relations_entity.dart';
import '../entities/voice_note_folder_relations_entity.dart';
import '../entities/todo_list_note_folder_relations_entity.dart';
import '../entities/reminder_note_folder_relations_entity.dart';

part '../generated/database/database.g.dart';

@DriftDatabase(tables: [
  // Keep old tables for now (will be removed after full migration)
  NoteFolderRelations,
  NoteFolders,
  NoteTodoItems,
  Notes,
  NoteAttachments,
  TextNotes,
  AudioNotes,
  TodoNotes,
  ReminderNotes,
  // NEW ARCHITECTURE V8: Independent note types
  TextNotesV2,
  VoiceNotesV2,
  TodoListNotesV2,
  TodoItemsV2,
  ReminderNotesV2,
  TextNoteFolderRelationsV2,
  VoiceNoteFolderRelationsV2,
  TodoListNoteFolderRelationsV2,
  ReminderNoteFolderRelationsV2,
])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase() : super(_openConnection());

  /// Opens against [executor] instead of the on-disk encrypted database.
  ///
  /// Lets tests run the real schema — constraints included — against
  /// `NativeDatabase.memory()`.
  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Create all tables from scratch
        await m.createAll();
        debugPrint('✅ [Database] Created fresh database schema v$schemaVersion');
      },
      onUpgrade: (m, from, to) async {
        debugPrint('🔄 [Database] Upgrading from v$from to v$to');

        if (from == 7) {
          // V7 → V8: Complete architecture redesign
          // No migration logic needed - fresh start with new schema
          // Old data will be lost (acceptable for development)
          debugPrint('⚠️ [Database] This is a breaking change - all data will be reset');

          // Drop all old tables and recreate
          await m.deleteTable('notes');
          await m.deleteTable('text_notes');
          await m.deleteTable('audio_notes');
          await m.deleteTable('todo_notes');
          await m.deleteTable('note_todo_items');
          await m.deleteTable('reminder_notes');
          await m.deleteTable('note_folder_relations');
          await m.deleteTable('note_attachments');

          // Create all new tables
          await m.createAll();
          debugPrint('✅ [Database] Migration to v8 completed - fresh schema ready');
        }

        if (from == 8 && to == 9) {
          // V8 → V9: Add recurring reminder fields
          debugPrint('🔄 [Database] Adding recurring reminder fields to ReminderNotesV2');

          await m.addColumn(reminderNotesV2, reminderNotesV2.notificationTitle);
          await m.addColumn(reminderNotesV2, reminderNotesV2.notificationContent);
          await m.addColumn(reminderNotesV2, reminderNotesV2.recurrenceType);
          await m.addColumn(reminderNotesV2, reminderNotesV2.recurrenceInterval);
          await m.addColumn(reminderNotesV2, reminderNotesV2.recurrenceEndType);
          await m.addColumn(reminderNotesV2, reminderNotesV2.recurrenceEndValue);
          await m.addColumn(reminderNotesV2, reminderNotesV2.parentReminderId);
          await m.addColumn(reminderNotesV2, reminderNotesV2.occurrenceNumber);
          await m.addColumn(reminderNotesV2, reminderNotesV2.seriesId);

          // Migrate existing data: copy title to notificationTitle, description to notificationContent
          await customStatement('''
            UPDATE reminder_notes_v2
            SET notification_title = COALESCE(title, ''),
                notification_content = description
            WHERE notification_title IS NULL
          ''');

          debugPrint('✅ [Database] Migration to v9 completed - recurring reminders ready');
        }

        if (from < 10 && to >= 10) {
          // V9 → V10: Add Keep-style note color to each note type.
          debugPrint('🔄 [Database] Adding color column to note tables');
          await m.addColumn(textNotesV2, textNotesV2.color);
          await m.addColumn(todoListNotesV2, todoListNotesV2.color);
          await m.addColumn(voiceNotesV2, voiceNotesV2.color);
          await m.addColumn(reminderNotesV2, reminderNotesV2.color);
          debugPrint('✅ [Database] Migration to v10 completed - note colors ready');
        }

        if (from < 11 && to >= 11) {
          // V10 → V11: make the foreign keys real.
          //
          // Three columns referenced a parent with no ON DELETE rule at all:
          // note_attachments.note_id, note_todo_items.note_uuid and
          // todo_items_v2.todo_list_note_uuid. Rebuild those three tables from
          // the (now cascading) Dart definitions, then delete the orphans that
          // piled up over every release that ran without enforcement, so that
          // switching enforcement on below lands on a consistent database.
          debugPrint('🔄 [Database] Repairing foreign keys');

          // Redundant on this code path — drift runs migrations before
          // [MigrationStrategy.beforeOpen], so enforcement is still off — but
          // stated explicitly because alterTable rebuilds tables and would
          // corrupt references if it ever ran with foreign keys on.
          await customStatement('PRAGMA foreign_keys = OFF');

          await m.alterTable(TableMigration(noteAttachments));
          await m.alterTable(TableMigration(noteTodoItems));
          await m.alterTable(TableMigration(todoItemsV2));

          final purged = await _purgeForeignKeyViolations();
          debugPrint(
              '✅ [Database] Migration to v11 completed - $purged orphan row(s) removed');

          if (kDebugMode) {
            // The purge above is what makes enabling enforcement safe, so a
            // leftover violation here is a bug worth surfacing loudly in
            // development rather than a crash on some user's device later.
            final remaining =
                await customSelect('PRAGMA foreign_key_check').get();
            assert(
              remaining.isEmpty,
              'foreign key violations survived the v11 migration: '
              '${remaining.map((row) => row.data).take(10).toList()}',
            );
          }
        }
      },
      // Enforcement itself. SQLite defaults foreign keys to OFF on every new
      // connection, which is why years of `onDelete: KeyAction.cascade`
      // declarations never actually cascaded. Runs after any migration above.
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Deletes every row that points at a parent which no longer exists.
  ///
  /// `PRAGMA foreign_key_check` reports one row per violation as
  /// `(table, rowid, parent, fkid)` and works whether or not enforcement is
  /// on. Deleting a violating row can orphan its own children, so this repeats
  /// until the database is clean (bounded — the schema is only two levels deep).
  Future<int> _purgeForeignKeyViolations() async {
    var removed = 0;

    for (var pass = 0; pass < 5; pass++) {
      final violations = await customSelect('PRAGMA foreign_key_check').get();
      if (violations.isEmpty) break;

      for (final violation in violations) {
        final table = violation.data['table'] as String?;
        final rowId = violation.data['rowid'];
        // A WITHOUT ROWID table reports a null rowid and cannot be addressed
        // this way; none of ours are, but skip rather than throw.
        if (table == null || rowId == null) continue;

        // The table name comes from SQLite's own catalogue, not from input.
        await customStatement(
            'DELETE FROM "$table" WHERE rowid = ?', [rowId]);
        removed++;
      }
    }

    return removed;
  }

  /// Deletes every row in every table, leaving the schema intact.
  ///
  /// Used by sign-out and by account deletion. This exists as one method
  /// enumerating [allTables] because the previous approach — delete `notes`
  /// and `note_folders`, and trust the declared cascades for the rest — left
  /// note bodies, checklist items, attachments and the whole V2 note family on
  /// the device, since nothing enforced those cascades.
  ///
  /// `defer_foreign_keys` holds constraint checks until the transaction
  /// commits, by which point every table is empty. That makes the wipe
  /// independent of the order [allTables] happens to return, and independent
  /// of whether some future foreign key omits its cascade.
  Future<int> wipeAllData() async {
    var deletedRows = 0;

    await transaction(() async {
      await customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in allTables) {
        deletedRows += await delete(table).go();
      }
    });

    return deletedRows;
  }

  static QueryExecutor _openConnection() {
    // At-rest encrypted (SQLCipher) connection with no-data-loss migration of
    // any pre-existing plaintext database. See secure_database.dart.
    return openSecureDatabase();
  }
}
