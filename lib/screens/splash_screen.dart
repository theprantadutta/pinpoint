import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../services/backend_auth_service.dart';
import '../services/encryption_service.dart';
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

  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  void _updateStatus(String message) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
    });
  }

  Future<void> _checkAndNavigate() async {
    if (!mounted) return;

    debugPrint('🚀 [Splash] Starting fast navigation...');
    final stopwatch = Stopwatch()..start();

    // Check if user has completed onboarding
    final preferences = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        preferences.getBool(kHasCompletedOnboardingKey) ?? false;

    if (!mounted) return;

    // Navigate to onboarding if not completed
    if (!hasCompletedOnboarding) {
      debugPrint('🔵 [Splash] Navigating to onboarding (${stopwatch.elapsedMilliseconds}ms)');
      context.go(OnboardingScreen.kRouteName);
      return;
    }

    // Check if user has accepted terms
    final hasAcceptedTerms = preferences.getBool(kHasAcceptedTermsKey) ?? false;

    if (!mounted) return;

    // Navigate to terms acceptance if not accepted
    if (!hasAcceptedTerms) {
      debugPrint('🔵 [Splash] Navigating to terms (${stopwatch.elapsedMilliseconds}ms)');
      context.go(TermsAcceptanceScreen.kRouteName);
      return;
    }

    // Get auth service (already initialized by provider with caching)
    _updateStatus('Checking authentication...');
    final backendAuth = context.read<BackendAuthService>();

    // Wait for auth initialization to complete (uses cached data, very fast)
    debugPrint('🔵 [Splash] Waiting for auth initialization...');
    await backendAuth.initialize();
    debugPrint('✅ [Splash] Auth ready (${stopwatch.elapsedMilliseconds}ms)');

    if (!mounted) return;

    // Navigate based on authentication status
    if (backendAuth.isAuthenticated) {
      debugPrint('✅ [Splash] User authenticated, setting up encryption...');
      _updateStatus('Setting up...');

      // Initialize encryption with LOCAL key only (fast, no network)
      // Cloud sync will happen in background on home screen
      try {
        if (!SecureEncryptionService.isInitialized) {
          await SecureEncryptionService.initialize();
          debugPrint('✅ [Splash] Encryption initialized (${stopwatch.elapsedMilliseconds}ms)');
        }
      } catch (e) {
        debugPrint('⚠️ [Splash] Encryption init failed: $e');
        // Continue anyway - will retry on home screen
      }

      if (!mounted) return;

      // Navigate to home immediately - sync happens in background there
      debugPrint('🚀 [Splash] Navigating to home (${stopwatch.elapsedMilliseconds}ms total)');
      context.go(HomeScreen.kRouteName);
    } else {
      debugPrint('⚠️ [Splash] Not authenticated, navigating to auth (${stopwatch.elapsedMilliseconds}ms)');

      // Initialize encryption without cloud sync (will be synced after login)
      if (!SecureEncryptionService.isInitialized) {
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
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo with enhanced shadow
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

                // Simple loading indicator
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer.withValues(alpha: 0.3),
                        colorScheme.secondaryContainer.withValues(alpha: 0.2),
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

                // Status message
                Text(
                  _statusMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
