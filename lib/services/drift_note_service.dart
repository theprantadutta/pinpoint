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
}
