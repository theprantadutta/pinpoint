import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../services/backend_auth_service.dart';
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
      debugPrint('✅ [Splash] User is authenticated, navigating to home');
      context.go(HomeScreen.kRouteName);
    } else {
      debugPrint('⚠️ [Splash] User is not authenticated, navigating to auth screen');
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
