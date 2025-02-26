import 'package:drift/drift.dart';
import 'package:pinpoint/entities/note.dart';

class NoteAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)(); // FK to Note.id
  TextColumn get name => text()();
  TextColumn get path => text()();
  TextColumn get mimeType => text().nullable()();
}
