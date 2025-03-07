import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/dtos/note_attachment_dto.dart';

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
      NotesCompanion note, int? previousNoteId) async {
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
        final existingAttachment = await (database
                .select(database.noteAttachments)
              ..where((tbl) =>
                  tbl.path.equals(attachment.path) & tbl.noteId.equals(noteId)))
            .getSingleOrNull();

        final attachmentCompanion = NoteAttachmentsCompanion(
          name: Value(attachment.name),
          noteId: Value(noteId),
          mimeType: Value(attachment.mimeType),
          path: Value(attachment.path),
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
}
