import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class TodoListTypeContent extends HookWidget {
  const TodoListTypeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final todos = useState<List<TodoItem>>([]);

    void addTodo() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          final TextEditingController controller = TextEditingController();
          return Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add Todo',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'Enter todo'),
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      todos.value = [
                        ...todos.value,
                        TodoItem(title: controller.text)
                      ];
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
      );
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
            AnimatedList(
              key: ValueKey(todos.value.length),
              initialItemCount: todos.value.length,
              itemBuilder: (context, index, animation) {
                final todo = todos.value[index];
                return SizeTransition(
                  sizeFactor: animation,
                  child: ListTile(
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        decoration:
                            todo.isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    leading: Checkbox(
                      value: todo.isDone,
                      onChanged: (value) {
                        todos.value = [
                          for (var t in todos.value)
                            if (t == todo)
                              t.copyWith(isDone: value ?? false)
                            else
                              t
                        ];
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteTodo(todo),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: FloatingActionButton(
                onPressed: addTodo,
                backgroundColor: kPrimaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodoItem {
  final String title;
  final bool isDone;

  TodoItem({required this.title, this.isDone = false});

  TodoItem copyWith({String? title, bool? isDone}) {
    return TodoItem(
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
}
