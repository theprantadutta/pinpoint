import 'package:drift/drift.dart';

import 'note.dart';

/// Table for storing text note specific data
/// One-to-one relationship with Notes table
@DataClassName('TextNote')
class TextNotes extends Table {
  /// Foreign key to Notes table
  /// CASCADE DELETE: When note is deleted, this text note data is also deleted
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// The actual text content of the note
  TextColumn get content => text().nullable()();

  @override
  Set<Column> get primaryKey => {noteId};
}
