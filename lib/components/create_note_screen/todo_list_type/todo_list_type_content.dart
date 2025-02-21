import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../services/dialog_service.dart';

class TodoListTypeContent extends HookWidget {
  const TodoListTypeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final todos = useState<List<TodoItem>>([]);

    void addTodo() {
      final TextEditingController controller = TextEditingController();
      DialogService.addSomethingDialog(
        context: context,
        controller: controller,
        title: 'Add Todo',
        hintText: 'Enter todo',
        onAddPressed: () {
          final id = todos.value.length + 1;
          debugPrint('Unique ID: $id');
          if (controller.text.isNotEmpty) {
            todos.value = [
              ...todos.value,
              TodoItem(
                id: id,
                title: controller.text,
              ),
            ];
            Navigator.pop(context);
          }
        },
      );
    }

    void markAllAsDone() {
      todos.value = [for (var t in todos.value) t.copyWith(isDone: true)];
    }

    void deleteTodo(TodoItem todo) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "${todo.title}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                todos.value = todos.value.where((t) => t != todo).toList();
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    void updateTodo(TodoItem todo) {
      todos.value = [
        for (var t in todos.value)
          if (t.id == todo.id) t.copyWith(title: todo.title) else t
      ];
    }

    void markTodo(TodoItem todo, bool? value) {
      todos.value = [
        for (var t in todos.value)
          if (t.id == todo.id) t.copyWith(isDone: value ?? false) else t
      ];
    }

    return SliverToBoxAdapter(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.59,
        padding: EdgeInsets.symmetric(
          vertical: 5,
          horizontal: 0,
        ),
        margin: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            if (todos.value.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 80,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Nothing Yet!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              margin: EdgeInsets.symmetric(vertical: 5),
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: AnimatedList(
                key: ValueKey(todos.value.length),
                initialItemCount: todos.value.length,
                itemBuilder: (context, index, animation) {
                  final todo = todos.value[index];
                  final isDarkTheme =
                      Theme.of(context).brightness == Brightness.dark;

                  return SizeTransition(
                    sizeFactor: animation,
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkTheme ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: todo.isDone
                                ? kPrimaryColor.withValues(alpha: 0.5)
                                : (isDarkTheme
                                    ? Colors.grey[700]!
                                    : Colors.grey[400]!),
                            width: 1.5,
                          ),
                          boxShadow: [
                            if (!isDarkTheme)
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: GestureDetector(
                            onTap: () => markTodo(todo, !todo.isDone),
                            child: Text(
                              todo.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDarkTheme ? Colors.white : Colors.black,
                                decoration: todo.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          leading: Checkbox(
                            value: todo.isDone,
                            activeColor: kPrimaryColor.withValues(
                                alpha: isDarkTheme ? 0.6 : 0.9),
                            checkColor:
                                isDarkTheme ? Colors.black : Colors.white,
                            onChanged: (bool? value) => markTodo(todo, value),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') updateTodo(todo);
                              if (value == 'delete') deleteTodo(todo);
                            },
                            icon: Icon(Icons.more_vert,
                                color: isDarkTheme
                                    ? Colors.white70
                                    : Colors.black54),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.055,
                child: Row(
                  children: [
                    FloatingActionButton.extended(
                      heroTag: UniqueKey(),
                      onPressed: markAllAsDone,
                      backgroundColor: kPrimaryColor,
                      label: Text(
                        'Mark All As Done',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10),
                    FloatingActionButton.extended(
                      heroTag: UniqueKey(),
                      onPressed: addTodo,
                      backgroundColor: kPrimaryColor,
                      label: Text(
                        'Add Todo',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      icon: Icon(
                        Icons.add_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodoItem {
  final int id;
  final String title;
  final bool isDone;

  TodoItem({required this.id, required this.title, this.isDone = false});

  TodoItem copyWith({int? id, String? title, bool? isDone}) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
}
