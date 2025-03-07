import 'package:drift/drift.dart';

import '../entities/note.dart';
import '../entities/note_attachments.dart';
import '../entities/note_folder.dart';
import '../entities/note_folder_relations.dart';
import '../entities/note_todo_item.dart';

abstract class NotesView extends View {
  Notes get notes;
  NoteTodoItems get noteTodoItems;
  NoteFolders get noteFolders;
  NoteFolderRelations get noteFolderRelations;
  NoteAttachments get noteAttachments;

  @override
  Query as() => select([
        notes.id,
        notes.title,
        notes.defaultNoteType,
        notes.content,
        notes.contentPlainText,
        notes.audioFilePath,
        notes.audioDuration,
        notes.reminderDescription,
        notes.reminderTime,
        notes.isPinned,
        notes.createdAt,
        notes.updatedAt,
        noteFolders.title, // Folder title
        noteAttachments.name, // Attachment name
        noteTodoItems.title, // Todo title
      ]).from(notes).join([
        leftOuterJoin(noteFolderRelations,
            noteFolderRelations.noteId.equalsExp(notes.id)),
        leftOuterJoin(noteFolders,
            noteFolders.id.equalsExp(noteFolderRelations.folderId)),
        leftOuterJoin(
            noteAttachments, noteAttachments.noteId.equalsExp(notes.id)),
        leftOuterJoin(noteTodoItems, noteTodoItems.noteId.equalsExp(notes.id)),
      ]);
}
