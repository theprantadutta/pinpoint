import 'package:drift/drift.dart';

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get noteTitle => text().nullable()();
  TextColumn get defaultNoteType => text()();

  // Note Content
  TextColumn get content => text().nullable()();
  TextColumn get contentPlainText => text().nullable()();

  // Record Audio
  TextColumn get audioFilePath => text().nullable()();
  IntColumn get audioDuration => integer().nullable()();

  // Todo List Types

  // Reminder Type
  TextColumn get reminderDescription => text().nullable()();
  DateTimeColumn get reminderTime => dateTime().nullable()();

  BoolColumn get isPinned => boolean().withDefault(Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
