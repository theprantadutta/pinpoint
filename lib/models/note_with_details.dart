import 'package:pinpoint/dtos/note_attachment_dto.dart';

import '../database/database.dart';
import '../dtos/note_folder_dto.dart';

class NoteWithDetails {
  final Note note;
  final List<NoteFolderDto> folders; // List of folders
  final List<NoteAttachmentDto> attachments;
  final List<NoteTodoItem> todoItems;
  final String? textContent; // Content from TextNotes table

  /// Keep-style color swatch name (e.g. 'storm'); null = default card color.
  final String? color;

  NoteWithDetails({
    required this.note,
    required this.folders,
    required this.attachments,
    required this.todoItems,
    this.textContent,
    this.color,
  });
}
