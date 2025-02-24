import 'package:drift/drift.dart';

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get noteTypes => text()();

  // Note Content
  TextColumn get content => text().nullable()();

  // Record Audio
  TextColumn get filePath => text().nullable()();
  IntColumn get duration => integer().nullable()();

  // Todo List Types

  // Reminder Type
  TextColumn get description => text().nullable()();
  DateTimeColumn get reminderTime => dateTime().nullable()();

  BoolColumn get isPinned => boolean().withDefault(Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
