import 'package:drift/drift.dart';

import 'note.dart';

/// Table for storing reminder note specific data
/// One-to-one relationship with Notes table
@DataClassName('ReminderNote')
class ReminderNotes extends Table {
  /// Foreign key to Notes table
  /// CASCADE DELETE: When note is deleted, this reminder note data is also deleted
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// The date and time when the reminder should trigger
  DateTimeColumn get reminderTime => dateTime()();

  /// Optional description/message for the reminder
  TextColumn get description => text().nullable()();

  /// Whether the reminder has been triggered/shown
  BoolColumn get isTriggered => boolean().withDefault(const Constant(false))();

  /// Whether the reminder is recurring
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();

  /// Recurrence pattern (daily, weekly, monthly, etc.) - stored as JSON string
  TextColumn get recurrencePattern => text().nullable()();

  @override
  Set<Column> get primaryKey => {noteId};
}
