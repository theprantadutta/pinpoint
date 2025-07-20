import 'package:drift/drift.dart';

class NoteTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tagTitle => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
