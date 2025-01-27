import 'package:flutter/material.dart';
import 'package:pinpoint/components/home_screen/note_types/single_todo_list_type.dart';

class TodoListType extends StatelessWidget {
  const TodoListType({super.key});

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Todo List',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: 6,
            padding: EdgeInsets.symmetric(vertical: 5),
            itemBuilder: (context, index) {
              return SingleTodoListType();
            },
          ),
        ],
      ),
    );
  }
}
