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
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/components/auth/provider_logos.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/util/api_error_messages.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/util/sync_phase_labels.dart';

/// Authentication screen with Google Sign-In and email/password options
/// Minimum password length enforced at registration. Named rather than inline
/// so the validator and the message the user reads can never drift apart.
const int kMinPasswordLength = 6;

class AuthScreen extends StatefulWidget {
  static const String kRouteName = '/auth';

  /// The query that opens this screen in sign-up mode (see
  /// [TermsAcceptanceScreen.signUpLocation]).
  static const String signUpLocation = '$kRouteName?mode=signup';

  const AuthScreen({super.key, this.startInSignUp = false});

  /// Open with the email form in sign-up mode — the onboarding's
  /// "Get started" path. Social sign-in is the same either way.
  final bool startInSignUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _isLogin = !widget.startInSignUp;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isEmailLoading = false;
  String? _errorMessage;

  /// Where [_errorMessage] is shown: under the email button when the email
  /// form raised it, otherwise under the provider buttons.
  bool _errorFromEmail = false;

  /// Doodle band offset: the swooshes run behind the brand sticker.
  static const double _doodleTop = 20;

  /// Whether any auth flow is currently in progress (used to disable buttons).
  bool get _isBusy => _isGoogleLoading || _isAppleLoading || _isEmailLoading;

  /// Turn a thrown error into text for the inline error banner.
  ///
  /// A coded [ApiError] is rendered from the user's own locale via its error
  /// code; everything else falls back to the exception text, minus Dart's
  /// "Exception: " prefix.
  String _describeError(Object e) {
    if (e is ApiError) return localizedApiError(context, e);
    return e.toString().replaceAll('Exception: ', '');
  }

  /// Shorthand for the localized strings. Safe in the async sync/auth helpers
  /// below as well as in build, since they all run against the State's context.
  AppL10n get _l10n => AppL10n.of(context);

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
        debugPrint(
            '📴 [Auth] Offline — skipping initial sync; will sync on reconnect');
        return true;
      }

      SyncResult? result;

      // Show a loading dialog driven by REAL, live sync progress.
      if (mounted) {
        final progressNotifier = ValueNotifier<SyncProgress>(
          SyncProgress(
            phase: SyncPhase.preparingFolders,
            message: _l10n.authConnectingToCloud,
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
                        message: _l10n.authSyncTakingAWhile,
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
      result ??= SyncResult(success: false, message: _l10n.authSyncCancelled);

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
          final hasErrors =
              result.notesFailed > 0 || result.decryptionErrors > 0;

          if (hasData || hasErrors) {
            await _showSyncResultDialog(result);
          }
        }

        return true;
      } else {
        debugPrint('⚠️ [Auth] Initial sync failed: ${result.message}');

        // Show error dialog with retry option
        if (mounted) {
          // true = Retry, false = Continue anyway, null = dismissed
          // (which, as before, continues).
          final retry = await _askRetry(
            _l10n.authSyncFailedTitle,
            _l10n.authSyncFailedBody(
              result.message.isEmpty ? _l10n.authUnknownError : result.message,
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
        // Dismissing retries, as before: only "Continue anyway" continues.
        final retry = await _askRetry(
          _l10n.authSyncErrorTitle,
          _l10n.authSyncErrorBody(e.toString()),
        );

        if (retry != false) {
          return await _performInitialSync(); // Retry
        }
      }

      return false; // Continue without sync
    }
  }

  /// The Retry / Continue-anyway choice after a failed initial sync, as a
  /// Sketchbook sheet. Returns true for Retry, false for Continue anyway and
  /// null when dismissed.
  Future<bool?> _askRetry(String title, String body) {
    return showSketchSheet<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.type;
        return SketchSheet(
          titleWidget: Semantics(
            header: true,
            child: Text(title, style: t.emptyTitle),
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillButton.secondary(
                label: _l10n.authContinueAnyway,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              const SizedBox(height: 10),
              PillButton(
                label: _l10n.commonRetry,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
          child: Text(
            body,
            style: t.bodyRegular
                .copyWith(fontSize: 14, height: 1.5, color: ctx.sketch.muted),
          ),
        );
      },
    );
  }

  /// Show sync result dialog with detailed information
  Future<void> _showSyncResultDialog(SyncResult result) async {
    final hasErrors = result.notesFailed > 0 || result.decryptionErrors > 0;

    await showSketchSheet<void>(
      context: context,
      builder: (ctx) {
        final t = ctx.type;
        final rows = <Widget>[
          if (result.notesSynced > 0)
            _buildSyncStat(
                _l10n.authStatNotes, result.notesSynced, Icons.notes_rounded),
          if (result.foldersSynced > 0)
            _buildSyncStat(_l10n.authStatFolders, result.foldersSynced,
                Icons.folder_outlined),
          if (result.remindersSynced > 0)
            _buildSyncStat(_l10n.authStatReminders, result.remindersSynced,
                Icons.alarm_rounded),
          if (result.notesFailed > 0)
            _buildSyncStat(
              _l10n.authStatFailedToRestore,
              result.notesFailed,
              Icons.error_outline_rounded,
              isError: true,
            ),
        ];

        return SketchSheet(
          titleWidget: Row(
            children: [
              StickerTile(
                color: hasErrors ? SketchPastels.yellow : SketchPastels.mint,
                size: 44,
                angle: -6,
                icon: hasErrors
                    ? Icons.priority_high_rounded
                    : Icons.check_rounded,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    hasErrors
                        ? _l10n.authSyncCompletedWithErrors
                        : _l10n.authSyncSuccessful,
                    style: t.emptyTitle,
                  ),
                ),
              ),
            ],
          ),
          footer: PillButton(
            label: _l10n.commonOk,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isNotEmpty)
                SketchGroup(margin: EdgeInsets.zero, children: rows),
              if (result.decryptionErrors > 0) ...[
                const SizedBox(height: 14),
                Text(
                  _l10n.authDecryptionErrors,
                  style: t.chip.copyWith(
                      fontWeight: FontWeight.w700,
                      color: SketchFunctional.error),
                ),
                const SizedBox(height: 6),
                SketchErrorPill(
                  message:
                      _l10n.auDecryptionErrorsBody(result.decryptionErrors),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// One row of the restore summary: icon, label and the count.
  Widget _buildSyncStat(String label, int count, IconData icon,
      {bool isError = false}) {
    return SketchRow(
      icon: icon,
      label: label,
      labelColor: isError ? SketchFunctional.error : null,
      trailing: Text(
        '$count',
        style: context.type.body.copyWith(
          fontWeight: FontWeight.w800,
          color: isError ? SketchFunctional.error : context.sketch.ink,
        ),
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
        throw Exception(_l10n.authGoogleSignInCancelled);
      }

      debugPrint('✅ [Google Sign-In] Step 1 Complete: User signed in');
      debugPrint('   - User ID: ${userCredential.user?.uid}');
      debugPrint('   - Email: ${userCredential.user?.email}');

      // 2. Get Firebase ID token
      debugPrint('🔵 [Google Sign-In] Step 2: Getting Firebase ID token...');
      final firebaseToken = await _googleSignInService.getFirebaseIdToken();

      if (firebaseToken == null) {
        debugPrint('❌ [Google Sign-In] Firebase token is null');
        throw Exception(_l10n.authFirebaseTokenFailed);
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
          _errorMessage = _describeError(e);
          _errorFromEmail = false;
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
          debugPrint(
              '🔑 [$tag] Initializing encryption locally after failure...');
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
      debugPrint(
          '🎉 [$tag] Authentication flow complete! Navigating to home...');
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
        throw Exception(_l10n.authAppleSignInCancelled);
      }
      debugPrint(
          '✅ [Apple Sign-In] Firebase user: ${userCredential.user?.uid}');

      // 2. Get Firebase ID token.
      final firebaseToken = await _appleSignInService.getFirebaseIdToken();
      if (firebaseToken == null) {
        throw Exception(_l10n.authFirebaseTokenFailed);
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
          _errorMessage = _describeError(e);
          _errorFromEmail = false;
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
        _errorMessage = _describeError(e);
        _errorFromEmail = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final muted =
        t.bodyRegular.copyWith(fontSize: 14, height: 1.5, color: s.muted);
    final socialError = _errorMessage != null && !_errorFromEmail;
    final emailError = _errorMessage != null && _errorFromEmail;

    return Scaffold(
      backgroundColor: s.bg,
      body: DoodleBackground(
        top: _doodleTop,
        squiggle: true,
        child: SafeArea(
          child: ResponsiveCenter(
            maxWidth: Breakpoints.formMaxWidth,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  SketchSpace.screenX, 28, SketchSpace.screenX, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthHero(),
                  const SizedBox(height: 26),
                  Semantics(
                    header: true,
                    child: HighlightedText(_l10n.auReadyTitle,
                        style: t.screenTitle),
                  ),
                  const SizedBox(height: 10),
                  Text(_l10n.auReadyBody, style: muted),
                  const SizedBox(height: 26),

                  // Google Sign-In Button (Primary)
                  PillButton.secondary(
                    label: _l10n.authContinueWithGoogle,
                    leading: const GoogleLogo(),
                    loading: _isGoogleLoading,
                    onPressed: _isBusy && !_isGoogleLoading
                        ? null
                        : _handleGoogleSignIn,
                  ),

                  // Sign in with Apple (iOS only — App Store Guideline 4.8).
                  // An outlined button with the Apple logo and an approved
                  // title, which the HIG permits for a custom button.
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    PillButton.secondary(
                      label: _l10n.authContinueWithApple,
                      leading: Icon(Icons.apple, size: 24, color: s.ink),
                      loading: _isAppleLoading,
                      onPressed: _isBusy && !_isAppleLoading
                          ? null
                          : _handleAppleSignIn,
                    ),
                  ],

                  if (socialError) ...[
                    const SizedBox(height: 14),
                    SketchErrorPill(message: _errorMessage!),
                  ],

                  const SizedBox(height: 26),
                  _OrDivider(label: _l10n.authEmailDivider),
                  const SizedBox(height: 18),

                  Semantics(
                    header: true,
                    child: Text(
                      _isLogin
                          ? _l10n.authWelcomeBack
                          : _l10n.authCreateAccount,
                      style: t.sectionTitle,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Email/Password Form
                  AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SketchTextField(
                            controller: _emailController,
                            hint: _l10n.authEmailLabel,
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _l10n.authEmailRequired;
                              }
                              if (!value.contains('@')) {
                                return _l10n.authEmailInvalid;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          SketchTextField(
                            controller: _passwordController,
                            hint: _l10n.authPasswordLabel,
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            revealLabel: _l10n.auShowPassword,
                            concealLabel: _l10n.auHidePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: [
                              _isLogin
                                  ? AutofillHints.password
                                  : AutofillHints.newPassword,
                            ],
                            onSubmitted: (_) {
                              if (!_isBusy) _handleEmailPasswordAuth();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return _l10n.authPasswordRequired;
                              }
                              if (!_isLogin &&
                                  value.length < kMinPasswordLength) {
                                return _l10n
                                    .authPasswordTooShort(kMinPasswordLength);
                              }
                              return null;
                            },
                          ),
                          if (emailError) ...[
                            const SizedBox(height: 14),
                            SketchErrorPill(message: _errorMessage!),
                          ],
                          const SizedBox(height: 18),

                          // Login/Register Button
                          PillButton(
                            label:
                                _isLogin ? _l10n.authLogIn : _l10n.authSignUp,
                            loading: _isEmailLoading,
                            onPressed: _isBusy && !_isEmailLoading
                                ? null
                                : _handleEmailPasswordAuth,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Toggle Login/Register
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? _l10n.authNoAccountPrompt
                            : _l10n.authHaveAccountPrompt,
                        style: muted,
                      ),
                      SketchTextAction(
                        label: _isLogin ? _l10n.authSignUp : _l10n.authLogIn,
                        style: t.chip.copyWith(fontSize: 14),
                        onTap: (_isGoogleLoading || _isEmailLoading)
                            ? null
                            : _toggleMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The brand sticker with two small companions — the same hero as the
/// onboarding's "Get started" step.
class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: 190,
          height: 118,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                start: 6,
                top: 14,
                child: BrandSticker(size: 92, shadow: true),
              ),
              PositionedDirectional(
                start: 120,
                top: 0,
                child: StickerTile(
                    color: SketchPastels.mint,
                    size: 42,
                    angle: 12,
                    icon: Icons.check_rounded),
              ),
              PositionedDirectional(
                start: 116,
                top: 70,
                child: StickerTile(
                    color: SketchPastels.lavender,
                    size: 36,
                    angle: -10,
                    icon: Icons.star_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "—— or continue with email ——" with hairline rules.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    Widget rule() => Expanded(
          child: Container(height: SketchStroke.outline, color: s.hairline),
        );
    return Row(
      children: [
        rule(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: context.type.caption),
        ),
        rule(),
      ],
    );
  }
}

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
        return Icons.check_rounded;
    }
  }

  Color _heroColor(BuildContext context, int step) {
    switch (step) {
      case 0:
        return context.sketch.highlight;
      case 1:
        return SketchPastels.lavender;
      case 2:
        return SketchPastels.sky;
      default:
        return SketchPastels.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    // Shape, surface and outline come from the Sketchbook dialog theme.
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: ValueListenableBuilder<SyncProgress>(
          valueListenable: progress,
          builder: (context, p, _) {
            final step = _stepOf(p.phase);
            final isError = p.phase == SyncPhase.error;
            final fraction = (p.overallProgress ??
                    (p.totalItems > 0 ? p.currentItem / p.totalItems : 0.0))
                .clamp(0.0, 1.0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StickerTile(
                  color:
                      isError ? SketchPastels.pink : _heroColor(context, step),
                  size: 64,
                  angle: -6,
                  icon: isError ? Icons.priority_high_rounded : _heroIcon(step),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.authRestoringNotes,
                  textAlign: TextAlign.center,
                  style: t.emptyTitle,
                ),
                const SizedBox(height: 6),
                // Live status message (+ per-item counter when available)
                AnimatedSwitcher(
                  duration: SketchMotion.of(
                      context, const Duration(milliseconds: 250)),
                  child: Text(
                    // Rendered from the phase rather than the service's own
                    // message: the sync layer has no BuildContext and cannot
                    // localize its status text.
                    syncPhaseLabel(context, p),
                    key: ValueKey(
                        '${p.message}-${p.currentItem}-${p.totalItems}'),
                    textAlign: TextAlign.center,
                    style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
                  ),
                ),
                const SizedBox(height: 20),
                // Real, smoothly-animated progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: fraction),
                  duration: SketchMotion.of(
                      context, const Duration(milliseconds: 300)),
                  curve: SketchMotion.enter,
                  builder: (context, value, _) => UsageBar(
                    fraction: value,
                    height: 10,
                    fill: isError ? SketchFunctional.error : s.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${(fraction * 100).round()}%',
                  style: t.cardTitleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isError ? SketchFunctional.error : s.ink,
                  ),
                ),
                const SizedBox(height: 18),
                // Step checklist
                _StepRow(
                    label: l10n.authStatFolders,
                    icon: Icons.folder_outlined,
                    index: 0,
                    step: step),
                const SizedBox(height: 10),
                _StepRow(
                    label: l10n.authStatNotes,
                    icon: Icons.notes_rounded,
                    index: 1,
                    step: step),
                const SizedBox(height: 10),
                _StepRow(
                    label: l10n.authStatReminders,
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

/// A single line in the restore step checklist: done (mint check), active
/// (spinner) or pending (hairline ring).
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
    final s = context.sketch;
    final t = context.type;
    final done = step > index;
    final active = step == index;
    final lit = done || active;

    Widget leading;
    if (done) {
      leading = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: SketchPastels.mint,
          shape: BoxShape.circle,
          border: Border.all(
              color: SketchPastels.onPastel, width: SketchStroke.pastel),
        ),
        child: const Icon(Icons.check_rounded,
            size: 14, color: SketchPastels.onPastel),
      );
    } else if (active) {
      leading = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: s.ink),
      );
    } else {
      leading = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: s.hairline, width: SketchStroke.outline),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(width: 24, child: Center(child: leading)),
        const SizedBox(width: 12),
        Icon(icon, size: 18, color: lit ? s.ink : s.muted),
        const SizedBox(width: 8),
        Text(
          label,
          style: t.body.copyWith(
            color: lit ? s.ink : s.muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
