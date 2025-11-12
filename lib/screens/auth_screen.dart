import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinpoint/services/google_sign_in_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/firebase_notification_service.dart';
import 'package:pinpoint/screens/home_screen.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/encryption_service.dart';
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
  bool _isLoading = false;
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

      final syncManager = getIt<SyncManager>();

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Restoring your notes...'),
              ],
            ),
          ),
        );
      }

      // Perform bidirectional sync to both upload and download
      final result = await syncManager.sync();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        debugPrint('✅ [Auth] Initial sync successful: ${result.message}');
        debugPrint('   - Notes synced count: ${result.notesSynced}');
        if (result.notesSynced > 0) {
          debugPrint('   - ✅ Restored ${result.notesSynced} notes from cloud');
        } else {
          debugPrint('   - ⚠️ No notes were synced (cloud might be empty or decryption failed)');
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
                'Unable to restore your notes from cloud:\n${result.message}\n\n'
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
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
      debugPrint('   - Token preview: ${firebaseToken.substring(0, firebaseToken.length > 100 ? 100 : firebaseToken.length)}...');

      // 3. Authenticate with backend using Firebase token
      debugPrint('🔵 [Google Sign-In] Step 3: Authenticating with backend...');
      try {
        await backendAuthService.authenticateWithGoogle(firebaseToken);
        debugPrint('✅ [Google Sign-In] Step 3 Complete: Backend authentication successful');

        // 4. Register FCM token with backend now that user is authenticated
        debugPrint('🔵 [Google Sign-In] Step 4: Registering FCM token...');
        try {
          final firebaseNotifications = FirebaseNotificationService();
          await firebaseNotifications.registerTokenWithBackend();
          debugPrint('✅ [Google Sign-In] Step 4 Complete: FCM token registered');
        } catch (e) {
          debugPrint('⚠️ [Google Sign-In] Failed to register FCM token (non-critical): $e');
        }

        // 5. Force sync encryption key from cloud
        debugPrint('🔵 [Google Sign-In] Step 5: Syncing encryption key from cloud...');
        try {
          final apiService = ApiService();
          final syncSuccess = await SecureEncryptionService.syncKeyFromCloud(apiService);

          if (syncSuccess) {
            debugPrint('✅ [Google Sign-In] Step 5 Complete: Encryption key synced from cloud');
          } else {
            debugPrint('⚠️ [Google Sign-In] Cloud key sync returned false, initializing encryption locally...');
            // Fallback: Initialize encryption locally
            // This ensures encryption is initialized even if cloud sync fails
            if (!SecureEncryptionService.isInitialized) {
              await SecureEncryptionService.initialize(apiService: apiService);
              debugPrint('✅ [Google Sign-In] Encryption initialized locally as fallback');
            }
          }
        } catch (e) {
          debugPrint('❌ [Google Sign-In] Encryption key sync failed with exception: $e');
          // Critical fallback: Initialize encryption locally
          if (!SecureEncryptionService.isInitialized) {
            debugPrint('🔑 [Google Sign-In] Initializing encryption locally after failure...');
            await SecureEncryptionService.initialize(apiService: ApiService());
            debugPrint('✅ [Google Sign-In] Encryption initialized locally');
          }
        }

        // 6. Perform initial sync to restore cloud data
        debugPrint('🔵 [Google Sign-In] Step 6: Syncing cloud data...');
        await _performInitialSync();
        debugPrint('✅ [Google Sign-In] Step 6 Complete: Sync finished');

        // Success! Navigate to home
        debugPrint('🎉 [Google Sign-In] Authentication flow complete! Navigating to home...');
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
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleEmailPasswordAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
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
        final syncSuccess = await SecureEncryptionService.syncKeyFromCloud(apiService);

        if (syncSuccess) {
          debugPrint('✅ [Email Auth] Encryption key synced from cloud');
        } else {
          debugPrint('⚠️ [Email Auth] Cloud key sync returned false, initializing encryption locally...');
          // Fallback: Initialize encryption locally
          // This ensures encryption is initialized even if cloud sync fails
          if (!SecureEncryptionService.isInitialized) {
            await SecureEncryptionService.initialize(apiService: apiService);
            debugPrint('✅ [Email Auth] Encryption initialized locally as fallback');
          }
        }
      } catch (e) {
        debugPrint('❌ [Email Auth] Encryption key sync failed with exception: $e');
        // Critical fallback: Initialize encryption locally
        if (!SecureEncryptionService.isInitialized) {
          debugPrint('🔑 [Email Auth] Initializing encryption locally after failure...');
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
          _isLoading = false;
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
                      onPressed: _isLoading ? null : _handleEmailPasswordAuth,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
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
                    onPressed: _isLoading
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
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: _isLoading
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
