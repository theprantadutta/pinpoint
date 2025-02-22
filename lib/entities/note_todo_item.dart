import 'package:drift/drift.dart';

import 'note_todo_list_type.dart';

class NoteTodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer()
      .references(NoteTodoListTypes, #id)(); // FK to NoteTodoListType.id
  TextColumn get title => text()();
  BoolColumn get isDone => boolean().withDefault(Constant(false))();
}
