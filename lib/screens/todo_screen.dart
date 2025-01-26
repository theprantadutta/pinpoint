import 'package:flutter/material.dart';

class TodoScreen extends StatelessWidget {
  static const String kRouteName = '/todo';
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Todo Screen'),
    );
  }
}
