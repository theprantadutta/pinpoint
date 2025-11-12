import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/dtos/note_attachment_dto.dart';
import 'package:pinpoint/dtos/note_folder_dto.dart';
import 'package:pinpoint/models/filter_options.dart';
import 'package:pinpoint/models/note_todo_item_with_note.dart';
import 'package:pinpoint/models/note_with_details.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:pinpoint/services/logger_service.dart';
import 'package:pinpoint/services/notification_service.dart';
import 'package:pinpoint/util/note_utils.dart';
import 'package:drift/drift.dart' as drift;

class DriftNoteService {
  DriftNoteService._();

  static Future<Note?> getSingleNote(int noteId) {
    final database = getIt<AppDatabase>();
    return (database.select(database.notes)..where((x) => x.id.equals(noteId)))
        .getSingleOrNull();
  }

  static Future<NoteWithDetails?> getSingleNoteWithDetails(int noteId) async {
    final note = await getSingleNote(noteId);
    if (note == null) return null;

    final database = getIt<AppDatabase>();

    // Get folders
    final folderLinks = await (database.select(database.noteFolderRelations)
          ..where((x) => x.noteId.equals(noteId)))
        .get();
    final folderIds = folderLinks.map((link) => link.noteFolderId).toList();
    final folders = folderIds.isEmpty
        ? <NoteFolderDto>[]
        : await (database.select(database.noteFolders)
              ..where((x) => x.noteFolderId.isIn(folderIds.cast<int>())))
            .get()
            .then((list) => list
                .map((f) => NoteFolderDto(
                      id: f.noteFolderId,
                      title: f.noteFolderTitle,
                    ))
                .toList());

    // Get todos
    final todos = await (database.select(database.noteTodoItems)
          ..where((x) => x.noteId.equals(noteId)))
        .get();

    // Get text content if note type is text
    String? textContent;
    if (note.noteType == 'text') {
      final textNote = await (database.select(database.textNotes)
            ..where((x) => x.noteId.equals(noteId)))
          .getSingleOrNull();
      textContent = textNote?.content;
    }

    // Get attachments (empty for now, add if needed)
    final attachments = <NoteAttachmentDto>[];

    return NoteWithDetails(
      note: note,
      folders: folders,
      attachments: attachments,
      todoItems: todos,
      textContent: textContent,
    );
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

  /// Temporarily kept for backward compatibility
  /// This method is deprecated and will be removed in the future
  /// TODO: Replace all calls with type-specific methods
  static Future<int> upsertANewTitleContentNote(
    NotesCompanion note,
    int? previousNoteId,
  ) async {
    try {
      final database = getIt<AppDatabase>();

      // For now, only save the base note fields
      // Type-specific data needs to be saved separately
      if (previousNoteId != null) {
        final existingNote = await getSingleNote(previousNoteId);
        if (existingNote != null) {
          log.d('Updating existing note...');
          await database
              .update(database.notes)
              .replace(note.copyWith(
                id: Value(previousNoteId),
                isSynced: Value(false), // Mark as needing upload
                isDeleted: Value(existingNote.isDeleted), // IMPORTANT: Preserve isDeleted flag
              ));
          return existingNote.id;
        }
      }

      log.d('Adding new note...');
      // isSynced defaults to false for new notes
      final newNoteId = await database.into(database.notes).insert(note);
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
    int orderIndex = 0,
  }) async {
    final database = getIt<AppDatabase>();
    final todoCompanion = NoteTodoItemsCompanion(
      noteId: Value(noteId),
      todoTitle: Value(title),
      isDone: Value(false),
      orderIndex: Value(orderIndex),
    );
    final id =
        await database.into(database.noteTodoItems).insert(todoCompanion);
    return NoteTodoItem(
        id: id, noteId: noteId, todoTitle: title, isDone: false, orderIndex: orderIndex);
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
        .write(NotesCompanion(
          isDeleted: Value(true),
          isSynced: Value(false), // Mark as needing upload
        ));
    NotificationService.cancelNotification(noteId);
    log.i("Note with ID $noteId soft-deleted successfully.");
  }

  static Future<void> restoreNoteById(int noteId) async {
    final database = getIt<AppDatabase>();
    await (database.update(database.notes)
          ..where((tbl) => tbl.id.equals(noteId)))
        .write(NotesCompanion(
          isDeleted: Value(false),
          isSynced: Value(false), // Mark as needing upload
        ));
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
      // Check if this note has a reminder
      final reminderNote = await (database.select(database.reminderNotes)
            ..where((x) => x.noteId.equals(noteId)))
          .getSingleOrNull();

      if (reminderNote != null &&
          reminderNote.reminderTime.isAfter(DateTime.now())) {
        final note = await getSingleNote(noteId);
        NotificationService.scheduleNotification(
          id: noteId,
          title: note?.noteTitle ?? 'Reminder',
          body: 'Time for your note!',
          scheduledDate: reminderNote.reminderTime,
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

  static Future<void> removeReminder(int noteId) async {
    final database = getIt<AppDatabase>();
    // Delete the reminder note data from ReminderNotes table
    await (database.delete(database.reminderNotes)
          ..where((tbl) => tbl.noteId.equals(noteId)))
        .go();
    NotificationService.cancelNotification(noteId);
  }

  static Stream<List<NoteWithDetails>> watchArchivedNotes({
    String searchQuery = '',
    FilterOptions? filterOptions,
  }) {
    try {
      final database = getIt<AppDatabase>();
      final filters = filterOptions ?? FilterOptions.empty;
      log.d('[watchArchivedNotes] start; query="$searchQuery", filters: $filters');

      String whereClause = 'WHERE n.is_archived = 1 AND n.is_deleted = 0 AND n.note_type != \'todo\'';
      List<dynamic> variables = [];

      // Search in title, content, todo items, folder names, and attachment names (case-insensitive)
      if (searchQuery.isNotEmpty) {
        whereClause +=
            ' AND (n.note_title LIKE ? COLLATE NOCASE'
            ' OR tn.content LIKE ? COLLATE NOCASE'
            ' OR EXISTS (SELECT 1 FROM note_todo_items t WHERE t.note_id = n.id AND t.todo_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_folder_relations r INNER JOIN note_folders f ON r.note_folder_id = f.note_folder_id WHERE r.note_id = n.id AND f.note_folder_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_attachments a WHERE a.note_id = n.id AND a.attachment_name LIKE ? COLLATE NOCASE))';
        final searchPattern = '%$searchQuery%';
        variables = [searchPattern, searchPattern, searchPattern, searchPattern, searchPattern];
      }

      // Filter by folder IDs
      if (filters.folderIds.isNotEmpty) {
        final placeholders = List.filled(filters.folderIds.length, '?').join(',');
        whereClause += ' AND EXISTS (SELECT 1 FROM note_folder_relations r WHERE r.note_id = n.id AND r.note_folder_id IN ($placeholders))';
        variables.addAll(filters.folderIds);
      }

      // Filter by note types
      if (filters.noteTypes.isNotEmpty) {
        final placeholders = List.filled(filters.noteTypes.length, '?').join(',');
        whereClause += ' AND n.note_type IN ($placeholders)';
        variables.addAll(filters.noteTypes);
      }

      // Filter by date range
      if (filters.dateRangeStart != null) {
        whereClause += ' AND n.created_at >= ?';
        variables.add(filters.dateRangeStart!.millisecondsSinceEpoch ~/ 1000);
      }
      if (filters.dateRangeEnd != null) {
        final endDate = filters.dateRangeEnd!.add(const Duration(days: 1));
        whereClause += ' AND n.created_at < ?';
        variables.add(endDate.millisecondsSinceEpoch ~/ 1000);
      }

      // Filter by pins only
      if (filters.pinsOnly) {
        whereClause += ' AND n.is_pinned = 1';
      }

      final sql = '''
    SELECT
      n.*,
      tn.content AS text_content,
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
    LEFT JOIN text_notes tn ON n.id = tn.note_id
    LEFT JOIN note_attachments a ON n.id = a.note_id
    LEFT JOIN note_todo_items t ON n.id = t.note_id
    $whereClause
    GROUP BY n.id
    ORDER BY n.is_pinned DESC, n.updated_at DESC
    ''';

      log.d('[watchArchivedNotes] SQL: $sql');
      log.d('[watchArchivedNotes] vars: $variables');

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
            },
          )
          .watch()
          .handleError((e, st) {
            log.e('[watchArchivedNotes] stream error', e, st);
          })
          .map((rows) {
            log.d('[watchArchivedNotes] rows: ${rows.length}');
            final notesMap = <int, NoteWithDetails>{};

            for (final row in rows) {
              try {
                final noteId = row.read<int>('id');
                notesMap.putIfAbsent(noteId, () {
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

                  return NoteWithDetails(
                    note: Note(
                      id: noteId,
                      noteTitle: row.read<String?>('note_title'),
                      noteType: row.read<String>('note_type'),
                      isPinned: row.read<bool>('is_pinned'),
                      createdAt: row.read<DateTime>('created_at'),
                      updatedAt: row.read<DateTime>('updated_at'),
                      isArchived: row.read<bool?>('is_archived') ?? false,
                      isDeleted: row.read<bool?>('is_deleted') ?? false,
                      isSynced: row.read<bool?>('is_synced') ?? false,
                    ),
                    folders: folders,
                    attachments: [],
                    todoItems: [],
                    textContent: row.read<String?>('text_content'),
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
                          orderIndex: 0,
                        ),
                      );
                }
              } catch (rowErr, st) {
                log.e('[watchArchivedNotes] row parse error', rowErr, st);
              }
            }

            log.d('[watchArchivedNotes] parsed notes: ${notesMap.length}');
            return notesMap.values.toList();
          });
    } catch (e, st) {
      log.e('[watchArchivedNotes] fatal error', e, st);
      rethrow;
    }
  }

  static Stream<List<NoteWithDetails>> watchDeletedNotes({
    String searchQuery = '',
    FilterOptions? filterOptions,
  }) {
    try {
      final database = getIt<AppDatabase>();
      final filters = filterOptions ?? FilterOptions.empty;
      log.d('[watchDeletedNotes] start; query="$searchQuery", filters: $filters');

      String whereClause = 'WHERE n.is_deleted = 1 AND n.note_type != \'todo\'';
      List<dynamic> variables = [];

      // Search in title, content, todo items, folder names, and attachment names (case-insensitive)
      if (searchQuery.isNotEmpty) {
        whereClause +=
            ' AND (n.note_title LIKE ? COLLATE NOCASE'
            ' OR tn.content LIKE ? COLLATE NOCASE'
            ' OR EXISTS (SELECT 1 FROM note_todo_items t WHERE t.note_id = n.id AND t.todo_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_folder_relations r INNER JOIN note_folders f ON r.note_folder_id = f.note_folder_id WHERE r.note_id = n.id AND f.note_folder_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_attachments a WHERE a.note_id = n.id AND a.attachment_name LIKE ? COLLATE NOCASE))';
        final searchPattern = '%$searchQuery%';
        variables = [searchPattern, searchPattern, searchPattern, searchPattern, searchPattern];
      }

      // Filter by folder IDs
      if (filters.folderIds.isNotEmpty) {
        final placeholders = List.filled(filters.folderIds.length, '?').join(',');
        whereClause += ' AND EXISTS (SELECT 1 FROM note_folder_relations r WHERE r.note_id = n.id AND r.note_folder_id IN ($placeholders))';
        variables.addAll(filters.folderIds);
      }

      // Filter by note types
      if (filters.noteTypes.isNotEmpty) {
        final placeholders = List.filled(filters.noteTypes.length, '?').join(',');
        whereClause += ' AND n.note_type IN ($placeholders)';
        variables.addAll(filters.noteTypes);
      }

      // Filter by date range
      if (filters.dateRangeStart != null) {
        whereClause += ' AND n.created_at >= ?';
        variables.add(filters.dateRangeStart!.millisecondsSinceEpoch ~/ 1000);
      }
      if (filters.dateRangeEnd != null) {
        final endDate = filters.dateRangeEnd!.add(const Duration(days: 1));
        whereClause += ' AND n.created_at < ?';
        variables.add(endDate.millisecondsSinceEpoch ~/ 1000);
      }

      // Filter by pins only
      if (filters.pinsOnly) {
        whereClause += ' AND n.is_pinned = 1';
      }

      final sql = '''
    SELECT
      n.*,
      tn.content AS text_content,
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
    LEFT JOIN text_notes tn ON n.id = tn.note_id
    LEFT JOIN note_attachments a ON n.id = a.note_id
    LEFT JOIN note_todo_items t ON n.id = t.note_id
    $whereClause
    GROUP BY n.id
    ORDER BY n.is_pinned DESC, n.updated_at DESC
    ''';

      log.d('[watchDeletedNotes] SQL: $sql');
      log.d('[watchDeletedNotes] vars: $variables');

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
            },
          )
          .watch()
          .handleError((e, st) {
            log.e('[watchDeletedNotes] stream error', e, st);
          })
          .map((rows) {
            log.d('[watchDeletedNotes] rows: ${rows.length}');
            final notesMap = <int, NoteWithDetails>{};

            for (final row in rows) {
              try {
                final noteId = row.read<int>('id');
                notesMap.putIfAbsent(noteId, () {
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

                  return NoteWithDetails(
                    note: Note(
                      id: noteId,
                      noteTitle: row.read<String?>('note_title'),
                      noteType: row.read<String>('note_type'),
                      isPinned: row.read<bool>('is_pinned'),
                      createdAt: row.read<DateTime>('created_at'),
                      updatedAt: row.read<DateTime>('updated_at'),
                      isArchived: row.read<bool?>('is_archived') ?? false,
                      isDeleted: row.read<bool?>('is_deleted') ?? false,
                      isSynced: row.read<bool?>('is_synced') ?? false,
                    ),
                    folders: folders,
                    attachments: [],
                    todoItems: [],
                    textContent: row.read<String?>('text_content'),
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
                          orderIndex: 0,
                        ),
                      );
                }
              } catch (rowErr, st) {
                log.e('[watchDeletedNotes] row parse error', rowErr, st);
              }
            }

            log.d('[watchDeletedNotes] parsed notes: ${notesMap.length}');
            return notesMap.values.toList();
          });
    } catch (e, st) {
      log.e('[watchDeletedNotes] fatal error', e, st);
      rethrow;
    }
  }

  static Stream<List<NoteWithDetails>> watchNotesWithDetails({
    String searchQuery = '',
    String sortType = 'updatedAt',
    String sortDirection = 'desc',
    FilterOptions? filterOptions,
  }) {
    try {
      final database = getIt<AppDatabase>();
      final filters = filterOptions ?? FilterOptions.empty;
      log.d(
          '[watchNotesWithDetails] start; query="$searchQuery", sort: $sortType $sortDirection, filters: $filters');

      String whereClause = 'WHERE n.is_archived = 0 AND n.is_deleted = 0 AND n.note_type != \'todo\'';
      List<dynamic> variables = [];

      // Search in title, content, todo items, folder names, and attachment names (case-insensitive)
      if (searchQuery.isNotEmpty) {
        whereClause +=
            ' AND (n.note_title LIKE ? COLLATE NOCASE'
            ' OR tn.content LIKE ? COLLATE NOCASE'
            ' OR EXISTS (SELECT 1 FROM note_todo_items t WHERE t.note_id = n.id AND t.todo_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_folder_relations r INNER JOIN note_folders f ON r.note_folder_id = f.note_folder_id WHERE r.note_id = n.id AND f.note_folder_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_attachments a WHERE a.note_id = n.id AND a.attachment_name LIKE ? COLLATE NOCASE))';
        final searchPattern = '%$searchQuery%';
        variables = [searchPattern, searchPattern, searchPattern, searchPattern, searchPattern];
      }

      // Filter by folder IDs
      if (filters.folderIds.isNotEmpty) {
        final placeholders = List.filled(filters.folderIds.length, '?').join(',');
        whereClause += ' AND EXISTS (SELECT 1 FROM note_folder_relations r WHERE r.note_id = n.id AND r.note_folder_id IN ($placeholders))';
        variables.addAll(filters.folderIds);
      }

      // Filter by note types
      if (filters.noteTypes.isNotEmpty) {
        final placeholders = List.filled(filters.noteTypes.length, '?').join(',');
        whereClause += ' AND n.note_type IN ($placeholders)';
        variables.addAll(filters.noteTypes);
      }

      // Filter by date range
      if (filters.dateRangeStart != null) {
        whereClause += ' AND n.created_at >= ?';
        variables.add(filters.dateRangeStart!.millisecondsSinceEpoch ~/ 1000);
      }
      if (filters.dateRangeEnd != null) {
        // Add 1 day to include the entire end date
        final endDate = filters.dateRangeEnd!.add(const Duration(days: 1));
        whereClause += ' AND n.created_at < ?';
        variables.add(endDate.millisecondsSinceEpoch ~/ 1000);
      }

      // Filter by pins only
      if (filters.pinsOnly) {
        whereClause += ' AND n.is_pinned = 1';
      }

      String orderBy;
      switch (sortType) {
        case 'createdAt':
          orderBy = 'n.created_at';
          break;
        case 'title':
          orderBy = 'n.note_title';
          break;
        case 'updatedAt':
        default:
          orderBy = 'n.updated_at';
          break;
      }

      final sql = '''
    SELECT
      n.*,
      tn.content AS text_content,
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
    LEFT JOIN text_notes tn ON n.id = tn.note_id
    LEFT JOIN note_attachments a ON n.id = a.note_id
    LEFT JOIN note_todo_items t ON n.id = t.note_id
    $whereClause
    GROUP BY n.id
    ORDER BY n.is_pinned DESC, $orderBy ${sortDirection.toUpperCase()}
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

                    return NoteWithDetails(
                      note: Note(
                        id: noteId,
                        noteTitle: row.read<String?>('note_title'),
                        noteType: row.read<String>('note_type'),
                        isPinned: row.read<bool>('is_pinned'),
                        createdAt: row.read<DateTime>('created_at'),
                        updatedAt: row.read<DateTime>('updated_at'),
                        isArchived: row.read<bool?>('is_archived') ?? false,
                        isDeleted: row.read<bool?>('is_deleted') ?? false,
                        isSynced: row.read<bool?>('is_synced') ?? false,
                      ),
                      folders: folders,
                      attachments: [],
                      todoItems: [],
                      textContent: row.read<String?>('text_content'),
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
                            orderIndex: 0, // TODO: Read from database
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

  static Stream<List<NoteWithDetails>> watchNotesWithDetailsByFolder({
    required int folderId,
    String searchQuery = '',
    FilterOptions? filterOptions,
  }) {
    try {
      final database = getIt<AppDatabase>();
      final filters = filterOptions ?? FilterOptions.empty;
      log.d('[watchNotesWithDetailsByFolder] start; folderId=$folderId, query="$searchQuery", filters: $filters');

      String whereClause = 'WHERE r.note_folder_id = ? AND n.is_archived = 0 AND n.is_deleted = 0';
      List<dynamic> variables = [folderId];

      // Search in title, content, todo items, folder names, and attachment names (case-insensitive)
      if (searchQuery.isNotEmpty) {
        whereClause +=
            ' AND (n.note_title LIKE ? COLLATE NOCASE'
            ' OR tn.content LIKE ? COLLATE NOCASE'
            ' OR EXISTS (SELECT 1 FROM note_todo_items t WHERE t.note_id = n.id AND t.todo_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_folder_relations r2 INNER JOIN note_folders f2 ON r2.note_folder_id = f2.note_folder_id WHERE r2.note_id = n.id AND f2.note_folder_title LIKE ? COLLATE NOCASE)'
            ' OR EXISTS (SELECT 1 FROM note_attachments a WHERE a.note_id = n.id AND a.attachment_name LIKE ? COLLATE NOCASE))';
        final searchPattern = '%$searchQuery%';
        variables.addAll([searchPattern, searchPattern, searchPattern, searchPattern, searchPattern]);
      }

      // Filter by note types
      if (filters.noteTypes.isNotEmpty) {
        final placeholders = List.filled(filters.noteTypes.length, '?').join(',');
        whereClause += ' AND n.note_type IN ($placeholders)';
        variables.addAll(filters.noteTypes);
      }

      // Filter by date range
      if (filters.dateRangeStart != null) {
        whereClause += ' AND n.created_at >= ?';
        variables.add(filters.dateRangeStart!.millisecondsSinceEpoch ~/ 1000);
      }
      if (filters.dateRangeEnd != null) {
        final endDate = filters.dateRangeEnd!.add(const Duration(days: 1));
        whereClause += ' AND n.created_at < ?';
        variables.add(endDate.millisecondsSinceEpoch ~/ 1000);
      }

      // Filter by pins only
      if (filters.pinsOnly) {
        whereClause += ' AND n.is_pinned = 1';
      }

      final sql = '''
        SELECT
          n.*,
          tn.content AS text_content,
          (
            SELECT json_group_array(json_object(
              'id', f.note_folder_id,
              'title', f.note_folder_title
            ))
            FROM note_folders f
            INNER JOIN note_folder_relations r_inner ON f.note_folder_id = r_inner.note_folder_id
            WHERE r_inner.note_id = n.id
          ) AS folders,
          a.attachment_mime_type AS attachment_mime_type,
          a.attachment_path AS attachment_path,
          a.attachment_name AS attachment_name,
          t.id AS todo_id,
          t.todo_title AS todo_title,
          t.is_done AS todo_is_done
        FROM notes n
        INNER JOIN note_folder_relations r ON n.id = r.note_id
        LEFT JOIN text_notes tn ON n.id = tn.note_id
        LEFT JOIN note_attachments a ON n.id = a.note_id
        LEFT JOIN note_todo_items t ON n.id = t.note_id
        $whereClause
        GROUP BY n.id
        ORDER BY n.is_pinned DESC, n.updated_at DESC
      ''';

      log.d('[watchNotesWithDetailsByFolder] SQL: $sql');
      log.d('[watchNotesWithDetailsByFolder] vars: $variables');

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
            },
          )
          .watch()
          .handleError((e, st) {
            log.e('[watchNotesWithDetailsByFolder] stream error', e, st);
          })
          .map((rows) {
            log.d('[watchNotesWithDetailsByFolder] rows: ${rows.length} for folderId=$folderId');
            final notesMap = <int, NoteWithDetails>{};

            for (final row in rows) {
              try {
                final noteId = row.read<int>('id');
                notesMap.putIfAbsent(noteId, () {
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

                  return NoteWithDetails(
                    note: Note(
                      id: noteId,
                      noteTitle: row.read<String?>('note_title'),
                      noteType: row.read<String>('note_type'),
                      isPinned: row.read<bool>('is_pinned'),
                      createdAt: row.read<DateTime>('created_at'),
                      updatedAt: row.read<DateTime>('updated_at'),
                      isArchived: row.read<bool?>('is_archived') ?? false,
                      isDeleted: row.read<bool?>('is_deleted') ?? false,
                      isSynced: row.read<bool?>('is_synced') ?? false,
                    ),
                    folders: folders,
                    attachments: [],
                    todoItems: [],
                    textContent: row.read<String?>('text_content'),
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
                          orderIndex: 0,
                        ),
                      );
                }
              } catch (rowErr, st) {
                log.e('[watchNotesWithDetailsByFolder] row parse error', rowErr, st);
              }
            }

            log.d('[watchNotesWithDetailsByFolder] parsed notes: ${notesMap.length}');
            return notesMap.values.toList();
          });
    } catch (e, st) {
      log.e('[watchNotesWithDetailsByFolder] fatal error', e, st);
      rethrow;
    }
  }

  static Stream<List<NoteTodoItemWithNote>> watchAllTodoItems() {
    try {
      final database = getIt<AppDatabase>();
      log.d('[watchAllTodoItems] start');

      final sql = '''
        SELECT
          t.id AS todo_id,
          t.note_id AS todo_note_id,
          t.todo_title AS todo_title,
          t.is_done AS todo_is_done,
          n.note_title AS note_title,
          tn.content AS note_content,
          n.created_at AS note_created_at,
          n.updated_at AS note_updated_at,
          n.note_type AS note_type
        FROM note_todo_items t
        INNER JOIN notes n ON t.note_id = n.id
        LEFT JOIN text_notes tn ON n.id = tn.note_id
        WHERE n.is_archived = 0 AND n.is_deleted = 0
        ORDER BY n.is_pinned DESC, n.updated_at DESC, t.id ASC
      ''';

      log.d('[watchAllTodoItems] SQL: $sql');

      return database
          .customSelect(
            sql,
            readsFrom: {
              database.noteTodoItems,
              database.notes,
            },
          )
          .watch()
          .handleError((e, st) {
            log.e('[watchAllTodoItems] stream error', e, st);
          })
          .map((rows) {
            log.d('[watchAllTodoItems] rows: ${rows.length}');
            return rows.map((row) {
              try {
                final noteTitle = row.read<String?>('note_title');
                final noteContent = row.read<String?>('note_content');

                return NoteTodoItemWithNote(
                  todoItem: NoteTodoItem(
                    id: row.read<int>('todo_id'),
                    noteId: row.read<int>('todo_note_id'),
                    todoTitle: row.read<String>('todo_title'),
                    isDone: row.read<bool>('todo_is_done'),
                    orderIndex: 0, // TODO: Read from database
                  ),
                  noteTitle: getNoteTitleOrPreview(noteTitle, noteContent),
                  noteContent: noteContent,
                  noteCreatedAt: row.read<DateTime>('note_created_at'),
                  noteUpdatedAt: row.read<DateTime>('note_updated_at'),
                  noteType: row.read<String>('note_type'),
                );
              } catch (rowErr, st) {
                log.e('[watchAllTodoItems] row parse error', rowErr, st);
                rethrow;
              }
            }).toList();
          });
    } catch (e, st) {
      log.e('[watchAllTodoItems] fatal error', e, st);
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
      return SecureEncryptionService.decrypt(v);
    } catch (_) {
      return value;
    }
  }

  static Future<void> importNoteFromJson(String jsonString) async {
    final database = getIt<AppDatabase>();
    final noteJson = jsonDecode(jsonString);

    final title = noteJson['title'] as String;
    final content = noteJson['content'] as String? ?? '';
    final now = DateTime.now();

    final noteCompanion = NotesCompanion.insert(
      noteTitle: drift.Value(title),
      isPinned: drift.Value(false),
      noteType: 'text', // Changed from defaultNoteType to noteType
      createdAt: now,
      updatedAt: now,
    );

    final noteId = await database.into(database.notes).insert(noteCompanion);

    // Insert text content into TextNotes table
    if (content.isNotEmpty) {
      await database.into(database.textNotes).insert(
        TextNotesCompanion(
          noteId: drift.Value(noteId),
          content: drift.Value(content),
        ),
      );
    }

    final folderTitles = noteJson['folders'] as List<dynamic>;
    final folders = <NoteFolderDto>[];
    for (final title in folderTitles) {
      final existingFolder = await (database.select(database.noteFolders)
            ..where((tbl) => tbl.noteFolderTitle.equals(title)))
          .getSingleOrNull();
      if (existingFolder != null) {
        folders.add(NoteFolderDto(
            id: existingFolder.noteFolderId,
            title: existingFolder.noteFolderTitle));
      } else {
        final newFolderId = await database.into(database.noteFolders).insert(
            NoteFoldersCompanion.insert(
                noteFolderTitle: title, createdAt: now, updatedAt: now));
        folders.add(NoteFolderDto(id: newFolderId, title: title));
      }
    }
    await DriftNoteFolderService.upsertNoteFoldersWithNote(folders, noteId);
  }
}
