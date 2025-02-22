import 'package:drift/drift.dart';

import 'note.dart';

class NoteReminderTypes extends Table {
  IntColumn get id => integer().references(Notes, #id)(); // FK to Notes.id
  TextColumn get description => text().nullable()();
  DateTimeColumn get reminderTime => dateTime()();
}
