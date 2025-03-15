import 'package:flutter/material.dart';

import '../components/home_screen/home_screen_my_folders.dart';
import '../components/home_screen/home_screen_recent_notes.dart';
import '../components/home_screen/home_screen_top_bar.dart';

class HomeScreen extends StatelessWidget {
  static const String kRouteName = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        spacing: 10,
        children: [
          HomeScreenTopBar(),
          HomeScreenMyFolders(),
          HomeScreenRecentNotes(),
        ],
      ),
    );
  }
}
