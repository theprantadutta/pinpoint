import 'package:drift/drift.dart';

/// Standalone table for reminder notes
/// ARCHITECTURAL CHANGE: No longer extends base Notes table
/// Each note type is now completely independent
@DataClassName('ReminderNoteEntity')
class ReminderNotesV2 extends Table {
  /// Auto-incrementing primary key (for local use only)
  IntColumn get id => integer().autoIncrement()();

  /// Globally unique identifier for cross-device sync
  /// Generated using UUID v4 on creation
  TextColumn get uuid => text().unique()();

  /// Optional title for the reminder (for app organization)
  TextColumn get title => text().nullable()();

  /// Title shown in the push notification
  TextColumn get notificationTitle => text().nullable()();

  /// Content/body shown in the push notification
  TextColumn get notificationContent => text().nullable()();

  /// When the reminder should trigger/notify the user
  DateTimeColumn get reminderTime => dateTime()();

  /// Optional description (deprecated, use notificationContent)
  TextColumn get description => text().nullable()();

  // Recurrence fields
  /// Type of recurrence: once, hourly, daily, weekly, monthly, yearly
  TextColumn get recurrenceType =>
      text().withDefault(const Constant('once'))();

  /// Interval for recurrence (e.g., every 2 days)
  IntColumn get recurrenceInterval => integer().withDefault(const Constant(1))();

  /// How the recurrence ends: never, after_occurrences, on_date
  TextColumn get recurrenceEndType =>
      text().withDefault(const Constant('never'))();

  /// Value for end condition (number of occurrences or ISO date string)
  TextColumn get recurrenceEndValue => text().nullable()();

  /// Link to parent reminder (for series tracking)
  TextColumn get parentReminderId => text().nullable()();

  /// Which occurrence in the series (1, 2, 3...)
  IntColumn get occurrenceNumber => integer().withDefault(const Constant(1))();

  /// UUID to group all occurrences of same recurring reminder
  TextColumn get seriesId => text().nullable()();

  /// Whether the reminder has already been triggered/shown to the user
  /// false = pending, true = already notified
  BoolColumn get isTriggered => boolean().withDefault(const Constant(false))();

  /// Whether the note is pinned to the top of the list
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Whether the note is archived (hidden from main view)
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Whether the note is deleted (soft delete)
  /// Deleted notes appear only in trash, not in main views
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Whether the note has been synced to the cloud
  /// false = needs upload, true = successfully uploaded
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// When the note was created
  DateTimeColumn get createdAt => dateTime()();

  /// When the note was last updated
  DateTimeColumn get updatedAt => dateTime()();
}
