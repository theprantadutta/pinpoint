import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
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

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Create all tables from scratch
        await m.createAll();
        debugPrint('✅ [Database] Created fresh database schema v9');
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
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pinpoint',
    );
  }
}
