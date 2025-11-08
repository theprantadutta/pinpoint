import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: GlassAppBar(
        scrollController: _scrollController,
        title: HomeScreenTopBar(
          onSearchChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
        ),
      ),
      body: Column(
        children: [
          // Folders Section (Compact)
          const HomeScreenMyFolders(),

          SizedBox(height: PinpointSpacing.lg),

          // Recent Notes Section
          Expanded(
            child: HomeScreenRecentNotes(
              searchQuery: _searchQuery,
              scrollController: _scrollController,
            ),
          ),
        ],
      ),
    );
  }
}
