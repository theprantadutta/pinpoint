import 'package:pinpoint/database/database.dart';

class NoteTodoItemWithNote {
  final NoteTodoItem todoItem;
  final String noteTitle;
  final DateTime noteCreatedAt;
  final DateTime noteUpdatedAt;

  NoteTodoItemWithNote({
    required this.todoItem,
    required this.noteTitle,
    required this.noteCreatedAt,
    required this.noteUpdatedAt,
  });
}
