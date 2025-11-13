import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design_system/design_system.dart';
import '../components/home_screen/home_screen_my_folders.dart';
import '../components/home_screen/home_screen_recent_notes.dart';
import '../components/home_screen/home_screen_top_bar.dart';
import '../services/notification_service.dart';

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
  void initState() {
    super.initState();
    // Request notification permission after user logs in
    _requestNotificationPermissionIfNeeded();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Request basic notification permission on first app launch after login
  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAskedBefore =
          prefs.getBool('notification_permission_requested') ?? false;

      if (!hasAskedBefore && mounted) {
        // Small delay to let the home screen render first
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Show explanation dialog
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Enable Notifications'),
            content: const Text(
              'Stay updated with your notes and reminders. '
              'We\'ll notify you when your reminders are due.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Enable'),
              ),
            ],
          ),
        );

        // Mark as asked regardless of user choice
        await prefs.setBool('notification_permission_requested', true);

        // Request permission if user agreed
        if (shouldRequest == true) {
          await NotificationService.requestBasicNotificationPermission();
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
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
