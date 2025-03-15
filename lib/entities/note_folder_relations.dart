import 'package:drift/drift.dart';

import 'note.dart';
import 'note_folder.dart';

/// Junction table for many-to-many relation
class NoteFolderRelations extends Table {
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  IntColumn get noteFolderId => integer()
      .references(NoteFolders, #noteFolderId, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey =>
      {noteId, noteFolderId}; // Composite primary key to ensure uniqueness
}
