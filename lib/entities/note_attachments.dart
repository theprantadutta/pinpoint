import 'package:drift/drift.dart';
import 'package:pinpoint/entities/note.dart';

class NoteAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)(); // FK to Note.id
  TextColumn get attachmentName => text()();
  TextColumn get attachmentPath => text()();
  TextColumn get attachmentMimeType => text().nullable()();
}
