import 'package:drift/drift.dart';

import 'note.dart';

class NoteTodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)(); // FK to Note.id
  TextColumn get title => text()();
  BoolColumn get isDone => boolean().withDefault(Constant(false))();
}
