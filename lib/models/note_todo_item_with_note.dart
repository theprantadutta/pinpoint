import 'package:pinpoint/database/database.dart';

class NoteTodoItemWithNote {
  final NoteTodoItem todoItem;
  final String noteTitle;
  final String? noteContent;
  final DateTime noteCreatedAt;
  final DateTime noteUpdatedAt;
  final String defaultNoteType;

  NoteTodoItemWithNote({
    required this.todoItem,
    required this.noteTitle,
    this.noteContent,
    required this.noteCreatedAt,
    required this.noteUpdatedAt,
    required this.defaultNoteType,
  });
}
