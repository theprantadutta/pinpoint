import 'package:flutter/material.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/design/app_theme.dart';

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
    final text = Theme.of(context);
    final cs = text.colorScheme;
    final dark = text.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: AppTheme.radiusL,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.radiusL,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppTheme.radiusL,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(dark ? 70 : 25),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: cs.primary.withAlpha(dark ? 25 : 15),
                  blurRadius: 36,
                  spreadRadius: -6,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppTheme.radiusL,
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      borderRadius: AppTheme.radiusL,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x1A7C3AED),
                          Color(0x1110B981),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.radiusL,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(dark ? 5 : 50),
                            Colors.transparent,
                            Colors.black.withAlpha(dark ? 60 : 15),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (dark ? const Color(0xFF0F1218) : Colors.white)
                          .withAlpha(200),
                      borderRadius: AppTheme.radiusL,
                      border: Border.all(
                        color: (dark ? Colors.white : Colors.black).withAlpha(15),
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
                                style: text.textTheme.bodyMedium?.copyWith(
                                  decoration: todo.isDone ? TextDecoration.lineThrough : null,
                                  color: todo.isDone
                                      ? (dark ? Colors.grey.shade400 : Colors.grey.shade600)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'In note: $noteTitle',
                                style: text.textTheme.labelSmall?.copyWith(
                                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}