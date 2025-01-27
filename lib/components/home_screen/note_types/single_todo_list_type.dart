import 'package:flutter/material.dart';

class SingleTodoListType extends StatefulWidget {
  const SingleTodoListType({super.key});

  @override
  State<SingleTodoListType> createState() => _SingleTodoListTypeState();
}

class _SingleTodoListTypeState extends State<SingleTodoListType> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final darkerColor =
        isDarkTheme ? Colors.grey.shade400 : Colors.grey.shade600;
    return Row(
      children: [
        SizedBox(
          height: 36,
          width: 24,
          child: Checkbox.adaptive(
            side: BorderSide(
              color: kPrimaryColor.withValues(
                alpha: 0.5,
              ),
            ),
            value: selected,
            onChanged: (value) => setState(
              () => selected = !selected,
            ),
          ),
        ),
        SizedBox(width: 2),
        Flexible(
          child: Text(
            'Buy Eggs or something',
            style: TextStyle(
              fontSize: 14,
              overflow: TextOverflow.ellipsis,
              color: darkerColor,
              decoration:
                  selected ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
