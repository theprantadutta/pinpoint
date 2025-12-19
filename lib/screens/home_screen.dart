import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../design_system/design_system.dart';
import '../components/home_screen/home_screen_my_folders.dart';
import '../components/home_screen/home_screen_recent_notes.dart';
import '../components/home_screen/home_screen_top_bar.dart';
import '../service_locators/init_service_locators.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../services/premium_service.dart';
import '../services/firebase_notification_service.dart';
import '../services/reminder_sync_service.dart';
import '../sync/sync_manager.dart';
import '../sync/api_sync_service.dart';

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
    // Initialize authenticated services after user logs in
    _initializeAuthenticatedServices();
  }

  /// Initialize services that require authentication
  /// This includes notification permissions, subscriptions, premium features, and background sync
  /// All operations run in parallel for maximum speed
  Future<void> _initializeAuthenticatedServices() async {
    debugPrint('🚀 [HomeScreen] Starting background initialization...');

    // Run all background tasks in parallel for speed
    await Future.wait([
      // 1. Request notification permission (only once)
      _requestNotificationPermissionIfNeeded(),

      // 2. Initialize Subscription and Premium Services
      _initializeSubscriptionServices(),

      // 3. Sync encryption key from cloud (ensures we have correct key)
      _syncEncryptionKeyFromCloud(),

      // 4. Register FCM token with backend
      _registerFcmToken(),
    ]);

    // After initial services are ready, run data sync in background
    // This is a separate step because it depends on encryption being ready
    _runBackgroundDataSync();
  }

  /// Initialize Subscription and Premium services
  Future<void> _initializeSubscriptionServices() async {
    try {
      debugPrint('💎 [HomeScreen] Initializing Subscription Service...');
      await SubscriptionService.initialize();
      debugPrint('✅ [HomeScreen] Subscription Service initialized');
    } catch (e) {
      debugPrint('⚠️ [HomeScreen] Subscription Service not initialized: $e');
    }

    try {
      debugPrint('💎 [HomeScreen] Initializing PremiumService...');
      await PremiumService().initialize();
      debugPrint('✅ [HomeScreen] PremiumService initialized');
    } catch (e) {
      debugPrint('⚠️ [HomeScreen] PremiumService not initialized: $e');
    }
  }

  /// Sync encryption key from cloud to ensure we have the correct key
  Future<void> _syncEncryptionKeyFromCloud() async {
    try {
      debugPrint('🔑 [HomeScreen] Syncing encryption key from cloud...');
      final apiService = ApiService();
      final synced = await SecureEncryptionService.syncKeyFromCloud(apiService);
      if (synced) {
        debugPrint('✅ [HomeScreen] Encryption key synced from cloud');
      } else {
        debugPrint('ℹ️ [HomeScreen] No cloud key found, using local key');
      }
    } catch (e) {
      debugPrint('⚠️ [HomeScreen] Encryption key sync failed: $e');
      // Not critical - local key will be used
    }
  }

  /// Register FCM token with backend
  Future<void> _registerFcmToken() async {
    try {
      debugPrint('📱 [HomeScreen] Registering FCM token with backend...');
      final firebaseNotifications = FirebaseNotificationService();
      await firebaseNotifications.registerTokenWithBackend();
      debugPrint('✅ [HomeScreen] FCM token registered');
    } catch (e) {
      debugPrint('⚠️ [HomeScreen] FCM token registration failed: $e');
    }
  }

  /// Run background data sync (notes, folders, reminders)
  /// This initializes the sync service IMMEDIATELY (not in microtask) so it's ready
  /// when the user navigates to Settings, then performs actual sync in background
  /// Only runs once per session to avoid repeated syncs on every navigation
  void _runBackgroundDataSync() {
    // Initialize sync service immediately so it's available for Settings
    _initializeSyncService();

    // Check if we've already completed initial sync this session
    final syncManager = getIt<SyncManager>();
    if (syncManager.hasCompletedInitialSync) {
      debugPrint(
          '⏭️ [HomeScreen] Initial sync already done this session, skipping');
      return;
    }

    // Then run actual sync in background
    Future.microtask(() async {
      try {
        debugPrint('🔄 [HomeScreen] Starting background data sync...');

        // Perform sync in background
        final result = await syncManager.sync();

        if (result.success) {
          debugPrint('✅ [HomeScreen] Background sync complete: ${result.message}');
          if (result.notesSynced > 0) {
            debugPrint('   📝 Notes synced: ${result.notesSynced}');
          }
          if (result.foldersSynced > 0) {
            debugPrint('   📁 Folders synced: ${result.foldersSynced}');
          }
        } else {
          debugPrint('⚠️ [HomeScreen] Background sync had issues: ${result.message}');
        }
      } catch (e) {
        debugPrint('⚠️ [HomeScreen] Background sync failed: $e');
        // Don't block app - sync failure is not critical
      }

      // Also sync reminders (only on initial sync)
      try {
        debugPrint('⏰ [HomeScreen] Syncing local reminders to backend...');
        final syncResult = await ReminderSyncService.syncAllReminders();
        final created = syncResult['created'] ?? 0;
        final failed = syncResult['failed'] ?? 0;

        if (created > 0) {
          debugPrint('✅ [HomeScreen] Synced $created reminders to backend');
        } else if (failed > 0) {
          debugPrint('⚠️ [HomeScreen] Failed to sync $failed reminders');
        } else {
          debugPrint('✅ [HomeScreen] No reminders to sync');
        }
      } catch (e) {
        debugPrint('⚠️ [HomeScreen] Reminder sync failed: $e');
      }
    });
  }

  /// Initialize the sync service so it's available for manual sync in Settings
  Future<void> _initializeSyncService() async {
    try {
      debugPrint('🔧 [HomeScreen] Initializing sync service...');

      final syncManager = getIt<SyncManager>();
      final apiService = ApiService();
      final database = getIt<AppDatabase>();

      final apiSyncService = ApiSyncService(
        apiService: apiService,
        database: database,
      );

      await syncManager.init(syncService: apiSyncService);
      debugPrint('✅ [HomeScreen] Sync service initialized');
    } catch (e) {
      debugPrint('⚠️ [HomeScreen] Failed to initialize sync service: $e');
    }
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
