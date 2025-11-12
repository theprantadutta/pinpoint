import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../database/database.dart';
import '../services/backend_auth_service.dart';
import '../services/drift_note_service.dart';
import '../services/encryption_service.dart';
import '../services/api_service.dart';
import '../sync/sync_manager.dart';
import '../sync/api_sync_service.dart';
import '../service_locators/init_service_locators.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'terms_acceptance_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String kRouteName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Loading...';
  double? _syncProgress; // null = indeterminate, 0-1 = progress

  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  void _updateStatus(String message, {double? progress}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _syncProgress = progress;
    });
  }

  Future<void> _checkAndNavigate() async {
    if (!mounted) return;

    debugPrint('🔵 [Splash] Starting splash screen navigation...');

    // Check if user has completed onboarding
    final preferences = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        preferences.getBool(kHasCompletedOnboardingKey) ?? false;

    if (!mounted) return;

    // Navigate to onboarding if not completed
    if (!hasCompletedOnboarding) {
      debugPrint('🔵 [Splash] User has not completed onboarding, navigating to onboarding screen');
      context.go(OnboardingScreen.kRouteName);
      return;
    }

    // Check if user has accepted terms
    final hasAcceptedTerms =
        preferences.getBool(kHasAcceptedTermsKey) ?? false;

    if (!mounted) return;

    // Navigate to terms acceptance if not accepted
    if (!hasAcceptedTerms) {
      debugPrint('🔵 [Splash] User has not accepted terms, navigating to terms screen');
      context.go(TermsAcceptanceScreen.kRouteName);
      return;
    }

    // Check authentication status
    _updateStatus('Checking authentication...');
    debugPrint('🔵 [Splash] Checking authentication status...');
    final backendAuth = context.read<BackendAuthService>();

    // Initialize authentication (verify token and fetch user info)
    try {
      debugPrint('🔵 [Splash] Initializing BackendAuthService...');
      await backendAuth.initialize();
      debugPrint('✅ [Splash] BackendAuthService initialized');
    } catch (e) {
      debugPrint('⚠️ [Splash] Failed to initialize auth: $e');
    }

    if (!mounted) return;

    // Navigate based on authentication status
    debugPrint('🔵 [Splash] Authentication status: ${backendAuth.isAuthenticated}');
    if (backendAuth.isAuthenticated) {
      debugPrint('✅ [Splash] User is authenticated');

      // Initialize encryption service with cloud sync (CRITICAL: Do this BEFORE any sync)
      _updateStatus('Setting up encryption...');
      debugPrint('🔑 [Splash] Initializing encryption service with cloud sync...');
      try {
        final apiService = ApiService();

        // First check if encryption is already initialized
        if (!SecureEncryptionService.isInitialized) {
          debugPrint('🔑 [Splash] Encryption not initialized, fetching from cloud...');
          await SecureEncryptionService.syncKeyFromCloud(apiService);
          debugPrint('✅ [Splash] Encryption initialized with cloud key');
        } else {
          debugPrint('⚠️ [Splash] Encryption already initialized, syncing from cloud anyway...');
          await SecureEncryptionService.syncKeyFromCloud(apiService);
        }
      } catch (e) {
        debugPrint('❌ [Splash] Failed to initialize encryption: $e');
        // Try to initialize without cloud sync as fallback
        if (!SecureEncryptionService.isInitialized) {
          debugPrint('🔑 [Splash] Falling back to local-only encryption initialization');
          await SecureEncryptionService.initialize();
        }
      }

      // Initialize sync manager with authenticated API service
      _updateStatus('Initializing sync...');
      debugPrint('🔄 [Splash] Initializing Sync Manager with authenticated API service...');
      try {
        final syncManager = getIt<SyncManager>();
        final database = getIt<AppDatabase>();
        final apiSyncService = ApiSyncService(
          apiService: ApiService(),
          database: database,
        );
        syncManager.setSyncService(apiSyncService);
        await syncManager.init(syncService: apiSyncService);
        debugPrint('✅ [Splash] Sync Manager initialized');
      } catch (e) {
        debugPrint('⚠️ [Splash] Failed to initialize sync manager: $e');
      }

      // Check if local database is empty OR has unsynced notes
      try {
        final notes = await DriftNoteService.watchNotesWithDetails().first;
        final database = getIt<AppDatabase>();

        // Count unsynced notes (including deleted ones that need to be synced)
        final unsyncedNotes = await (database.select(database.notes)
              ..where((tbl) => tbl.isSynced.equals(false)))
            .get();
        final unsyncedCount = unsyncedNotes.length;
        final deletedCount = unsyncedNotes.where((n) => n.isDeleted).length;

        debugPrint('🔵 [Splash] Found ${notes.length} local notes ($unsyncedCount unsynced, $deletedCount deleted)');

        if (notes.isEmpty || unsyncedCount > 0) {
          // No local notes OR unsynced notes - attempt sync
          debugPrint('🔄 [Splash] Syncing ${notes.isEmpty ? "from" : "with"} cloud ($unsyncedCount unsynced)...');

          if (!mounted) return;

          // Show sync progress UI
          final syncManager = getIt<SyncManager>();

          // Simulate progress for better UX (since we don't have real-time progress from API)
          if (notes.isEmpty) {
            // Restoring notes
            _updateStatus('Restoring your notes...', progress: 0.0);
            await Future.delayed(const Duration(milliseconds: 100));

            _updateStatus('Downloading from cloud...', progress: 0.3);
            final result = await syncManager.sync();

            _updateStatus('Almost done...', progress: 0.9);
            await Future.delayed(const Duration(milliseconds: 200));

            if (result.success && result.notesSynced > 0) {
              _updateStatus('Restored ${result.notesSynced} notes', progress: 1.0);
              debugPrint('✅ [Splash] Synced ${result.notesSynced} notes from cloud');
              await Future.delayed(const Duration(milliseconds: 500));
            } else {
              debugPrint('ℹ️ [Splash] No notes to sync from cloud');
            }
          } else {
            // Syncing changes
            _updateStatus('Syncing your changes...', progress: 0.0);
            await Future.delayed(const Duration(milliseconds: 100));

            _updateStatus('Uploading $unsyncedCount notes...', progress: 0.5);
            final result = await syncManager.sync();

            if (result.success) {
              _updateStatus('Sync complete', progress: 1.0);
              debugPrint('✅ [Splash] Sync completed');
              await Future.delayed(const Duration(milliseconds: 300));
            }
          }

          // Reset progress indicator
          if (mounted) {
            setState(() {
              _syncProgress = null;
              _statusMessage = 'Loading...';
            });
          }
        }
      } catch (e) {
        debugPrint('⚠️ [Splash] Error checking/restoring notes: $e');
        // Continue to home even if sync fails
      }

      if (!mounted) return;

      _updateStatus('Opening app...');
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      debugPrint('✅ [Splash] Navigating to home');
      context.go(HomeScreen.kRouteName);
    } else {
      debugPrint('⚠️ [Splash] User is not authenticated, navigating to auth screen');

      // Initialize encryption without cloud sync (will be synced after login)
      if (!SecureEncryptionService.isInitialized) {
        debugPrint('🔑 [Splash] Initializing encryption for unauthenticated user');
        await SecureEncryptionService.initialize();
      }

      if (!mounted) return;
      context.go(AuthScreen.kRouteName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity, // Force full width
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo - Centered
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/pinpoint-logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // App Name - Centered
                Center(
                  child: Text(
                    'PinPoint',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 12),

                // Tagline - Centered with full width
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Your thoughts, perfectly organized',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 3),

                // Loading/Sync indicator
                if (_syncProgress != null) ...[
                  // Progress bar for sync
                  Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Column(
                      children: [
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _syncProgress,
                            minHeight: 8,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Percentage text
                        Text(
                          '${(_syncProgress! * 100).toInt()}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Circular indicator for general loading
                  Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Status message
                Center(
                  child: Text(
                    _statusMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
