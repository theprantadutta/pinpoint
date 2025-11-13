import 'package:drift/drift.dart';

import 'note.dart';

/// Table for storing individual todo items
/// Many-to-one relationship with Notes table (through TodoNotes)
/// Each todo item belongs to a single note, a note can have multiple todo items
@DataClassName('NoteTodoItem')
class NoteTodoItems extends Table {
  /// Auto-incrementing primary key (for local use only)
  IntColumn get id => integer().autoIncrement()();

  /// Globally unique identifier for sync
  TextColumn get uuid => text().unique()();

  /// Foreign key to Notes table (local reference)
  /// CASCADE DELETE: When note is deleted, all its todo items are also deleted
  /// Note: This references Notes.id directly, which is the same as TodoNotes.noteId
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// Parent note UUID (for sync)
  /// This references the parent note's UUID for cross-device sync
  TextColumn get noteUuid => text().references(Notes, #uuid)();

  /// The text content of the todo item
  TextColumn get todoTitle => text()();

  /// Whether this todo item is marked as completed
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  /// Order/position of this item in the list (for drag-and-drop reordering)
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
}
