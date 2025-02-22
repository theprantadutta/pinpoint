import 'package:drift/drift.dart';

import 'note.dart';

class NoteTitleContentTypes extends Table {
  IntColumn get id => integer().references(Notes, #id)(); // FK to Notes.id
  TextColumn get content => text().nullable()();
}
