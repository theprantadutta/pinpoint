import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/dtos/note_attachment_dto.dart';

import '../components/create_note_screen/todo_list_type/todo_list_type_content.dart';
import '../dtos/note_folder_dto.dart';
import '../models/note_with_details.dart';
import '../service_locators/init_service_locators.dart';

class DriftNoteService {
  DriftNoteService._();

  static Future<Note?> getSingleNote(int noteId) {
    final database = getIt<AppDatabase>();
    return (database.select(database.notes)..where((x) => x.id.equals(noteId)))
        .getSingleOrNull();
  }

  static Stream<List<Note>> watchRecentNotes() {
    final database = getIt<AppDatabase>();
    return (database.select(database.notes)
          ..orderBy([
            (x) =>
                OrderingTerm(expression: x.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  static Future<int> upsertANewTitleContentNote(
    NotesCompanion note,
    int? previousNoteId,
  ) async {
    try {
      final database = getIt<AppDatabase>();

      if (previousNoteId != null) {
        final existingNote = await getSingleNote(previousNoteId);
        if (existingNote != null) {
          debugPrint('Updating existing note...');
          await database
              .update(database.notes)
              .replace(note.copyWith(id: Value(previousNoteId)));
          return existingNote.id;
        }
      }

      debugPrint('Adding new note...');
      return await database.into(database.notes).insert(note);
    } catch (e) {
      debugPrint('Failed to insert/update note: $e');
      return 0;
    }
  }

  static Future<bool> upsertNoteAttachments(
      List<NoteAttachmentDto> attachments, int noteId) async {
    try {
      final database = getIt<AppDatabase>();
      if (attachments.isEmpty) return true;

      for (final attachment in attachments) {
        final existingAttachment =
            await (database.select(database.noteAttachments)
                  ..where((tbl) =>
                      tbl.attachmentPath.equals(attachment.path) &
                      tbl.noteId.equals(noteId)))
                .getSingleOrNull();

        final attachmentCompanion = NoteAttachmentsCompanion(
          attachmentName: Value(attachment.name),
          noteId: Value(noteId),
          attachmentMimeType: Value(attachment.mimeType),
          attachmentPath: Value(attachment.path),
        );

        if (existingAttachment != null) {
          debugPrint('Updating attachment: ${attachment.name}');
          await database.update(database.noteAttachments).replace(
              attachmentCompanion.copyWith(id: Value(existingAttachment.id)));
        } else {
          debugPrint('Inserting new attachment: ${attachment.name}');
          await database
              .into(database.noteAttachments)
              .insert(attachmentCompanion);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Failed to upsert note attachments: $e');
      return false;
    }
  }

  static Stream<List<NoteAttachment>> watchNoteAttachmentsById(int noteId) {
    final database = getIt<AppDatabase>();
    return (database.select(database.noteAttachments)
          ..where((x) => x.noteId.equals(noteId)))
        .watch();
  }

  static Future<bool> deleteNoteById(int noteId) async {
    final database = getIt<AppDatabase>();
    // Delete attachments first to maintain referential integrity
    await (database.delete(database.noteAttachments)
          ..where((tbl) => tbl.noteId.equals(noteId)))
        .go();

    // Now delete the note
    await (database.delete(database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .go();

    debugPrint(
        "Note with ID $noteId and its attachments deleted successfully.");

    return true;
  }

  // static Stream<List<NotesViewData>> getNoteViewData() {
  //   final database = getIt<AppDatabase>();

  //   return (database.select(database.notesView)
  //         ..orderBy([
  //           (x) =>
  //               OrderingTerm(expression: x.updatedAt, mode: OrderingMode.desc)
  //         ]))
  //       .watch();
  // }

  // static Future<NotesViewData?> getSingleNoteView(int noteId) async {
  //   final database = getIt<AppDatabase>();
  //   return (database.select(database.notesView)
  //         ..where((x) => x.id.equals(noteId)))
  //       .getSingleOrNull();
  // }

  static Stream<List<NoteWithDetails>> watchNotesWithDetails() {
    try {
      final database = getIt<AppDatabase>();
      if (kDebugMode) {
        print('Fetching notes with details from the database...');
      }

      return database
          .customSelect(
            '''
    SELECT 
      n.*,
      (
        SELECT json_group_array(json_object(
          'id', f.note_folder_id,
          'title', f.note_folder_title
        ))
        FROM note_folders f
        INNER JOIN note_folder_relations r ON f.note_folder_id = r.note_folder_id
        WHERE r.note_id = n.id
      ) AS folders,
      a.attachment_mime_type AS attachment_mime_type,
      a.attachment_path AS attachment_path,
      a.attachment_name AS attachment_name,
      t.id AS todo_id,
      t.todo_title AS todo_title,
      t.is_done AS todo_is_done
    FROM notes n
    LEFT JOIN note_attachments a ON n.id = a.note_id
    LEFT JOIN note_todo_items t ON n.id = t.note_id
    GROUP BY n.id
    ''',
            readsFrom: {
              database.notes,
              database.noteFolderRelations,
              database.noteFolders,
              database.noteAttachments,
              database.noteTodoItems
            },
          )
          .watch()
          .map(
            (rows) {
              if (kDebugMode) {
                print('Received ${rows.length} rows from the database.');
              }

              final notesMap = <int, NoteWithDetails>{};

              for (final row in rows) {
                final noteId = row.read<int>('id');
                if (kDebugMode) {
                  print('Processing note with ID: $noteId');
                }

                // Parse the note if it hasn't been parsed yet.
                if (!notesMap.containsKey(noteId)) {
                  if (kDebugMode) {
                    print('Parsing note with ID: $noteId for the first time.');
                  }

                  // Parse the folders JSON array.
                  final foldersJson = row.read<String>('folders');
                  if (kDebugMode) {
                    print('Folders JSON for note $noteId: $foldersJson');
                  }

                  final folders = (jsonDecode(foldersJson) as List<dynamic>)
                      .map((folder) => NoteFolderDto(
                            id: folder['id'],
                            title: folder['title'],
                          ))
                      .toList();

                  if (kDebugMode) {
                    print('Parsed folders for note $noteId: $folders');
                  }

                  final audioFilePath = row.read<String?>('audio_file_path');
                  final audioDuration = row.read<int?>('audio_duration');
                  if (kDebugMode) {
                    print(
                        'Audio file path for note $noteId: $audioFilePath, duration: $audioDuration');
                  }

                  notesMap[noteId] = NoteWithDetails(
                    note: Note(
                      id: noteId,
                      noteTitle: row.read<String?>('note_title'),
                      defaultNoteType: row.read<String>('default_note_type'),
                      content: row.read<String?>('content'),
                      contentPlainText: row.read<String?>('content_plain_text'),
                      audioFilePath: audioFilePath,
                      audioDuration: audioDuration,
                      reminderDescription:
                          row.read<String?>('reminder_description'),
                      reminderTime: row.read<DateTime?>('reminder_time'),
                      isPinned: row.read<bool>('is_pinned'),
                      createdAt: row.read<DateTime>('created_at'),
                      updatedAt: row.read<DateTime>('updated_at'),
                    ),
                    folders: folders,
                    attachments: [],
                    todoItems: [],
                  );

                  if (kDebugMode) {
                    print('Successfully parsed note with ID: $noteId');
                  }
                }

                // Parse attachments if they exist.
                final attachmentName = row.read<String?>('attachment_name');
                if (attachmentName != null) {
                  if (kDebugMode) {
                    print(
                        'Parsing attachment for note $noteId: $attachmentName');
                  }

                  notesMap[noteId]!.attachments.add(
                        NoteAttachmentDto(
                          mimeType: row.read<String?>('attachment_mime_type'),
                          path: row.read<String>('attachment_path'),
                          name: attachmentName,
                        ),
                      );

                  if (kDebugMode) {
                    print('Successfully parsed attachment for note $noteId');
                  }
                }

                // Parse to-do items if they exist.
                final todoTitle = row.read<String?>('todo_title');
                final todoId = row.read<int?>('todo_id');
                if (todoTitle != null) {
                  if (kDebugMode) {
                    print('Parsing to-do item for note $noteId: $todoTitle');
                  }

                  notesMap[noteId]!.todoItems.add(
                        TodoItem(
                          id: todoId!,
                          title: todoTitle,
                          isDone: row.read<bool>('todo_is_done'),
                        ),
                      );

                  if (kDebugMode) {
                    print('Successfully parsed to-do item for note $noteId');
                  }
                }
              }

              if (kDebugMode) {
                print(
                    'Finished processing all rows. Returning ${notesMap.length} notes.');
              }

              return notesMap.values.toList();
            },
          );
    } catch (e) {
      if (kDebugMode) {
        print('Something went wrong while fetching notes with details: $e');
      }
      rethrow;
    }
  }
}
