import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
import '../services/backend_auth_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

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
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Wait for splash animation to complete
    // await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    // Check if user has completed onboarding
    final preferences = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        preferences.getBool(kHasCompletedOnboardingKey) ?? false;

    if (!mounted) return;

    // Navigate to onboarding if not completed
    if (!hasCompletedOnboarding) {
      context.go(OnboardingScreen.kRouteName);
      return;
    }

    // Check authentication status
    final backendAuth = context.read<BackendAuthService>();
    final hasSeenAuthPrompt = preferences.getBool(kHasSeenAuthPromptKey) ?? false;

    // If user completed onboarding but hasn't signed in and hasn't seen the prompt
    if (!backendAuth.isAuthenticated && !hasSeenAuthPrompt) {
      if (!mounted) return;

      // Show authentication prompt
      await _showAuthPrompt(preferences);
    } else {
      // Navigate to home screen
      if (!mounted) return;
      context.go(HomeScreen.kRouteName);
    }
  }

  Future<void> _showAuthPrompt(SharedPreferences preferences) async {
    // Mark that user has seen the prompt
    await preferences.setBool(kHasSeenAuthPromptKey, true);

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to Pinpoint!'),
        content: const Text(
          'Sign in to sync your notes across devices and keep them safe in the cloud.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip for now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == true) {
      // Navigate to auth screen
      context.go(AuthScreen.kRouteName);
    } else {
      // Navigate to home screen
      context.go(HomeScreen.kRouteName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? PinpointGradients.crescentInk
              : PinpointGradients.oceanQuartz,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with animated entrance
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(80),
                  child: Image.asset(
                    'assets/images/pinpoint-logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  .animate()
                  .scale(
                    duration: 800.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              // App name
              Text(
                'Pinpoint',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: isDark
                          ? PinpointColors.darkTextPrimary
                          : PinpointColors.lightTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 48,
                    ),
              )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 8),

              // Tagline
              Text(
                'Your thoughts, perfectly organized',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? PinpointColors.darkTextSecondary
                          : PinpointColors.lightTextSecondary,
                      fontSize: 16,
                    ),
              )
                  .animate(delay: 400.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
            ],
          ),
        ),
      ),
    );
  }
}
