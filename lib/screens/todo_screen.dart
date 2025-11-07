import 'package:flutter/material.dart';
import 'package:pinpoint/models/note_todo_item_with_note.dart';
import 'package:pinpoint/services/drift_note_service.dart';
import 'package:pinpoint/database/database.dart';
import '../design_system/design_system.dart';

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

                return AnimatedListStagger(
                  itemCount: filteredTodos.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final todoWithNote = filteredTodos[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TodoCard(
                        todo: todoWithNote.todoItem,
                        noteTitle: todoWithNote.noteTitle,
                        onCheckboxChanged: (value) {
                          if (value != null) {
                            PinpointHaptics.light();
                            _toggleTodoStatus(todoWithNote.todoItem.id, value);
                          }
                        },
                        onTap: () {
                          PinpointHaptics.medium();
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
        onPressed: () {
          PinpointHaptics.medium();
          _showAddTodoDialog();
        },
        child: const Icon(Icons.add_rounded),
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

  Future<void> _showAddTodoDialog() async {
    await ConfirmSheet.show(
      context: context,
      title: 'Add Todo',
      message:
          'To add a new todo, you need to create it within a note. Please go to the Notes screen and create a new note with todo list type, or edit an existing note to add todos.',
      primaryLabel: 'OK',
      icon: Icons.info_outline_rounded,
    );
  }
}

class _TodoCard extends StatefulWidget {
  final NoteTodoItem todo;
  final String noteTitle;
  final VoidCallback? onTap;
  final Function(bool?)? onCheckboxChanged;

  const _TodoCard({
    required this.todo,
    required this.noteTitle,
    this.onTap,
    this.onCheckboxChanged,
  });

  @override
  State<_TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<_TodoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (widget.onTap != null) widget.onTap!();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: PinpointAnimations.durationFast,
        curve: PinpointAnimations.emphasized,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: PinpointElevations.md(theme.brightness),
          ),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 20,
            child: Row(
              children: [
                // Checkbox
                Checkbox(
                  value: widget.todo.isDone,
                  onChanged: widget.onCheckboxChanged,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.todo.todoTitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: widget.todo.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: widget.todo.isDone
                              ? cs.onSurface.withAlpha(150)
                              : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.note_rounded,
                            size: 14,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.noteTitle,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.onSurface.withAlpha(180),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
