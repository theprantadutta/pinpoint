import 'package:flutter/material.dart';

class DialogService {
  DialogService._();

  static void addSomethingDialog({
    required BuildContext context,
    required TextEditingController controller,
    required String title,
    required String hintText,
    required void Function() onAddPressed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
              Text(title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hintText),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: onAddPressed,
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }
}
