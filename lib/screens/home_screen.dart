import 'package:flutter/material.dart';

import '../components/home_screen/home_screen_my_folders.dart';
import '../components/home_screen/home_screen_recent_notes.dart';
import '../components/home_screen/home_screen_top_bar.dart';

class HomeScreen extends StatefulWidget {
  static const String kRouteName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      // Full-bleed background, no outer white gutters
      color: theme.scaffoldBackgroundColor,
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 12), // consistent inner gutter
        child: Column(
          children: [
            HomeScreenTopBar(
              onSearchChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 10),
            const HomeScreenMyFolders(),
            const SizedBox(height: 10),
            HomeScreenRecentNotes(searchQuery: _searchQuery),
          ],
        ),
      ),
    );
  }
}
