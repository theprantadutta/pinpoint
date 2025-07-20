import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from == 1) {
          await m.addColumn(notes, notes.isArchived);
        }
        if (from == 2) {
          await m.addColumn(notes, notes.isDeleted);
        }
        if (from == 3) {
          await m.createTable(noteTags);
          await m.createTable(noteTagRelations);
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
