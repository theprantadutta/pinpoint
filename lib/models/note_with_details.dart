import 'package:pinpoint/dtos/note_attachment_dto.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';

class NoteWithDetails {
  final Note note;
  final List<NoteFolderDto> folders; // List of folders
  final List<NoteAttachmentDto> attachments;
  final List<NoteTodoItem> todoItems;
  final String? textContent; // Content from TextNotes table

  /// Note colour name (a pastel, or a legacy Keep name); null = no colour.
  final String? color;

  /// Voice notes: recording length, for the "Voice · 0:42" card caption.
  final int? voiceDurationSeconds;

  /// Reminder notes: when it fires, for the reminder chip.
  final DateTime? reminderAt;

  NoteWithDetails({
    required this.note,
    required this.folders,
    required this.attachments,
    required this.todoItems,
    this.textContent,
    this.color,
    this.voiceDurationSeconds,
    this.reminderAt,
  });
}
