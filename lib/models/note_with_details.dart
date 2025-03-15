import 'package:pinpoint/dtos/note_attachment_dto.dart';

import '../components/create_note_screen/todo_list_type/todo_list_type_content.dart';
import '../database/database.dart';
import '../dtos/note_folder_dto.dart';

class NoteWithDetails {
  final Note note;
  final List<NoteFolderDto> folders; // List of folders
  final List<NoteAttachmentDto> attachments;
  final List<TodoItem> todoItems;

  NoteWithDetails({
    required this.note,
    required this.folders,
    required this.attachments,
    required this.todoItems,
  });
}
