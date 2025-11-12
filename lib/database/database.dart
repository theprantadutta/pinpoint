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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Ensure full schema exists on fresh installs
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // App not released yet - just recreate everything
        await m.deleteTable('notes');
        await m.deleteTable('text_notes');
        await m.deleteTable('audio_notes');
        await m.deleteTable('todo_notes');
        await m.deleteTable('reminder_notes');
        await m.deleteTable('note_todo_items');
        await m.deleteTable('note_folders');
        await m.deleteTable('note_folder_relations');
        await m.deleteTable('note_attachments');
        await m.createAll();
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pinpoint',
    );
  }
}
