import 'package:drift/drift.dart';

import 'note.dart';

class NoteTodoListType extends Table {
  IntColumn get id => integer().references(Notes, #id)(); // FK to Notes.id
}
