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
      debugPrint(
          '🔵 [Splash] User has not completed onboarding, navigating to onboarding screen');
      context.go(OnboardingScreen.kRouteName);
      return;
    }

    // Check if user has accepted terms
    final hasAcceptedTerms = preferences.getBool(kHasAcceptedTermsKey) ?? false;

    if (!mounted) return;

    // Navigate to terms acceptance if not accepted
    if (!hasAcceptedTerms) {
      debugPrint(
          '🔵 [Splash] User has not accepted terms, navigating to terms screen');
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
    debugPrint(
        '🔵 [Splash] Authentication status: ${backendAuth.isAuthenticated}');
    if (backendAuth.isAuthenticated) {
      debugPrint('✅ [Splash] User is authenticated');

      // Initialize encryption service with cloud sync (CRITICAL: Do this BEFORE any sync)
      _updateStatus('Setting up encryption...');
      debugPrint(
          '🔑 [Splash] Initializing encryption service with cloud sync...');
      bool encryptionKeySuccess = false;
      try {
        final apiService = ApiService();

        // Always sync key from cloud to ensure we have the correct key
        debugPrint('🔑 [Splash] Fetching encryption key from cloud...');
        encryptionKeySuccess = await SecureEncryptionService.syncKeyFromCloud(apiService);

        if (encryptionKeySuccess) {
          debugPrint('✅ [Splash] Encryption key synced successfully from cloud');
        } else {
          debugPrint('⚠️ [Splash] Failed to sync encryption key from cloud');
          // Try to initialize with local key or generate new one
          if (!SecureEncryptionService.isInitialized) {
            debugPrint('🔑 [Splash] Falling back to local-only encryption');
            await SecureEncryptionService.initialize();
          }
        }
      } catch (e) {
        debugPrint('❌ [Splash] Error during encryption initialization: $e');
        // Try to initialize without cloud sync as fallback
        if (!SecureEncryptionService.isInitialized) {
          debugPrint(
              '🔑 [Splash] Falling back to local-only encryption initialization');
          await SecureEncryptionService.initialize();
        }
      }

      // Initialize sync manager with authenticated API service
      _updateStatus('Initializing sync...');
      debugPrint(
          '🔄 [Splash] Initializing Sync Manager with authenticated API service...');
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

        debugPrint(
            '🔵 [Splash] Found ${notes.length} local notes ($unsyncedCount unsynced, $deletedCount deleted)');

        if (notes.isEmpty || unsyncedCount > 0) {
          // No local notes OR unsynced notes - attempt sync
          debugPrint(
              '🔄 [Splash] Syncing ${notes.isEmpty ? "from" : "with"} cloud ($unsyncedCount unsynced)...');

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
              _updateStatus('Restored ${result.notesSynced} notes',
                  progress: 1.0);
              debugPrint(
                  '✅ [Splash] Synced ${result.notesSynced} notes from cloud');
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
      debugPrint(
          '⚠️ [Splash] User is not authenticated, navigating to auth screen');

      // Initialize encryption without cloud sync (will be synced after login)
      if (!SecureEncryptionService.isInitialized) {
        debugPrint(
            '🔑 [Splash] Initializing encryption for unauthenticated user');
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo with enhanced shadow and animation
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.1),
                            colorScheme.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/images/pinpoint-logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // App Name
                Center(
                  child: Text(
                    'PinPoint',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Your thoughts, perfectly organized',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 2),

                // Enhanced Loading/Sync indicator
                if (_syncProgress != null) ...[
                  // Syncing card with progress
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.5),
                          colorScheme.secondaryContainer.withValues(alpha: isDark ? 0.2 : 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Sync icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.sync_rounded,
                            size: 32,
                            color: colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Status message
                        Text(
                          _statusMessage,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        // Progress bar with gradient
                        Stack(
                          children: [
                            // Background
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              ),
                            ),
                            // Progress
                            FractionallySizedBox(
                              widthFactor: _syncProgress,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Percentage with better styling
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(_syncProgress! * 100).toInt()}%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Enhanced circular indicator for general loading
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.4),
                          colorScheme.secondaryContainer.withValues(alpha: isDark ? 0.2 : 0.3),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status message for non-sync loading
                  Text(
                    _statusMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
