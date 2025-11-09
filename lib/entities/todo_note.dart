import 'package:drift/drift.dart';

import 'note.dart';

/// Table for storing todo list note specific data
/// One-to-one relationship with Notes table
/// Individual todo items are stored in TodoItems table (one-to-many)
@DataClassName('TodoNote')
class TodoNotes extends Table {
  /// Foreign key to Notes table
  /// CASCADE DELETE: When note is deleted, this todo note data is also deleted
  IntColumn get noteId => integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// Optional description/header for the todo list
  TextColumn get description => text().nullable()();

  /// Total number of todo items
  IntColumn get totalItems => integer().withDefault(const Constant(0))();

  /// Number of completed items
  IntColumn get completedItems => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {noteId};
}
