import 'package:drift/drift.dart';

import 'note_folder.dart';
import 'todo_list_note_entity.dart';

/// Junction table for many-to-many relationship between todo list notes and folders
/// ARCHITECTURAL CHANGE: Links to TodoListNotes instead of base Notes table
/// MANDATORY FOLDERS: Every todo list note must have at least one folder relation
@DataClassName('TodoListNoteFolderRelationEntity')
class TodoListNoteFolderRelations extends Table {
  /// Foreign key to TodoListNotes table
  /// CASCADE DELETE: When todo list note is deleted, its folder relations are also deleted
  IntColumn get todoListNoteId =>
      integer().references(TodoListNotes, #id, onDelete: KeyAction.cascade)();

  /// Foreign key to NoteFolders table
  /// CASCADE DELETE: When folder is deleted, all note-folder relations are also deleted
  IntColumn get folderId => integer()
      .references(NoteFolders, #noteFolderId, onDelete: KeyAction.cascade)();

  /// Composite primary key: A todo list note can be in a folder only once
  @override
  Set<Column> get primaryKey => {todoListNoteId, folderId};
}
