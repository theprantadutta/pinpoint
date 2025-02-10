import 'package:drift/drift.dart';

import 'note.dart';
import 'note_folder.dart';

/// Junction table for many-to-many relation
class NoteFolderRelations extends Table {
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  IntColumn get folderId =>
      integer().references(NoteFolders, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey =>
      {noteId, folderId}; // Composite primary key to ensure uniqueness
}
