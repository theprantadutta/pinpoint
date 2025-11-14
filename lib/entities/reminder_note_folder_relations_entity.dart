import 'package:drift/drift.dart';

import 'note_folder.dart';
import 'reminder_note_entity.dart';

/// Junction table for many-to-many relationship between reminder notes and folders
/// ARCHITECTURAL CHANGE: Links to ReminderNotesV2 instead of base Notes table
/// MANDATORY FOLDERS: Every reminder note must have at least one folder relation
@DataClassName('ReminderNoteFolderRelationEntity')
class ReminderNoteFolderRelationsV2 extends Table {
  /// Foreign key to ReminderNotesV2 table
  /// CASCADE DELETE: When reminder note is deleted, its folder relations are also deleted
  IntColumn get reminderNoteId =>
      integer().references(ReminderNotesV2, #id, onDelete: KeyAction.cascade)();

  /// Foreign key to NoteFolders table
  /// CASCADE DELETE: When folder is deleted, all note-folder relations are also deleted
  IntColumn get folderId => integer()
      .references(NoteFolders, #noteFolderId, onDelete: KeyAction.cascade)();

  /// Composite primary key: A reminder note can be in a folder only once
  @override
  Set<Column> get primaryKey => {reminderNoteId, folderId};
}
