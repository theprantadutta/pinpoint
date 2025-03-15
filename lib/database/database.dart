import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../entities/note.dart';
import '../entities/note_attachments.dart';
import '../entities/note_folder.dart';
import '../entities/note_folder_relations.dart';
import '../entities/note_todo_item.dart';

part '../generated/database/database.g.dart';

@DriftDatabase(tables: [
  NoteFolderRelations,
  NoteFolders,
  NoteTodoItems,
  Notes,
  NoteAttachments,
])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pinpoint',
    );
  }
}
