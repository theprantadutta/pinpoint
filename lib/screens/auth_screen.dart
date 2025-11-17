import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinpoint/services/google_sign_in_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/firebase_notification_service.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:pinpoint/screens/home_screen.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:pinpoint/sync/api_sync_service.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:pinpoint/design_system/colors.dart';
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
  bool _isEmailLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final GoogleSignInService _googleSignInService = GoogleSignInService();

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

      SyncResult? result;

      // Show loading dialog with animated progress
      if (mounted) {
        // Use a completer to track sync completion
        result = await showDialog<SyncResult>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            // Start the sync and update progress
            Future.delayed(Duration.zero, () async {
              try {
                final syncResult = await syncManager.sync();
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

            return const _SyncProgressDialog();
          },
        );
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
            ),
            const SizedBox(width: 8),
            Text(hasErrors ? 'Sync Completed with Errors' : 'Sync Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.notesSynced > 0) ...[
              _buildSyncStat('Notes', result.notesSynced, Icons.note),
            ],
            if (result.foldersSynced > 0) ...[
              const SizedBox(height: 8),
              _buildSyncStat('Folders', result.foldersSynced, Icons.folder),
            ],
            if (result.remindersSynced > 0) ...[
              const SizedBox(height: 8),
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
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isError ? Colors.red : Colors.blue,
        ),
        const SizedBox(width: 8),
        Text('$label: '),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isError ? Colors.red : Colors.green,
          ),
        ),
      ],
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

      // 3. Authenticate with backend using Firebase token
      debugPrint('🔵 [Google Sign-In] Step 3: Authenticating with backend...');
      try {
        await backendAuthService.authenticateWithGoogle(firebaseToken);
        debugPrint(
            '✅ [Google Sign-In] Step 3 Complete: Backend authentication successful');

        // 4. Register FCM token with backend now that user is authenticated
        debugPrint('🔵 [Google Sign-In] Step 4: Registering FCM token...');
        try {
          final firebaseNotifications = FirebaseNotificationService();
          await firebaseNotifications.registerTokenWithBackend();
          debugPrint(
              '✅ [Google Sign-In] Step 4 Complete: FCM token registered');
        } catch (e) {
          debugPrint(
              '⚠️ [Google Sign-In] Failed to register FCM token (non-critical): $e');
        }

        // 5. Force sync encryption key from cloud
        debugPrint(
            '🔵 [Google Sign-In] Step 5: Syncing encryption key from cloud...');
        try {
          final apiService = ApiService();
          final syncSuccess =
              await SecureEncryptionService.syncKeyFromCloud(apiService);

          if (syncSuccess) {
            debugPrint(
                '✅ [Google Sign-In] Step 5 Complete: Encryption key synced from cloud');
          } else {
            debugPrint(
                '⚠️ [Google Sign-In] Cloud key sync returned false, initializing encryption locally...');
            // Fallback: Initialize encryption locally
            // This ensures encryption is initialized even if cloud sync fails
            if (!SecureEncryptionService.isInitialized) {
              await SecureEncryptionService.initialize(apiService: apiService);
              debugPrint(
                  '✅ [Google Sign-In] Encryption initialized locally as fallback');
            }
          }
        } catch (e) {
          debugPrint(
              '❌ [Google Sign-In] Encryption key sync failed with exception: $e');
          // Critical fallback: Initialize encryption locally
          if (!SecureEncryptionService.isInitialized) {
            debugPrint(
                '🔑 [Google Sign-In] Initializing encryption locally after failure...');
            await SecureEncryptionService.initialize(apiService: ApiService());
            debugPrint('✅ [Google Sign-In] Encryption initialized locally');
          }
        }

        // 6. Perform initial sync to restore cloud data
        debugPrint('🔵 [Google Sign-In] Step 6: Syncing cloud data...');
        await _performInitialSync();
        debugPrint('✅ [Google Sign-In] Step 6 Complete: Sync finished');

        // Success! Navigate to home
        debugPrint(
            '🎉 [Google Sign-In] Authentication flow complete! Navigating to home...');
        if (mounted) {
          context.go(HomeScreen.kRouteName);
        }
      } on AccountLinkingRequiredException catch (e) {
        debugPrint('⚠️ [Google Sign-In] Account linking required');
        debugPrint('   - Message: ${e.message}');
        // Account linking required - navigate to account linking screen
        if (mounted) {
          context.push('/account-linking', extra: firebaseToken);
        }
      }
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
                      onPressed: (_isGoogleLoading || _isEmailLoading) ? null : _handleEmailPasswordAuth,
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
        onPressed: (_isGoogleLoading || _isEmailLoading) ? null : _handleGoogleSignIn,
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
}

/// Animated sync progress dialog
class _SyncProgressDialog extends StatefulWidget {
  const _SyncProgressDialog();

  @override
  State<_SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends State<_SyncProgressDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  String _statusMessage = 'Preparing to sync...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    // Animate status messages
    _animateStatusMessages();
  }

  void _animateStatusMessages() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _statusMessage = 'Downloading your notes...');
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _statusMessage = 'Decrypting data...');
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() => _statusMessage = 'Almost done...');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    return Dialog(
      backgroundColor: brightness == Brightness.dark
          ? PinpointColors.darkSurface1
          : PinpointColors.lightSurface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Icon(
              Icons.cloud_download_outlined,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Restoring Your Notes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Animated Progress Bar
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(_progressAnimation.value * 100).toInt()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Status message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _statusMessage,
                key: ValueKey(_statusMessage),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
