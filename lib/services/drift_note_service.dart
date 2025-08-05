import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pinpoint/services/logger_service.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/dtos/note_attachment_dto.dart';

import '../dtos/note_folder_dto.dart';
import '../models/note_with_details.dart';
import '../service_locators/init_service_locators.dart';
import 'package:pinpoint/services/notification_service.dart';
import 'package:pinpoint/services/encryption_service.dart';

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

      final encryptedContent = note.content.value != null
          ? EncryptionService.encrypt(note.content.value!)
          : null;
      final encryptedContentPlainText = note.contentPlainText.value != null
          ? EncryptionService.encrypt(note.contentPlainText.value!)
          : null;

      final noteToSave = note.copyWith(
        content: Value(encryptedContent),
        contentPlainText: Value(encryptedContentPlainText),
      );

      if (previousNoteId != null) {
        final existingNote = await getSingleNote(previousNoteId);
        if (existingNote != null) {
          log.d('Updating existing note...');
          await database
              .update(database.notes)
              .replace(noteToSave.copyWith(id: Value(previousNoteId)));
          final updatedNoteId = existingNote.id;
          _handleReminderNotification(
            updatedNoteId,
            note.reminderTime.present ? note.reminderTime.value : null,
            note.noteTitle.present ? note.noteTitle.value : null,
          );
          return updatedNoteId;
        }
      }

      log.d('Adding new note...');
      final newNoteId = await database.into(database.notes).insert(noteToSave);
      _handleReminderNotification(
        newNoteId,
        note.reminderTime.present ? note.reminderTime.value : null,
        note.noteTitle.present ? note.noteTitle.value : null,
      );
      return newNoteId;
    } catch (e, st) {
      log.e('Failed to insert/update note', e, st);
      return 0;
    }
  }

  static void _handleReminderNotification(
      int noteId, DateTime? reminderTime, String? noteTitle) {
    if (reminderTime != null && reminderTime.isAfter(DateTime.now())) {
      NotificationService.scheduleNotification(
        id: noteId,
        title: noteTitle ?? 'Reminder',
        body: 'Time for your note!',
        scheduledDate: reminderTime,
      );
    } else {
      NotificationService.cancelNotification(noteId);
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
          log.d('Updating attachment: ${attachment.name}');
          await database.update(database.noteAttachments).replace(
              attachmentCompanion.copyWith(id: Value(existingAttachment.id)));
        } else {
          log.d('Inserting new attachment: ${attachment.name}');
          await database
              .into(database.noteAttachments)
              .insert(attachmentCompanion);
        }
      }
      return true;
    } catch (e, st) {
      log.e('Failed to upsert note attachments', e, st);
      return false;
    }
  }

  static Stream<List<NoteAttachment>> watchNoteAttachmentsById(int noteId) {
    final database = getIt<AppDatabase>();
    return (database.select(database.noteAttachments)
          ..where((x) => x.noteId.equals(noteId)))
        .watch();
  }

  static Future<NoteTodoItem> insertTodoItem({
    required int noteId,
    required String title,
  }) async {
    final database = getIt<AppDatabase>();
    final todoCompanion = NoteTodoItemsCompanion(
      noteId: Value(noteId),
      todoTitle: Value(title),
      isDone: Value(false),
    );
    final id =
        await database.into(database.noteTodoItems).insert(todoCompanion);
    return NoteTodoItem(
        id: id, noteId: noteId, todoTitle: title, isDone: false);
  }

  static Future<void> updateTodoItemStatus(int todoId, bool isDone) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.noteTodoItems)
          ..where((tbl) => tbl.id.equals(todoId)))
        .write(NoteTodoItemsCompanion(isDone: Value(isDone)));
  }

  static Future<void> updateTodoItemTitle(int todoId, String newTitle) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.noteTodoItems)
          ..where((tbl) => tbl.id.equals(todoId)))
        .write(NoteTodoItemsCompanion(todoTitle: Value(newTitle)));
  }

  static Future<void> deleteTodoItem(int todoId) async {
    final database = getIt<AppDatabase>();
    await (database.delete(database.noteTodoItems)
          ..where((tbl) => tbl.id.equals(todoId)))
        .go();
  }

  static Future<void> softDeleteNoteById(int noteId) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .write(NotesCompanion(isDeleted: Value(true)));
    NotificationService.cancelNotification(noteId);
    log.i("Note with ID $noteId soft-deleted successfully.");
  }

  static Future<void> restoreNoteById(int noteId) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .write(NotesCompanion(isDeleted: Value(false)));
    log.i("Note with ID $noteId restored successfully.");
  }

  static Future<void> permanentlyDeleteNoteById(int noteId) async {
    final database = getIt<AppDatabase>();
    NotificationService.cancelNotification(noteId);
    // Delete attachments first to maintain referential integrity
    await (database.delete(database.noteAttachments)
          ..where((tbl) => tbl.noteId.equals(noteId)))
        .go();

    // Now delete the note
    await (database.delete(database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .go();
    log.i("Note with ID $noteId and its attachments permanently deleted.");
  }

  static Future<void> toggleArchiveStatus(int noteId, bool isArchived) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .write(NotesCompanion(isArchived: Value(isArchived)));

    if (isArchived) {
      NotificationService.cancelNotification(noteId);
    } else {
      final note = await getSingleNote(noteId);
      if (note != null &&
          note.reminderTime != null &&
          note.reminderTime!.isAfter(DateTime.now())) {
        NotificationService.scheduleNotification(
          id: note.id,
          title: note.noteTitle ?? 'Reminder',
          body: 'Time for your note!',
          scheduledDate: note.reminderTime!,
        );
      }
    }
  }

  static Future<void> togglePinStatus(int noteId, bool isPinned) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .write(NotesCompanion(isPinned: Value(isPinned)));
  }

  static Stream<List<NoteWithDetails>> watchArchivedNotes() {
    return (getIt<AppDatabase>().select(getIt<AppDatabase>().notes)
          ..where((tbl) => tbl.isArchived.equals(true))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch()
        .map((notes) => notes
            .map((note) => NoteWithDetails(
                  note: note,
                  folders: const [],
                  attachments: const [],
                  todoItems: const [],
                  tags: const [],
                ))
            .toList());
  }

  static Stream<List<NoteWithDetails>> watchDeletedNotes() {
    return (getIt<AppDatabase>().select(getIt<AppDatabase>().notes)
          ..where((tbl) => tbl.isDeleted.equals(true))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch()
        .map((notes) => notes
            .map((note) => NoteWithDetails(
                  note: note,
                  folders: const [],
                  attachments: const [],
                  todoItems: const [],
                  tags: const [],
                ))
            .toList());
  }

  static Future<NoteTag> insertNoteTag(String title) async {
    final database = getIt<AppDatabase>();
    final now = Value(DateTime.now());
    final tagCompanion = NoteTagsCompanion(
      tagTitle: Value(title),
      createdAt: now,
      updatedAt: now,
    );
    final id = await database.into(database.noteTags).insert(tagCompanion);
    return NoteTag(
        id: id, tagTitle: title, createdAt: now.value, updatedAt: now.value);
  }

  static Future<void> deleteNoteTag(int tagId) async {
    final database = getIt<AppDatabase>();
    await database.transaction(() async {
      await (database.delete(database.noteTagRelations)
            ..where((tbl) => tbl.tagId.equals(tagId)))
          .go();
      await (database.delete(database.noteTags)
            ..where((tbl) => tbl.id.equals(tagId)))
          .go();
    });
  }

  static Stream<List<NoteTag>> watchAllNoteTags() {
    final database = getIt<AppDatabase>();
    return database.select(database.noteTags).watch();
  }

  static Future<void> upsertNoteTagsWithNote(
      List<int> tagIds, int noteId) async {
    final database = getIt<AppDatabase>();
    await database.transaction(() async {
      // Delete existing relations for this note
      await (database.delete(database.noteTagRelations)
            ..where((tbl) => tbl.noteId.equals(noteId)))
          .go();

      // Insert new relations
      final newRelations =
          tagIds.map((tagId) => NoteTagRelationsCompanion.insert(
                noteId: noteId,
                tagId: tagId,
              ));
      await database.batch((batch) {
        batch.insertAll(database.noteTagRelations, newRelations);
      });
    });
  }

  static Stream<List<NoteWithDetails>> watchNotesWithDetails(
      [String searchQuery = '']) {
    try {
      final database = getIt<AppDatabase>();
      log.d('[watchNotesWithDetails] start; query="$searchQuery"');

      String whereClause = 'WHERE n.is_archived = 0 AND n.is_deleted = 0';
      List<dynamic> variables = [];
      if (searchQuery.isNotEmpty) {
        whereClause +=
            ' AND (n.note_title LIKE ? OR n.content_plain_text LIKE ?)';
        variables = ['%$searchQuery%', '%$searchQuery%'];
      }

      final sql = '''
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
      t.is_done AS todo_is_done,
      (
        SELECT json_group_array(json_object(
          'id', tag.id,
          'tag_title', tag.tag_title
        ))
        FROM note_tags tag
        INNER JOIN note_tag_relations tag_rel ON tag.id = tag_rel.tag_id
        WHERE tag_rel.note_id = n.id
      ) AS tags
    FROM notes n
    LEFT JOIN note_attachments a ON n.id = a.note_id
    LEFT JOIN note_todo_items t ON n.id = t.note_id
    $whereClause
    GROUP BY n.id
    ORDER BY n.is_pinned DESC, n.updated_at DESC
    ''';

      log.d('[watchNotesWithDetails] SQL: $sql');
      log.d('[watchNotesWithDetails] vars: $variables');

      return database
          .customSelect(
            sql,
            variables: variables.map((e) => Variable(e)).toList(),
            readsFrom: {
              database.notes,
              database.noteFolderRelations,
              database.noteFolders,
              database.noteAttachments,
              database.noteTodoItems,
              database.noteTags,
              database.noteTagRelations,
            },
          )
          .watch()
          .handleError((e, st) {
            log.e('[watchNotesWithDetails] stream error', e, st);
          })
          .map(
            (rows) {
              log.d('[watchNotesWithDetails] rows: ${rows.length}');
              final notesMap = <int, NoteWithDetails>{};

              for (final row in rows) {
                try {
                  final noteId = row.read<int>('id');
                  // Parse only once per note id
                  notesMap.putIfAbsent(() {
                    return noteId;
                  }(), () {
                    // Folders
                    final foldersJson = row.read<String?>('folders');
                    final List<NoteFolderDto> folders = foldersJson != null
                        ? (jsonDecode(foldersJson) as List<dynamic>)
                            .map((f) => NoteFolderDto(
                                  id: f['id'],
                                  title: f['title'],
                                ))
                            .toList()
                        : <NoteFolderDto>[];

                    // Tags
                    final tagsJson = row.read<String?>('tags');
                    final List<NoteTag> tags = tagsJson != null
                        ? (jsonDecode(tagsJson) as List<dynamic>)
                            .map((t) => NoteTag(
                                  id: t['id'],
                                  tagTitle: t['tag_title'],
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ))
                            .toList()
                        : <NoteTag>[];

                    final audioFilePath = row.read<String?>('audio_file_path');
                    final audioDuration = row.read<int?>('audio_duration');

                    return NoteWithDetails(
                      note: Note(
                        id: noteId,
                        noteTitle: row.read<String?>('note_title'),
                        defaultNoteType: row.read<String>('default_note_type'),
                        content: _safeDecrypt(row.read<String?>('content')),
                        contentPlainText: _safeDecrypt(
                            row.read<String?>('content_plain_text')),
                        audioFilePath: audioFilePath,
                        audioDuration: audioDuration,
                        reminderDescription:
                            row.read<String?>('reminder_description'),
                        reminderTime: row.read<DateTime?>('reminder_time'),
                        isPinned: row.read<bool>('is_pinned'),
                        createdAt: row.read<DateTime>('created_at'),
                        updatedAt: row.read<DateTime>('updated_at'),
                        isArchived: row.read<bool?>('is_archived') ?? false,
                        isDeleted: row.read<bool?>('is_deleted') ?? false,
                      ),
                      folders: folders,
                      attachments: [],
                      todoItems: [],
                      tags: tags,
                    );
                  });

                  // Attachments
                  final attachmentName = row.read<String?>('attachment_name');
                  if (attachmentName != null) {
                    notesMap[noteId]!.attachments.add(
                          NoteAttachmentDto(
                            mimeType: row.read<String?>('attachment_mime_type'),
                            path: row.read<String>('attachment_path'),
                            name: attachmentName,
                          ),
                        );
                  }

                  // Todos
                  final todoTitle = row.read<String?>('todo_title');
                  final todoId = row.read<int?>('todo_id');
                  if (todoTitle != null && todoId != null) {
                    notesMap[noteId]!.todoItems.add(
                          NoteTodoItem(
                            id: todoId,
                            noteId: noteId,
                            todoTitle: todoTitle,
                            isDone: row.read<bool>('todo_is_done'),
                          ),
                        );
                  }
                } catch (rowErr, st) {
                  log.e('[watchNotesWithDetails] row parse error', rowErr, st);
                }
              }

              log.d('[watchNotesWithDetails] parsed notes: ${notesMap.length}');
              return notesMap.values.toList();
            },
          );
    } catch (e, st) {
      log.e('[watchNotesWithDetails] fatal error', e, st);
      rethrow;
    }
  }

  static Stream<List<NoteWithDetails>> watchNotesWithDetailsByFolder(
      int folderId) {
    try {
      final database = getIt<AppDatabase>();
      log.d('[watchNotesWithDetailsByFolder] start; folderId=$folderId');

      final sql = '''
        SELECT
          n.*,
          (
            SELECT json_group_array(json_object(
              'id', f.note_folder_id,
              'title', f.note_folder_title
            ))
            FROM note_folders f
            INNER JOIN note_folder_relations r_inner ON f.note_folder_id = r_inner.note_folder_id
            WHERE r_inner.note_id = n.id
          ) AS folders
        FROM notes n
        LEFT JOIN note_tag_relations tr ON n.id = tr.note_id
        LEFT JOIN note_tags nt ON tr.tag_id = nt.id
        INNER JOIN note_folder_relations r ON n.id = r.note_id
        WHERE r.note_folder_id = ? AND n.is_archived = 0 AND n.is_deleted = 0
        GROUP BY n.id
        ORDER BY n.is_pinned DESC, n.updated_at DESC
      ''';

      log.d('[watchNotesWithDetailsByFolder] SQL: $sql');

      return database
          .customSelect(
            sql,
            variables: [Variable.withInt(folderId)],
            readsFrom: {
              database.notes,
              database.noteFolderRelations,
              database.noteFolders,
              database.noteTags,
              database.noteTagRelations,
            },
          )
          .watch()
          .handleError((e, st) {
            log.e('[watchNotesWithDetailsByFolder] stream error', e, st);
          })
          .map((rows) {
            log.d(
                '[watchNotesWithDetailsByFolder] rows: ${rows.length} for folderId=$folderId');
            return rows.map((row) {
              try {
                final foldersJson = row.read<String?>('folders');
                final List<NoteFolderDto> folders = foldersJson != null
                    ? (jsonDecode(foldersJson) as List<dynamic>)
                        .map((folder) => NoteFolderDto(
                              id: folder['id'],
                              title: folder['title'],
                            ))
                        .toList()
                    : <NoteFolderDto>[];

                final tagsJson = row.read<String?>('tags');
                final List<NoteTag> tags = tagsJson != null
                    ? (jsonDecode(tagsJson) as List<dynamic>)
                        .map((tag) => NoteTag(
                              id: tag['id'],
                              tagTitle: tag['tag_title'],
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ))
                        .toList()
                    : <NoteTag>[];

                return NoteWithDetails(
                  note: Note(
                    id: row.read<int>('id'),
                    noteTitle: row.read<String?>('note_title'),
                    defaultNoteType: row.read<String>('default_note_type'),
                    content: _safeDecrypt(row.read<String?>('content')),
                    contentPlainText:
                        _safeDecrypt(row.read<String?>('content_plain_text')),
                    audioFilePath: row.read<String?>('audio_file_path'),
                    audioDuration: row.read<int?>('audio_duration'),
                    reminderDescription:
                        row.read<String?>('reminder_description'),
                    reminderTime: row.read<DateTime?>('reminder_time'),
                    isPinned: row.read<bool>('is_pinned'),
                    createdAt: row.read<DateTime>('created_at'),
                    updatedAt: row.read<DateTime>('updated_at'),
                    isArchived: row.read<bool?>('is_archived') ?? false,
                    isDeleted: row.read<bool?>('is_deleted') ?? false,
                  ),
                  folders: folders,
                  attachments: [],
                  todoItems: [],
                  tags: tags,
                );
              } catch (rowErr, st) {
                log.e('[watchNotesWithDetailsByFolder] row parse error', rowErr,
                    st);
                rethrow;
              }
            }).toList();
          });
    } catch (e, st) {
      log.e('[watchNotesWithDetailsByFolder] fatal error', e, st);
      rethrow;
    }
  }

  // Heuristic decrypt with quiet fallback:
  // - If it looks like JSON/delta (starts with '[' or '{'), return as-is.
  // - If it is not base64-like or length not multiple of 4, return as-is.
  // - Otherwise attempt decrypt, and on failure return original without noisy logs.
  static String? _safeDecrypt(String? value) {
    if (value == null) return null;
    final v = value.trim();

    // Quick check: Quill delta / JSON content
    if (v.startsWith('[') || v.startsWith('{')) {
      return value;
    }

    // Base64 characters only
    final base64Like = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (!base64Like.hasMatch(v)) {
      return value;
    }

    // Base64 should be padded to multiple of 4
    if (v.length % 4 != 0) {
      return value;
    }

    try {
      return EncryptionService.decrypt(v);
    } catch (_) {
      return value;
    }
  }
}
