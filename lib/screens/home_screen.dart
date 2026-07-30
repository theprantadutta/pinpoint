import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../design_system/design_system.dart';
import '../components/home_screen/home_screen_my_folders.dart';
import '../components/home_screen/home_screen_recent_notes.dart';
import '../models/note_with_details.dart';
import '../screen_arguments/create_note_screen_arguments.dart';
import '../screens/create_note_screen_v2.dart';
import '../components/home_screen/home_screen_top_bar.dart';
import '../design_system/components/keep_fab.dart';
import '../navigation/keep_drawer.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../services/premium_service.dart';
import '../services/firebase_notification_service.dart';
import '../services/reminder_sync_service.dart';
import '../services/app_review_service.dart';
import '../sync/sync_manager.dart';
import '../sync/api_sync_service.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  static const String kRouteName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  // Master–detail (expanded/tablet only): the note open in the detail pane.
  NoteWithDetails? _selectedNote;

  // Whether the notes list has scrolled under the top bar (drives the hairline).
  bool _scrolledUnder = false;

  // Static flag to prevent re-initialization across widget rebuilds
  static bool _servicesInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Home');
    // Initialize authenticated services only once per app session
    if (!_servicesInitialized) {
      _initializeAuthenticatedServices();
      _servicesInitialized = true;
    }
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

    // Maybe ask for an in-app review (self-gated: only after enough returning
    // launches and past the cooldown; the OS decides if the prompt shows).
    AppReviewService().maybeRequestReview();
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
          debugPrint(
              '✅ [HomeScreen] Background sync complete: ${result.message}');
          if (result.notesSynced > 0) {
            debugPrint('   📝 Notes synced: ${result.notesSynced}');
          }
          if (result.foldersSynced > 0) {
            debugPrint('   📁 Folders synced: ${result.foldersSynced}');
          }
        } else {
          debugPrint(
              '⚠️ [HomeScreen] Background sync had issues: ${result.message}');
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

  void _onScroll() {
    final scrolledUnder =
        _scrollController.hasClients && _scrollController.offset > 0;
    if (scrolledUnder != _scrolledUnder) {
      setState(() => _scrolledUnder = scrolledUnder);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
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
            title: Text(AppL10n.of(context).homeEnableNotifTitle),
            content: Text(
              AppL10n.of(context).homeEnableNotifBody,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppL10n.of(context).homeNotNow),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppL10n.of(context).homeEnable),
              ),
            ],
          ),
        );

        // Mark as asked regardless of user choice
        await prefs.setBool('notification_permission_requested', true);

        // Request permission if user agreed
        if (shouldRequest == true) {
          await NotificationService.requestBasicNotificationPermission();
          getIt<AnalyticsFacade>()
              .trackNotificationPermissionResult(granted: true);
        } else {
          getIt<AnalyticsFacade>()
              .trackNotificationPermissionResult(granted: false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    // Match the app-bar surface to the home canvas so it blends in.
    final barColor = theme.scaffoldBackgroundColor;

    final sizeClass = context.windowSizeClass;

    // Expanded (landscape tablets/iPads): the search bar + folders span the
    // FULL width across the top; only the note list is a narrow pane, with the
    // editor filling the rest (note list | editor). The navigation drawer is
    // reached via the hamburger (Apple Notes-style collapsed sidebar).
    if (sizeClass == WindowSizeClass.expanded) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: const KeepDrawer(),
        floatingActionButton: const KeepFab(),
        body: Column(
          children: [
            // Full-width header: search + folders.
            _buildTopBar(theme, barColor),
            const HomeScreenMyFolders(),
            SizedBox(height: PinpointSpacing.lg),

            // Below the header: narrow note list | editor pane.
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 380,
                    child: _buildNotesList(masterDetail: true),
                  ),
                  VerticalDivider(
                    width: 0.5,
                    thickness: 0.5,
                    color: theme.dividerColor,
                  ),
                  Expanded(child: _buildDetailPane(theme)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Medium (portrait tablets/iPads): pin the navigation drawer open beside
    // the content (there's no editor pane here, so it's just drawer + list).
    // Compact (phones): the classic modal drawer + hamburger.
    final isMedium = sizeClass == WindowSizeClass.medium;

    // Flat, Keep-style home: a solid app-bar surface (with breathing room
    // beneath the search field) over a flat canvas — no gradient/glass.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: isMedium ? null : const KeepDrawer(),
      floatingActionButton: const KeepFab(),
      body: isMedium
          ? Row(
              children: [
                const KeepDrawer(permanent: true),
                Expanded(child: _buildHomeBody(theme, barColor)),
              ],
            )
          : _buildHomeBody(theme, barColor),
    );
  }

  /// The editor pane for master–detail. Shows a placeholder until a note is
  /// selected, then the note editor embedded (no route push/pop).
  Widget _buildDetailPane(ThemeData theme) {
    final note = _selectedNote;
    if (note == null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 64,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: PinpointSpacing.md),
              Text(
                AppL10n.of(context).homeSelectNote,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: PinpointSpacing.xs),
              Text(
                'or tap + to create a new one',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CreateNoteScreenV2(
      // A new key per note forces a fresh editor State so initState re-reads
      // the newly selected note (args are only read once, in initState).
      key: ValueKey(note.note.id),
      embedded: true,
      onClose: () => setState(() => _selectedNote = null),
      arguments: CreateNoteScreenArguments(
        noticeType: note.note.noteType,
        existingNote: note,
      ),
    );
  }

  Widget _buildHomeBody(ThemeData theme, Color barColor,
      {bool masterDetail = false}) {
    return Column(
      children: [
        _buildTopBar(theme, barColor),

        // Folders Section (Compact)
        const HomeScreenMyFolders(),

        SizedBox(height: PinpointSpacing.lg),

        // Recent Notes Section
        Expanded(child: _buildNotesList(masterDetail: masterDetail)),
      ],
    );
  }

  /// Top bar surface (search + hamburger/filter) with a hairline once scrolled.
  Widget _buildTopBar(ThemeData theme, Color barColor) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          bottom: BorderSide(
            color: _scrolledUnder ? theme.dividerColor : Colors.transparent,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: PinpointSpacing.sm),
          child: HomeScreenTopBar(
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
          ),
        ),
      ),
    );
  }

  /// The scrollable notes list. In [masterDetail] mode, taps select into the
  /// detail pane instead of pushing the full-screen editor.
  Widget _buildNotesList({bool masterDetail = false}) {
    return HomeScreenRecentNotes(
      searchQuery: _searchQuery,
      scrollController: _scrollController,
      onNoteSelected:
          masterDetail ? (note) => setState(() => _selectedNote = note) : null,
      selectedNoteId: masterDetail ? _selectedNote?.note.id : null,
    );
  }
}
