import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
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
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    // Check if user has completed onboarding
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool(kHasCompletedOnboardingKey) ?? false;

    if (!mounted) return;

    // Navigate based on onboarding status only (no authentication required)
    if (!hasCompletedOnboarding) {
      context.go(OnboardingScreen.kRouteName);
    } else {
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

              const SizedBox(height: 80),

              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 400.ms)
                  .scale(curve: Curves.easeOut),
            ],
          ),
        ),
      ),
    );
  }
}
