import 'package:drift/drift.dart';
import 'package:pinpoint/entities/note.dart';

class NoteAttachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// FK to Note.id.
  ///
  /// CASCADE DELETE: attachments belong to their note and must not outlive it.
  /// This declared no `onDelete` at all until schema v11, which left orphan
  /// attachment rows behind every note deletion — invisible only because
  /// foreign keys were never enforced.
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get attachmentName => text()();
  TextColumn get attachmentPath => text()();
  TextColumn get attachmentMimeType => text().nullable()();
}
