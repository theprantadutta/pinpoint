import 'package:drift/drift.dart';

/// Standalone table for text notes with markdown support
/// ARCHITECTURAL CHANGE: No longer extends base Notes table
/// Each note type is now completely independent
@DataClassName('TextNoteEntity')
class TextNotesV2 extends Table {
  /// Auto-incrementing primary key (for local use only)
  IntColumn get id => integer().autoIncrement()();

  /// Globally unique identifier for cross-device sync
  /// Generated using UUID v4 on creation
  TextColumn get uuid => text().unique()();

  /// Optional title for the note
  TextColumn get title => text().nullable()();

  /// Markdown content of the note
  /// Supports: **bold**, *italic*, lists, headers, code, links
  /// Stored as plain text markdown, rendered as HTML in UI
  TextColumn get content => text()();

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
