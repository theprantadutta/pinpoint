import 'package:drift/drift.dart';

import 'note_folder.dart';
import 'voice_note_entity.dart';

/// Junction table for many-to-many relationship between voice notes and folders
/// ARCHITECTURAL CHANGE: Links to VoiceNotesV2 instead of base Notes table
/// MANDATORY FOLDERS: Every voice note must have at least one folder relation
@DataClassName('VoiceNoteFolderRelationEntity')
class VoiceNoteFolderRelationsV2 extends Table {
  /// Foreign key to VoiceNotesV2 table
  /// CASCADE DELETE: When voice note is deleted, its folder relations are also deleted
  IntColumn get voiceNoteId =>
      integer().references(VoiceNotesV2, #id, onDelete: KeyAction.cascade)();

  /// Foreign key to NoteFolders table
  /// CASCADE DELETE: When folder is deleted, all note-folder relations are also deleted
  IntColumn get folderId => integer()
      .references(NoteFolders, #noteFolderId, onDelete: KeyAction.cascade)();

  /// Composite primary key: A voice note can be in a folder only once
  @override
  Set<Column> get primaryKey => {voiceNoteId, folderId};
}
