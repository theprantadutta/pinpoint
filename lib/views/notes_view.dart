

// abstract class NotesView extends View {
//   Notes get notes;
//   NoteTodoItems get noteTodoItems;
//   NoteFolders get noteFolders;
//   NoteFolderRelations get noteFolderRelations;
//   NoteAttachments get noteAttachments;

//   @override
//   Query as() => select([
//         notes.id,
//         notes.noteTitle,
//         notes.defaultNoteType,
//         notes.content,
//         notes.contentPlainText,
//         notes.audioFilePath,
//         notes.audioDuration,
//         notes.reminderDescription,
//         notes.reminderTime,
//         notes.isPinned,
//         notes.createdAt,
//         notes.updatedAt,
//         noteFolders.noteFolderId,
//         noteFolders.noteFolderTitle,
//         noteAttachments.mimeType,
//         noteAttachments.attachmentPath,
//         noteAttachments.attachmentName,
//         noteTodoItems.todoTitle,
//         noteTodoItems.isDone,
//       ]).from(notes).join([
//         leftOuterJoin(noteFolderRelations,
//             noteFolderRelations.noteId.equalsExp(notes.id)),
//         leftOuterJoin(
//             noteFolders,
//             noteFolders.noteFolderId
//                 .equalsExp(noteFolderRelations.noteFolderId)),
//         leftOuterJoin(
//             noteAttachments, noteAttachments.noteId.equalsExp(notes.id)),
//         leftOuterJoin(noteTodoItems, noteTodoItems.noteId.equalsExp(notes.id)),
//       ]);
// }

// abstract class NotesView extends View {
//   Notes get notes;
//   NoteFolders get noteFolders;
//   NoteFolderRelations get noteFolderRelations;
//   NoteAttachments get noteAttachments;
//   NoteTodoItems get noteTodoItems;

//   @override
//   Query as() => CustomSelect(
//         '''
//         SELECT 
//           notes.*,
//           json_group_array(
//             json_object(
//               'noteFolderId', noteFolders.noteFolderId,
//               'noteFolderTitle', noteFolders.noteFolderTitle
//             )
//           ) AS noteFolders,
//           json_group_array(
//             json_object(
//               'mimeType', noteAttachments.mimeType,
//               'attachmentPath', noteAttachments.attachmentPath,
//               'attachmentName', noteAttachments.attachmentName
//             )
//           ) AS attachments,
//           json_group_array(
//             json_object(
//               'todoTitle', noteTodoItems.todoTitle,
//               'isDone', noteTodoItems.isDone
//             )
//           ) AS todos
//         FROM notes
//         LEFT JOIN note_folder_relations ON note_folder_relations.noteId = notes.id
//         LEFT JOIN note_folders ON note_folders.noteFolderId = note_folder_relations.noteFolderId
//         LEFT JOIN note_attachments ON note_attachments.noteId = notes.id
//         LEFT JOIN note_todo_items ON note_todo_items.noteId = notes.id
//         GROUP BY notes.id
//         ''',
//         readsFrom: {
//           notes,
//           noteFolders,
//           noteFolderRelations,
//           noteAttachments,
//           noteTodoItems
//         },
//       ).as();
// }
