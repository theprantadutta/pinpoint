import 'package:drift/drift.dart';

import 'todo_list_note_entity.dart';

/// Table for individual todo items within a todo list note
/// Many-to-one relationship with TodoListNotesV2
/// ARCHITECTURAL CHANGE: Now references TodoListNotesV2 instead of base Notes table
@DataClassName('TodoItemEntity')
class TodoItemsV2 extends Table {
  /// Auto-incrementing primary key (for local use only)
  IntColumn get id => integer().autoIncrement()();

  /// Globally unique identifier for cross-device sync
  /// Generated using UUID v4 on creation
  TextColumn get uuid => text().unique()();

  /// Foreign key to TodoListNotesV2 table (local ID)
  /// CASCADE DELETE: When todo list note is deleted, all its items are also deleted
  IntColumn get todoListNoteId =>
      integer().references(TodoListNotesV2, #id, onDelete: KeyAction.cascade)();

  /// Foreign key to TodoListNotesV2 table (UUID for sync)
  /// Used for cross-device sync to link items to their parent todo list
  TextColumn get todoListNoteUuid =>
      text().references(TodoListNotesV2, #uuid)();

  /// The text content of this todo item
  TextColumn get title => text()();

  /// Whether this todo item is completed
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  /// Display order within the todo list
  /// Lower numbers appear first (0, 1, 2, ...)
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}
