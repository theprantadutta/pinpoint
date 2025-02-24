import 'package:flutter/foundation.dart';
import 'package:pinpoint/database/database.dart';

import '../service_locators/init_service_locators.dart';

class DriftNoteService {
  DriftNoteService._();

  // Future<void> addNoteToFolder(int noteId, int folderId) async {
  //   await into(noteFolderRelations).insert(
  //     NoteFolderRelationsCompanion.insert(noteId: noteId, folderId: folderId),
  //     mode: InsertMode.insertOrIgnore, // Avoid duplicates
  //   );
  // }

  // Future<List<Note>> getNotesInFolder(int folderId) async {
  //   return (select(notes)
  //         ..where((n) => n.id.isInQuery(select(noteFolderRelations)
  //           ..where((r) => r.folderId.equals(folderId)).map((r) => r.noteId))))
  //       .get();
  // }

  // Future<List<NoteFolder>> getFoldersForNote(int noteId) async {
  //   return (select(noteFolders)
  //         ..where((f) => f.id.isInQuery(select(noteFolderRelations)
  //           ..where((r) => r.noteId.equals(noteId)).map((r) => r.folderId))))
  //       .get();
  // }

  static Future<Note?> getSingleNote(int noteId) {
    final database = getIt<AppDatabase>();
    return (database.select(database.notes)..where((x) => x.id.equals(noteId)))
        .getSingleOrNull();
  }

  static Future<bool> addANewTitleContentNote(
    NotesCompanion note,
  ) async {
    try {
      final database = getIt<AppDatabase>();

      final existingNote = await getSingleNote(note.id.value);
      if (existingNote == null) {
        await database.into(database.notes).insert(note);
      } else {
        await database.update(database.notes).replace(note);
      }

      // Insert into TitleContentType table
      // await database.into(database.noteTitleContentTypes).insert(
      //       NoteTitleContentTypesCompanion(
      //         id: Value(noteId),
      //         content: Value(content),
      //       ),
      //     );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to insert title content type');
        print(e);
      }
      return false;
    }
  }
}
