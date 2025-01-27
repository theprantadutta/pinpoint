import 'package:flutter/material.dart';

import '../../screens/account_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/notes_screen.dart';
import '../../screens/todo_screen.dart';

/// Top Level Pages
const List<Widget> kTopLevelPages = [
  HomeScreen(),
  NotesScreen(),
  TodoScreen(),
  AccountScreen(),
];
