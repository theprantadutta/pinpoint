import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinpoint/services/google_sign_in_service.dart';
import 'package:pinpoint/services/apple_sign_in_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/firebase_notification_service.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/services/connectivity_service.dart';
import 'package:pinpoint/screens/home_screen.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:pinpoint/sync/api_sync_service.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:pinpoint/services/zero_knowledge_service.dart';
import 'package:pinpoint/screens/unlock_screen.dart';
import 'package:pinpoint/design_system/colors.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:go_router/go_router.dart';

/// Authentication screen with Google Sign-In and email/password options
class AuthScreen extends StatefulWidget {
  static const String kRouteName = '/auth';

  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isEmailLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  /// Whether any auth flow is currently in progress (used to disable buttons).
  bool get _isBusy => _isGoogleLoading || _isAppleLoading || _isEmailLoading;

  final GoogleSignInService _googleSignInService = GoogleSignInService();
  final AppleSignInService _appleSignInService = AppleSignInService();

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Auth');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Performs initial sync after login to restore cloud data
  Future<bool> _performInitialSync() async {
    try {
      debugPrint('🔄 [Auth] Starting initial sync to restore data...');

      // CRITICAL: Initialize folders BEFORE sync to prevent data loss
      // Without this, notes restored from cloud won't have folder relationships
      // because the folder lookup will fail silently
      debugPrint('📁 [Auth] Initializing note folders before sync...');
      await DriftNoteFolderService.watchAllNoteFoldersStream().first;
      debugPrint('✅ [Auth] Note folders initialized');

      // Initialize sync manager with API sync service (now that we're authenticated)
      debugPrint(
          '🔄 [Auth] Initializing Sync Manager with authenticated API service...');
      final syncManager = getIt<SyncManager>();
      final database = getIt<AppDatabase>();

      final apiSyncService = ApiSyncService(
        apiService: ApiService(),
        database: database,
      );

      // Set the sync service (allows re-initialization on subsequent logins)
      syncManager.setSyncService(apiSyncService);
      await syncManager.init(syncService: apiSyncService);
      debugPrint(
          '✅ [Auth] Sync Manager initialized with authenticated API service');

      // Offline-first: if there's no network right now, skip the blocking
      // initial sync and go straight to home. SyncManager auto-syncs once
      // connectivity is restored, so no data is lost and the user is never
      // trapped on a spinner.
      if (ConnectivityService().isOffline) {
        debugPrint('📴 [Auth] Offline — skipping initial sync; will sync on reconnect');
        return true;
      }

      SyncResult? result;

      // Show a loading dialog driven by REAL, live sync progress.
      if (mounted) {
        final progressNotifier = ValueNotifier<SyncProgress>(
          const SyncProgress(
            phase: SyncPhase.preparingFolders,
            message: 'Connecting to the cloud…',
            overallProgress: 0.02,
          ),
        );
        // Forward live progress events from the sync service to the dialog.
        apiSyncService.onProgressUpdate = (p) => progressNotifier.value = p;

        result = await showDialog<SyncResult>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            // Start the sync; the dialog re-renders from progressNotifier.
            Future.delayed(Duration.zero, () async {
              try {
                // Never let a slow/dropped network trap the user on this
                // dialog — time out and proceed; the background sync (and
                // reconnect auto-sync) will finish the job.
                final syncResult = await syncManager.sync().timeout(
                  const Duration(seconds: 25),
                  onTimeout: () => SyncResult(
                    success: false,
                    message:
                        'Sync is taking a while — it will finish in the background.',
                  ),
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(syncResult);
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(SyncResult(
                    success: false,
                    message: e.toString(),
                  ));
                }
              }
            });

            return _SyncProgressDialog(progress: progressNotifier);
          },
        );

        apiSyncService.onProgressUpdate = null;
        progressNotifier.dispose();
      }

      // Use the result from the dialog
      result ??= SyncResult(success: false, message: 'Sync cancelled');

      if (result.success) {
        debugPrint('✅ [Auth] Initial sync successful: ${result.message}');
        debugPrint('   - Notes synced: ${result.notesSynced}');
        debugPrint('   - Folders synced: ${result.foldersSynced}');
        debugPrint('   - Reminders synced: ${result.remindersSynced}');
        if (result.notesFailed > 0) {
          debugPrint('   - ⚠️ Notes failed: ${result.notesFailed}');
        }
        if (result.decryptionErrors > 0) {
          debugPrint('   - ❌ Decryption errors: ${result.decryptionErrors}');
        }

        // Show sync result summary to user
        if (mounted) {
          final hasData = result.notesSynced > 0 ||
              result.foldersSynced > 0 ||
              result.remindersSynced > 0;
          final hasErrors = result.notesFailed > 0 || result.decryptionErrors > 0;

          if (hasData || hasErrors) {
            await _showSyncResultDialog(result);
          }
        }

        return true;
      } else {
        debugPrint('⚠️ [Auth] Initial sync failed: ${result.message}');

        // Show error dialog with retry option
        if (mounted) {
          final retry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sync Failed'),
              content: Text(
                'Unable to restore your notes from cloud:\n${result?.message ?? 'Unknown error'}\n\n'
                'You can continue without syncing, or try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Continue Anyway'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );

          if (retry == true) {
            return await _performInitialSync(); // Recursive retry
          }
        }

        return false; // User chose to continue without sync
      }
    } catch (e) {
      debugPrint('❌ [Auth] Initial sync error: $e');

      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Show error with option to continue
      if (mounted) {
        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Error'),
            content: Text(
              'Failed to restore your notes:\n${e.toString()}\n\n'
              'You can continue without syncing, or try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue Anyway'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Retry'),
              ),
            ],
          ),
        );

        if (continueAnyway != true) {
          return await _performInitialSync(); // Retry
        }
      }

      return false; // Continue without sync
    }
  }

  /// Show sync result dialog with detailed information
  Future<void> _showSyncResultDialog(SyncResult result) async {
    final hasErrors = result.notesFailed > 0 || result.decryptionErrors > 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasErrors ? Icons.warning_amber : Icons.check_circle,
              color: hasErrors ? Colors.orange : Colors.green,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasErrors ? 'Sync Completed with Errors' : 'Sync Successful',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.notesSynced > 0) ...[
                _buildSyncStat('Notes', result.notesSynced, Icons.note),
              ],
              if (result.foldersSynced > 0) ...[
                const SizedBox(height: 12),
                _buildSyncStat('Folders', result.foldersSynced, Icons.folder),
              ],
              if (result.remindersSynced > 0) ...[
                const SizedBox(height: 12),
                _buildSyncStat('Reminders', result.remindersSynced, Icons.alarm),
              ],
            if (result.notesFailed > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildSyncStat(
                'Failed to restore',
                result.notesFailed,
                Icons.error_outline,
                isError: true,
              ),
            ],
            if (result.decryptionErrors > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Decryption Errors',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.decryptionErrors} notes could not be decrypted. This usually means the encryption key is incorrect or corrupted.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                    ),
                  ],
                ),
              ),
            ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Helper widget to build sync stat row
  Widget _buildSyncStat(String label, int count, IconData icon,
      {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isError
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isError ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isError
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isError ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔵 [Google Sign-In] Starting Google Sign-In flow...');

      // Get BackendAuthService before any await
      final backendAuthService = context.read<BackendAuthService>();

      // 1. Sign in with Google and get Firebase credential
      debugPrint('🔵 [Google Sign-In] Step 1: Initiating Google Sign-In...');
      final userCredential = await _googleSignInService.signInWithGoogle();

      if (userCredential == null) {
        debugPrint('❌ [Google Sign-In] User credential is null');
        throw Exception('Google Sign-In was cancelled or failed');
      }

      debugPrint('✅ [Google Sign-In] Step 1 Complete: User signed in');
      debugPrint('   - User ID: ${userCredential.user?.uid}');
      debugPrint('   - Email: ${userCredential.user?.email}');

      // 2. Get Firebase ID token
      debugPrint('🔵 [Google Sign-In] Step 2: Getting Firebase ID token...');
      final firebaseToken = await _googleSignInService.getFirebaseIdToken();

      if (firebaseToken == null) {
        debugPrint('❌ [Google Sign-In] Firebase token is null');
        throw Exception('Failed to get Firebase token');
      }

      debugPrint('✅ [Google Sign-In] Step 2 Complete: Got Firebase token');
      debugPrint('   - Token length: ${firebaseToken.length}');
      debugPrint(
          '   - Token preview: ${firebaseToken.substring(0, firebaseToken.length > 100 ? 100 : firebaseToken.length)}...');

      // 3-6. Backend auth, FCM, encryption sync, initial sync, navigation.
      await _completeSocialSignIn(
        backendAuthService: backendAuthService,
        userCredential: userCredential,
        firebaseToken: firebaseToken,
        method: 'google',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [Google Sign-In] ERROR: $e');
      debugPrint('❌ [Google Sign-In] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  /// Shared completion for social sign-in (Google / Apple) once we hold a
  /// Firebase credential and a backend-ready Firebase ID token.
  ///
  /// Handles: backend authentication, FCM token registration, encryption-key
  /// sync (incl. zero-knowledge unlock routing), initial data sync, analytics,
  /// and navigation. On [AccountLinkingRequiredException] it routes to the
  /// account-linking screen. [method] is the analytics label ('google'/'apple').
  Future<void> _completeSocialSignIn({
    required BackendAuthService backendAuthService,
    required UserCredential userCredential,
    required String firebaseToken,
    required String method,
  }) async {
    final tag = method == 'apple' ? 'Apple Sign-In' : 'Google Sign-In';
    try {
      // Backend authentication (shared /auth/firebase verification).
      debugPrint('🔵 [$tag] Authenticating with backend...');
      if (method == 'apple') {
        await backendAuthService.authenticateWithApple(firebaseToken);
      } else {
        await backendAuthService.authenticateWithGoogle(firebaseToken);
      }
      debugPrint('✅ [$tag] Backend authentication successful');

      // Register FCM token now that the user is authenticated.
      debugPrint('🔵 [$tag] Registering FCM token...');
      try {
        final firebaseNotifications = FirebaseNotificationService();
        await firebaseNotifications.registerTokenWithBackend();
        debugPrint('✅ [$tag] FCM token registered');
      } catch (e) {
        debugPrint('⚠️ [$tag] Failed to register FCM token (non-critical): $e');
      }

      // Sync the encryption key from the cloud.
      debugPrint('🔵 [$tag] Syncing encryption key from cloud...');
      try {
        final apiService = ApiService();
        // Zero-knowledge accounts unlock with a passphrase — never sync or
        // generate a server-held key for them.
        final zkMode =
            await ZeroKnowledgeService.refreshModeFromServer(apiService);
        if (zkMode == ZeroKnowledgeService.modeZeroKnowledge) {
          if (await SecureEncryptionService.hasLocalKey() &&
              !SecureEncryptionService.isInitialized) {
            await SecureEncryptionService.initialize();
          }
          if (mounted) context.go(UnlockScreen.kRouteName);
          return;
        }
        final syncSuccess =
            await SecureEncryptionService.syncKeyFromCloud(apiService);

        if (syncSuccess) {
          debugPrint('✅ [$tag] Encryption key synced from cloud');
        } else {
          debugPrint(
              '⚠️ [$tag] Cloud key sync returned false, initializing encryption locally...');
          if (!SecureEncryptionService.isInitialized) {
            await SecureEncryptionService.initialize(apiService: apiService);
            debugPrint('✅ [$tag] Encryption initialized locally as fallback');
          }
        }
      } catch (e) {
        debugPrint('❌ [$tag] Encryption key sync failed with exception: $e');
        if (!SecureEncryptionService.isInitialized) {
          debugPrint('🔑 [$tag] Initializing encryption locally after failure...');
          await SecureEncryptionService.initialize(apiService: ApiService());
          debugPrint('✅ [$tag] Encryption initialized locally');
        }
      }

      // Perform initial sync to restore cloud data.
      debugPrint('🔵 [$tag] Syncing cloud data...');
      await _performInitialSync();
      debugPrint('✅ [$tag] Sync finished');

      // Track analytics.
      final analytics = getIt<AnalyticsFacade>();
      analytics.trackLogin(method: method);
      if (userCredential.user?.uid != null) {
        analytics.setUserId(userCredential.user!.uid);
      }

      // Success! Navigate to home.
      debugPrint('🎉 [$tag] Authentication flow complete! Navigating to home...');
      if (mounted) {
        context.go(HomeScreen.kRouteName);
      }
    } on AccountLinkingRequiredException catch (e) {
      debugPrint('⚠️ [$tag] Account linking required: ${e.message}');
      if (mounted) {
        context.push('/account-linking', extra: firebaseToken);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isAppleLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🍎 [Apple Sign-In] Starting Apple Sign-In flow...');

      // Capture provider before any await.
      final backendAuthService = context.read<BackendAuthService>();

      // 1. Sign in with Apple and get a Firebase credential.
      final userCredential = await _appleSignInService.signInWithApple();
      if (userCredential == null) {
        throw Exception('Sign in with Apple was cancelled or failed');
      }
      debugPrint('✅ [Apple Sign-In] Firebase user: ${userCredential.user?.uid}');

      // 2. Get Firebase ID token.
      final firebaseToken = await _appleSignInService.getFirebaseIdToken();
      if (firebaseToken == null) {
        throw Exception('Failed to get Firebase token');
      }

      // 3-6. Shared completion (backend, FCM, encryption, sync, navigation).
      await _completeSocialSignIn(
        backendAuthService: backendAuthService,
        userCredential: userCredential,
        firebaseToken: firebaseToken,
        method: 'apple',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [Apple Sign-In] ERROR: $e');
      debugPrint('❌ [Apple Sign-In] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  Future<void> _handleEmailPasswordAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isEmailLoading = true;
      _errorMessage = null;
    });

    try {
      final backendAuthService = context.read<BackendAuthService>();

      if (_isLogin) {
        await backendAuthService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await backendAuthService.register(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      // Register FCM token with backend now that user is authenticated
      try {
        final firebaseNotifications = FirebaseNotificationService();
        await firebaseNotifications.registerTokenWithBackend();
      } catch (e) {
        debugPrint('⚠️ Failed to register FCM token (non-critical): $e');
      }

      // Force sync encryption key from cloud
      debugPrint('🔵 [Email Auth] Syncing encryption key from cloud...');
      try {
        final apiService = ApiService();
        // Zero-knowledge accounts unlock with a passphrase — never sync or
        // generate a server-held key for them.
        final zkMode =
            await ZeroKnowledgeService.refreshModeFromServer(apiService);
        if (zkMode == ZeroKnowledgeService.modeZeroKnowledge) {
          if (await SecureEncryptionService.hasLocalKey() &&
              !SecureEncryptionService.isInitialized) {
            await SecureEncryptionService.initialize();
          }
          if (mounted) context.go(UnlockScreen.kRouteName);
          return;
        }
        final syncSuccess =
            await SecureEncryptionService.syncKeyFromCloud(apiService);

        if (syncSuccess) {
          debugPrint('✅ [Email Auth] Encryption key synced from cloud');
        } else {
          debugPrint(
              '⚠️ [Email Auth] Cloud key sync returned false, initializing encryption locally...');
          // Fallback: Initialize encryption locally
          // This ensures encryption is initialized even if cloud sync fails
          if (!SecureEncryptionService.isInitialized) {
            await SecureEncryptionService.initialize(apiService: apiService);
            debugPrint(
                '✅ [Email Auth] Encryption initialized locally as fallback');
          }
        }
      } catch (e) {
        debugPrint(
            '❌ [Email Auth] Encryption key sync failed with exception: $e');
        // Critical fallback: Initialize encryption locally
        if (!SecureEncryptionService.isInitialized) {
          debugPrint(
              '🔑 [Email Auth] Initializing encryption locally after failure...');
          await SecureEncryptionService.initialize(apiService: ApiService());
          debugPrint('✅ [Email Auth] Encryption initialized locally');
        }
      }

      // Perform initial sync to restore cloud data
      debugPrint('🔄 [Email Auth] Syncing cloud data...');
      await _performInitialSync();
      debugPrint('✅ [Email Auth] Sync finished');

      // Track analytics
      final analytics = getIt<AnalyticsFacade>();
      analytics.setUserId(backendAuthService.userId);
      if (_isLogin) {
        analytics.trackLogin(method: 'email');
      } else {
        analytics.trackSignUp(method: 'email');
      }

      // Success! Navigate to home
      if (mounted) {
        context.go(HomeScreen.kRouteName);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // App Logo/Icon
              Icon(
                Icons.push_pin,
                size: 80,
                color: cs.primary,
              ),

              const SizedBox(height: 16),

              // App Title
              Text(
                'PinPoint',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                _isLogin ? 'Welcome back!' : 'Create your account',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Google Sign-In Button (Primary)
              _buildGoogleSignInButton(theme, cs),

              // Sign in with Apple (iOS only — App Store Guideline 4.8)
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _buildAppleSignInButton(theme, cs),
              ],

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: cs.outlineVariant,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with email',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: cs.outlineVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Email/Password Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (!_isLogin && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: cs.onErrorContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Login/Register Button
                    FilledButton(
                      onPressed: _isBusy ? null : _handleEmailPasswordAuth,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isEmailLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isLogin ? 'Log In' : 'Sign Up',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Toggle Login/Register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? "Don't have an account? "
                        : 'Already have an account? ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: (_isGoogleLoading || _isEmailLoading)
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                            });
                          },
                    child: Text(
                      _isLogin ? 'Sign Up' : 'Log In',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(ThemeData theme, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FilledButton.tonalIcon(
        onPressed: _isBusy ? null : _handleGoogleSignIn,
        icon: _isGoogleLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Image.asset(
                'assets/images/google_logo.png',
                height: 24,
                width: 24,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to icon if image not found
                  return const Icon(Icons.g_mobiledata, size: 24);
                },
              ),
        label: Text(
          'Continue with Google',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: cs.outline,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// "Continue with Apple" button (iOS only).
  ///
  /// Custom-styled to match [_buildGoogleSignInButton] for a consistent look.
  /// App Store HIG permits a custom Sign in with Apple button as long as it uses
  /// the Apple logo, an approved title, and adequate size/contrast — this is the
  /// "white with outline" treatment (surface background + outline in light mode,
  /// adapting to the theme).
  Widget _buildAppleSignInButton(ThemeData theme, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FilledButton.tonalIcon(
        onPressed: _isBusy ? null : _handleAppleSignIn,
        icon: _isAppleLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.apple, size: 26, color: cs.onSurface),
        label: Text(
          'Continue with Apple',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: cs.outline,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated sync progress dialog
/// Restore dialog driven by REAL, live sync progress (folders → notes →
/// reminders), with a per-note counter and a step checklist.
class _SyncProgressDialog extends StatelessWidget {
  final ValueListenable<SyncProgress> progress;
  const _SyncProgressDialog({required this.progress});

  /// Map a fine-grained sync phase to one of three high-level steps.
  static int _stepOf(SyncPhase phase) {
    switch (phase) {
      case SyncPhase.idle:
      case SyncPhase.preparingFolders:
      case SyncPhase.syncingFolders:
        return 0; // Folders
      case SyncPhase.preparingNotes:
      case SyncPhase.uploadingNotes:
      case SyncPhase.downloadingNotes:
      case SyncPhase.processingNotes:
        return 1; // Notes
      case SyncPhase.syncingReminders:
        return 2; // Reminders
      case SyncPhase.finalizing:
      case SyncPhase.completed:
      case SyncPhase.error:
        return 3; // Done
    }
  }

  IconData _heroIcon(int step) {
    switch (step) {
      case 0:
        return Icons.folder_rounded;
      case 1:
        return Icons.lock_open_rounded; // decrypting notes
      case 2:
        return Icons.alarm_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;

    return Dialog(
      backgroundColor: brightness == Brightness.dark
          ? PinpointColors.darkSurface1
          : PinpointColors.lightSurface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ValueListenableBuilder<SyncProgress>(
          valueListenable: progress,
          builder: (context, p, _) {
            final step = _stepOf(p.phase);
            final isError = p.phase == SyncPhase.error;
            final fraction = (p.overallProgress ??
                    (p.totalItems > 0 ? p.currentItem / p.totalItems : 0.0))
                .clamp(0.0, 1.0);
            final accent = isError ? cs.error : cs.primary;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero phase icon in a soft circle
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    isError ? Icons.error_rounded : _heroIcon(step),
                    size: 32,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Restoring your notes',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                // Live status message (+ per-item counter when available)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    (p.totalItems > 1 && p.currentItem > 0)
                        ? '${p.message}  (${p.currentItem} of ${p.totalItems})'
                        : p.message,
                    key: ValueKey(
                        '${p.message}-${p.currentItem}-${p.totalItems}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 20),
                // Real, smoothly-animated progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: fraction),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${(fraction * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Step checklist
                _StepRow(
                    label: 'Folders',
                    icon: Icons.folder_rounded,
                    index: 0,
                    step: step),
                const SizedBox(height: 8),
                _StepRow(
                    label: 'Notes',
                    icon: Icons.notes_rounded,
                    index: 1,
                    step: step),
                const SizedBox(height: 8),
                _StepRow(
                    label: 'Reminders',
                    icon: Icons.alarm_rounded,
                    index: 2,
                    step: step),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A single line in the restore step checklist: done (check), active (spinner)
/// or pending (outline).
class _StepRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index;
  final int step;
  const _StepRow({
    required this.label,
    required this.icon,
    required this.index,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final done = step > index;
    final active = step == index;
    final muted = cs.onSurfaceVariant.withValues(alpha: 0.5);

    Widget leading;
    if (done) {
      leading = Icon(Icons.check_circle_rounded, size: 20, color: cs.primary);
    } else if (active) {
      leading = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
        ),
      );
    } else {
      leading = Icon(Icons.circle_outlined, size: 20, color: muted);
    }

    return Row(
      children: [
        SizedBox(width: 24, child: Center(child: leading)),
        const SizedBox(width: 12),
        Icon(icon, size: 18, color: (done || active) ? cs.primary : muted),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: (done || active) ? cs.onSurface : muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
