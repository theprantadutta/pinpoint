import 'package:drift/drift.dart';

import 'note.dart';
import 'note_tags.dart';

/// Not registered in `AppDatabase`, so no such table exists on any device.
/// The cascades are declared anyway so that registering it later cannot
/// reintroduce the orphan-row problem schema v11 fixed.
class NoteTagRelations extends Table {
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(NoteTags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}
