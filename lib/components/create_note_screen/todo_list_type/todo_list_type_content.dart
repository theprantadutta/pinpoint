import 'package:flutter/material.dart';
import 'package:pinpoint/database/database.dart';

import '../../../services/dialog_service.dart';

class TodoListTypeContent extends StatefulWidget {
  final List<NoteTodoItem> todos;
  final Function(List<NoteTodoItem> newTodoItems) onTodoChanged;

  const TodoListTypeContent({
    super.key,
    required this.todos,
    required this.onTodoChanged,
  });

  @override
  State<TodoListTypeContent> createState() => _TodoListTypeContentState();
}

class _TodoListTypeContentState extends State<TodoListTypeContent> {
  void addTodo() {
    final TextEditingController controller = TextEditingController();
    DialogService.addSomethingDialog(
      context: context,
      controller: controller,
      title: 'Add Todo',
      hintText: 'Enter todo',
      onAddPressed: () async {
        if (controller.text.isNotEmpty) {
          // Create a temporary todo item with a negative ID to indicate it's not yet saved
          final newTodo = NoteTodoItem(
            id: -(widget.todos.length + 1), // Negative ID for temporary items
            noteId: 0, // Will be updated when note is saved
            todoTitle: controller.text,
            isDone: false,
          );

          widget.onTodoChanged([
            ...widget.todos,
            newTodo,
          ]);

          if (!mounted) return;
          Navigator.pop(context);
        }
      },
    );
  }

  void markAllAsDone() async {
    final updatedTodos = [for (var t in widget.todos) t.copyWith(isDone: true)];
    widget.onTodoChanged(updatedTodos);
  }

  void deleteTodo(NoteTodoItem todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${todo.todoTitle}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              widget.onTodoChanged(
                  widget.todos.where((t) => t.id != todo.id).toList());
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void updateTodo(NoteTodoItem todo) {
    final TextEditingController controller =
        TextEditingController(text: todo.todoTitle);
    DialogService.addSomethingDialog(
      context: context,
      controller: controller,
      title: 'Update Todo',
      hintText: 'Enter todo',
      onAddPressed: () async {
        if (controller.text.isNotEmpty) {
          widget.onTodoChanged([
            for (var t in widget.todos)
              if (t.id == todo.id) t.copyWith(todoTitle: controller.text) else t
          ]);
          if (!mounted) return;
          Navigator.pop(context);
        }
      },
    );
  }

  void markTodo(NoteTodoItem todo, bool? value) async {
    widget.onTodoChanged([
      for (var t in widget.todos)
        if (t.id == todo.id) t.copyWith(isDone: value ?? false) else t
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            children: [
              // Todo List (Scrollable)
              Expanded(
                child: widget.todos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 64,
                              color: cs.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No todos yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first todo to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.todos.length,
                        itemBuilder: (context, index) {
                          final todo = widget.todos[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                                    : cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: todo.isDone
                                      ? cs.primary.withValues(alpha: 0.3)
                                      : cs.outline.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: Checkbox(
                                  value: todo.isDone,
                                  activeColor: cs.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  onChanged: (bool? value) => markTodo(todo, value),
                                ),
                                title: GestureDetector(
                                  onTap: () => markTodo(todo, !todo.isDone),
                                  child: Text(
                                    todo.todoTitle,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                      decoration: todo.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') updateTodo(todo);
                                    if (value == 'delete') deleteTodo(todo);
                                  },
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_rounded,
                                               size: 20,
                                               color: cs.primary),
                                          const SizedBox(width: 12),
                                          const Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_rounded,
                                               size: 20,
                                               color: cs.error),
                                          const SizedBox(width: 12),
                                          const Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Action Buttons (Fixed at bottom)
              Row(
                children: [
                  if (widget.todos.isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: markAllAsDone,
                        icon: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                        label: Text('Mark All Done'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: addTodo,
                      icon: Icon(Icons.add_rounded, size: 20),
                      label: Text('Add Todo'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
