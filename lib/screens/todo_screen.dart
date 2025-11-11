import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/models/note_todo_item_with_note.dart';
import 'package:pinpoint/models/grouped_todos.dart';
import 'package:pinpoint/screen_arguments/create_note_screen_arguments.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import '../design_system/design_system.dart';
import 'create_note_screen.dart';

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

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Todos'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (String result) {
              PinpointHaptics.selection();
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  _filter == 'all'
                      ? 'All Todos'
                      : _filter == 'pending'
                          ? 'Pending'
                          : 'Completed',
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
                    return TagChip(
                      label: '${filteredTodos.length}',
                      color: cs.primary,
                      size: TagChipSize.small,
                    );
                  },
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<List<NoteTodoItemWithNote>>(
              stream: DriftNoteService.watchAllTodoItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Error loading todos',
                    message: 'Please try again later',
                  );
                }

                final allTodos = snapshot.data ?? [];
                final filteredTodos = _filterTodos(allTodos, _filter);
                final groupedTodos = _groupTodosByNote(filteredTodos);

                if (filteredTodos.isEmpty) {
                  return EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: _filter == 'all'
                        ? 'No todos yet'
                        : _filter == 'pending'
                            ? 'No pending todos'
                            : 'No completed todos',
                    message: _filter == 'all'
                        ? 'Create notes with todo lists to see them here'
                        : '',
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                  itemCount: groupedTodos.length,
                  itemBuilder: (context, groupIndex) {
                    final group = groupedTodos[groupIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _TodoGroup(
                        group: group,
                        onTodoToggle: (todoId, isDone) {
                          PinpointHaptics.light();
                          _toggleTodoStatus(todoId, isDone);
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () {
            PinpointHaptics.medium();
            // Navigate to create note screen with Todo List pre-selected
            context.push(
              CreateNoteScreen.kRouteName,
              extra: CreateNoteScreenArguments(
                noticeType: 'Todo List',
              ),
            );
          },
          child: const Icon(Icons.add_rounded),
        ),
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

  List<GroupedTodos> _groupTodosByNote(List<NoteTodoItemWithNote> todos) {
    final Map<int, List<NoteTodoItemWithNote>> grouped = {};

    for (final todo in todos) {
      if (!grouped.containsKey(todo.todoItem.noteId)) {
        grouped[todo.todoItem.noteId] = [];
      }
      grouped[todo.todoItem.noteId]!.add(todo);
    }

    return grouped.entries.map((entry) {
      final firstTodo = entry.value.first;
      return GroupedTodos(
        noteId: entry.key,
        noteTitle: firstTodo.noteTitle,
        noteType: firstTodo.noteType,
        todos: entry.value,
      );
    }).toList();
  }

  void _toggleTodoStatus(int todoId, bool isDone) {
    DriftNoteService.updateTodoItemStatus(todoId, isDone);
  }
}

class _TodoGroup extends StatelessWidget {
  final GroupedTodos group;
  final Function(int todoId, bool isDone) onTodoToggle;

  const _TodoGroup({
    required this.group,
    required this.onTodoToggle,
  });

  Future<void> _openNote(BuildContext context) async {
    try {
      PinpointHaptics.medium();

      // Fetch the full note with details
      final noteWithDetails =
          await DriftNoteService.getSingleNoteWithDetails(group.noteId);

      if (noteWithDetails == null) {
        if (context.mounted) {
          showErrorToast(
            context: context,
            title: 'Note not found',
            description: 'The note could not be loaded',
          );
        }
        return;
      }

      if (context.mounted) {
        context.push(
          CreateNoteScreen.kRouteName,
          extra: CreateNoteScreenArguments(
            noticeType: group.noteType,
            existingNote: noteWithDetails,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(
          context: context,
          title: 'Error',
          description: 'Failed to open note: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with note title
          GestureDetector(
            onTap: () => _openNote(context),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.noteTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TagChip(
                  label: '${group.completedItems}/${group.totalItems}',
                  color: cs.primary,
                  size: TagChipSize.small,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withAlpha(150),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Todo items
          ...group.todos.asMap().entries.map((entry) {
            final index = entry.key;
            final todoWithNote = entry.value;
            final isLast = index == group.todos.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: _TodoItem(
                todo: todoWithNote.todoItem,
                onCheckboxChanged: (value) {
                  if (value != null) {
                    onTodoToggle(todoWithNote.todoItem.id, value);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TodoItem extends StatelessWidget {
  final NoteTodoItem todo;
  final Function(bool?)? onCheckboxChanged;

  const _TodoItem({
    required this.todo,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Checkbox(
          value: todo.isDone,
          onChanged: onCheckboxChanged,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            todo.todoTitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: todo.isDone ? TextDecoration.lineThrough : null,
              color: todo.isDone ? cs.onSurface.withAlpha(150) : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

