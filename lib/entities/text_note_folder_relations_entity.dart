import 'package:drift/drift.dart';

import 'note_folder.dart';
import 'text_note_entity.dart';

/// Junction table for many-to-many relationship between text notes and folders
/// ARCHITECTURAL CHANGE: Links to TextNotesV2 instead of base Notes table
/// MANDATORY FOLDERS: Every text note must have at least one folder relation
@DataClassName('TextNoteFolderRelationEntity')
class TextNoteFolderRelationsV2 extends Table {
  /// Foreign key to TextNotesV2 table
  /// CASCADE DELETE: When text note is deleted, its folder relations are also deleted
  IntColumn get textNoteId =>
      integer().references(TextNotesV2, #id, onDelete: KeyAction.cascade)();

  /// Foreign key to NoteFolders table
  /// CASCADE DELETE: When folder is deleted, all note-folder relations are also deleted
  IntColumn get folderId => integer()
      .references(NoteFolders, #noteFolderId, onDelete: KeyAction.cascade)();

  /// Composite primary key: A text note can be in a folder only once
  @override
  Set<Column> get primaryKey => {textNoteId, folderId};
}
