import 'package:flutter/material.dart';
import 'package:pinpoint/design/widgets/todo_item.dart';
import 'package:pinpoint/models/note_todo_item_with_note.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/design/app_theme.dart';
import 'package:pinpoint/components/shared/empty_state_widget.dart';

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background
          Glass(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Todos',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<List<NoteTodoItemWithNote>>(
                      stream: DriftNoteService.watchAllTodoItems(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox();
                        }
                        final allTodos = snapshot.data ?? [];
                        final filteredTodos = _filterTodos(allTodos, _filter);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            '${filteredTodos.length}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.22),
                        cs.primary.withValues(alpha: 0.0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Content
          Expanded(
            child: StreamBuilder<List<NoteTodoItemWithNote>>(
              stream: DriftNoteService.watchAllTodoItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: EmptyStateWidget(
                      message: 'Error loading todos: ${snapshot.error}',
                      iconData: Icons.error_outline,
                    ),
                  );
                }

                final allTodos = snapshot.data ?? [];
                final filteredTodos = _filterTodos(allTodos, _filter);

                if (filteredTodos.isEmpty) {
                  return Center(
                    child: EmptyStateWidget(
                      message: 'No todos yet.\nAdd your first todo to get started',
                      iconData: Icons.check_circle_outline,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                  itemCount: filteredTodos.length,
                  itemBuilder: (context, index) {
                    final todoWithNote = filteredTodos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TodoItem(
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTodoDialog,
        child: const Icon(Icons.add),
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