import 'package:flutter/material.dart';

Future<void> showTextFormDialog(
  BuildContext context, {
  required String title,
  String? hintText,
  String initialValue = '',
  required Function(String) onSave,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hintText),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}
