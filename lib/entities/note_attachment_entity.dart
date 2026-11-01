import 'package:drift/drift.dart';

/// Files attached to a note: images (shown as thumbnails) and any other file.
///
/// Keyed by the note's uuid, so one table serves text and checklist notes.
/// The file lives on this device at [localPath] and works offline; once
/// uploaded (encrypted with the account data key, see AttachmentSync) the
/// server copy is [remoteId], and that id is what sync sends to the user's
/// other devices inside the note's encrypted payload.
@DataClassName('NoteAttachmentEntity')
class NoteAttachmentsV2 extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable across devices: the payload refers to attachments by it.
  TextColumn get uuid => text().unique()();

  TextColumn get noteUuid => text()();

  /// 'text' or 'todo': which table [noteUuid] is in.
  TextColumn get noteType => text()();

  /// The name the user picked it with, shown on file chips.
  TextColumn get fileName => text()();

  TextColumn get mimeType => text()();

  IntColumn get sizeBytes => integer()();

  /// The file on this device; null until a synced attachment is downloaded.
  TextColumn get localPath => text().nullable()();

  /// FileRunner id of the encrypted copy; null until uploaded.
  TextColumn get remoteId => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
}
