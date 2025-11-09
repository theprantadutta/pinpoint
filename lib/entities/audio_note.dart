import 'package:drift/drift.dart';

import 'note.dart';

/// Table for storing audio/voice note specific data
/// One-to-one relationship with Notes table
@DataClassName('AudioNote')
class AudioNotes extends Table {
  /// Foreign key to Notes table
  /// CASCADE DELETE: When note is deleted, this audio note data is also deleted
  IntColumn get noteId => integer().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// Path to the audio file (local storage or cloud URL)
  TextColumn get audioFilePath => text()();

  /// Duration of the audio in seconds
  IntColumn get durationSeconds => integer().nullable()();

  /// Transcription of the audio (optional, for search)
  TextColumn get transcription => text().nullable()();

  /// Recording timestamp
  DateTimeColumn get recordedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {noteId};
}
