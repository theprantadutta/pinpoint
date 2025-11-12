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
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
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

      // Check if local database is empty (fresh install or cleared data)
      try {
        final notes = await DriftNoteService.watchNotesWithDetails().first;
        debugPrint('🔵 [Splash] Found ${notes.length} local notes');

        if (notes.isEmpty) {
          // No local notes - attempt to restore from cloud
          debugPrint('🔄 [Splash] No local notes found, attempting cloud sync...');

          if (!mounted) return;

          // Show loading with message
          setState(() {}); // Trigger rebuild to show "Restoring..." text

          final syncManager = getIt<SyncManager>();
          // Use bidirectional sync to both upload and download
          final result = await syncManager.sync();

          if (result.success && result.notesSynced > 0) {
            debugPrint('✅ [Splash] Synced ${result.notesSynced} notes from cloud');
          } else {
            debugPrint('ℹ️ [Splash] No notes to sync from cloud');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [Splash] Error checking/restoring notes: $e');
        // Continue to home even if sync fails
      }

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

                // Loading indicator - Centered
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

                const SizedBox(height: 24),

                // Loading text - Centered
                Center(
                  child: Text(
                    'Loading...',
                    style: theme.textTheme.bodySmall?.copyWith(
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
