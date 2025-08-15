import 'package:flutter/material.dart';
import 'package:pinpoint/database/database.dart';

class TodoItem extends StatelessWidget {
  final NoteTodoItem todo;
  final String noteTitle;
  final VoidCallback? onTap;
  final Function(bool?)? onCheckboxChanged;

  const TodoItem({
    super.key,
    required this.todo,
    required this.noteTitle,
    this.onTap,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: dark ? Colors.grey.shade800 : Colors.grey.shade300,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: todo.isDone,
              onChanged: onCheckboxChanged,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.todoTitle,
                    style: text.bodyMedium?.copyWith(
                      decoration: todo.isDone ? TextDecoration.lineThrough : null,
                      color: todo.isDone
                          ? (dark ? Colors.grey.shade400 : Colors.grey.shade600)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'In note: $noteTitle',
                    style: text.labelSmall?.copyWith(
                      color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}