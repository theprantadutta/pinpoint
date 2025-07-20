import 'package:drift/drift.dart';

import 'note.dart';
import 'note_tags.dart';

class NoteTagRelations extends Table {
  IntColumn get noteId => integer().references(Notes, #id)();
  IntColumn get tagId => integer().references(NoteTags, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}
