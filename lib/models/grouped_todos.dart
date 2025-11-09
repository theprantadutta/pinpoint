import 'package:pinpoint/models/note_todo_item_with_note.dart';

class GroupedTodos {
  final int noteId;
  final String noteTitle;
  final String noteType;
  final List<NoteTodoItemWithNote> todos;

  GroupedTodos({
    required this.noteId,
    required this.noteTitle,
    required this.noteType,
    required this.todos,
  });

  int get totalItems => todos.length;
  int get completedItems => todos.where((t) => t.todoItem.isDone).length;
  int get pendingItems => totalItems - completedItems;
}
