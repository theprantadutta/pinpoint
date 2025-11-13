import 'package:drift/drift.dart';

/// Base table for all notes
/// Contains only common fields shared across all note types
/// Type-specific data is stored in separate tables (TextNotes, AudioNotes, TodoNotes, ReminderNotes)
@DataClassName('Note')
class Notes extends Table {
  /// Auto-incrementing primary key (for local use only)
  IntColumn get id => integer().autoIncrement()();

  /// Globally unique identifier for sync
  /// This UUID is generated on the client and used for cross-device sync
  TextColumn get uuid => text().unique()();

  /// Optional title for the note
  TextColumn get noteTitle => text().nullable()();

  /// The type of note (text, audio, todo, reminder)
  /// Stored as string for compatibility with NoteType enum
  TextColumn get noteType => text()();

  /// Whether the note is pinned to the top of the list
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Whether the note is archived (hidden from main view)
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Whether the note is deleted (soft delete)
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Whether the note has been synced to the cloud
  /// false = needs upload, true = successfully uploaded
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// When the note was created
  DateTimeColumn get createdAt => dateTime()();

  /// When the note was last updated
  DateTimeColumn get updatedAt => dateTime()();
}
