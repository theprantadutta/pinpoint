import 'package:flutter/material.dart';
import 'package:pinpoint/design/widgets/todo_item.dart';
import 'package:pinpoint/models/note_todo_item_with_note.dart';
import 'package:pinpoint/services/drift_note_service.dart';

class TodoScreen extends StatefulWidget {
  static const String kRouteName = '/todo';
  
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  String _filter = 'all'; // all, completed, pending

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String result) {
              setState(() {
                _filter = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('All Todos'),
              ),
              const PopupMenuItem<String>(
                value: 'pending',
                child: Text('Pending'),
              ),
              const PopupMenuItem<String>(
                value: 'completed',
                child: Text('Completed'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<NoteTodoItemWithNote>>(
        stream: DriftNoteService.watchAllTodoItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading todos: ${snapshot.error}'),
            );
          }

          final allTodos = snapshot.data ?? [];
          final filteredTodos = _filterTodos(allTodos, _filter);

          if (filteredTodos.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: filteredTodos.length,
            itemBuilder: (context, index) {
              final todoWithNote = filteredTodos[index];
              return TodoItem(
                todo: todoWithNote.todoItem,
                noteTitle: todoWithNote.noteTitle,
                onCheckboxChanged: (value) {
                  if (value != null) {
                    _toggleTodoStatus(todoWithNote.todoItem.id, value);
                  }
                },
                onTap: () {
                  // TODO: Navigate to the note containing this todo
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTodoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'No todos yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first todo to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showAddTodoDialog,
            child: const Text('Add Your First Todo'),
          ),
        ],
      ),
    );
  }

  List<NoteTodoItemWithNote> _filterTodos(
      List<NoteTodoItemWithNote> todos, String filter) {
    switch (filter) {
      case 'completed':
        return todos.where((todo) => todo.todoItem.isDone).toList();
      case 'pending':
        return todos.where((todo) => !todo.todoItem.isDone).toList();
      case 'all':
      default:
        return todos;
    }
  }

  void _toggleTodoStatus(int todoId, bool isDone) {
    DriftNoteService.updateTodoItemStatus(todoId, isDone);
  }

  void _showAddTodoDialog() {
    // TODO: Implement add todo functionality
    // This would require creating a new note or adding to an existing note
    // For now, we'll show a simple dialog explaining the process
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Todo'),
          content: const Text(
            'To add a new todo, you need to create it within a note. Please go to the Notes screen and create a new note with todo list type, or edit an existing note to add todos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
