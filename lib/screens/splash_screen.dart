import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/shared_preference_keys.dart';
import '../design_system/design_system.dart';
import '../services/backend_auth_service.dart';
import '../services/encryption_service.dart';
import '../services/zero_knowledge_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'unlock_screen.dart';
import 'onboarding_screen.dart';
import 'terms_acceptance_screen.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String kRouteName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Nothing holds the user here: the splash leaves the moment startup work
  /// is done. Only if that work runs past this does a caption appear.
  static const Duration _lateCaptionAfter = Duration(milliseconds: 1500);

  Timer? _lateTimer;
  bool _late = false;

  @override
  void initState() {
    super.initState();
    _lateTimer = Timer(_lateCaptionAfter, () {
      if (mounted) setState(() => _late = true);
    });
    _checkAndNavigate();
  }

  @override
  void dispose() {
    _lateTimer?.cancel();
    super.dispose();
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
      debugPrint(
          '🔵 [Splash] Navigating to onboarding (${stopwatch.elapsedMilliseconds}ms)');
      context.go(OnboardingScreen.kRouteName);
      return;
    }

    // Check if user has accepted terms
    final hasAcceptedTerms = preferences.getBool(kHasAcceptedTermsKey) ?? false;

    if (!mounted) return;

    // Navigate to terms acceptance if not accepted
    if (!hasAcceptedTerms) {
      debugPrint(
          '🔵 [Splash] Navigating to terms (${stopwatch.elapsedMilliseconds}ms)');
      context.go(TermsAcceptanceScreen.kRouteName);
      return;
    }

    // Get auth service (already initialized by provider with caching)
    final backendAuth = context.read<BackendAuthService>();

    // Wait for auth initialization to complete (uses cached data, very fast)
    debugPrint('🔵 [Splash] Waiting for auth initialization...');
    await backendAuth.initialize();
    debugPrint('✅ [Splash] Auth ready (${stopwatch.elapsedMilliseconds}ms)');

    if (!mounted) return;

    // Navigate based on authentication status
    if (backendAuth.isAuthenticated) {
      debugPrint('✅ [Splash] User authenticated, setting up encryption...');

      // Zero-knowledge accounts: NEVER generate a key here (that would diverge
      // from the real, wrapped key). Only load an existing local key, then gate
      // on unlock. Standard accounts keep the original fast local-init path.
      final isZk = await ZeroKnowledgeService.isZeroKnowledge();
      if (isZk) {
        try {
          if (await SecureEncryptionService.hasLocalKey() &&
              !SecureEncryptionService.isInitialized) {
            await SecureEncryptionService.initialize();
          }
        } catch (e) {
          debugPrint('⚠️ [Splash] ZK local key load failed: $e');
        }
        if (!mounted) return;
        final mustUnlock = await ZeroKnowledgeService.needsUnlock();
        if (!mounted) return;
        if (mustUnlock) {
          context.go(UnlockScreen.kRouteName);
          return;
        }
        context.go(HomeScreen.kRouteName);
        return;
      }

      // Initialize encryption with LOCAL key only (fast, no network)
      // Cloud sync will happen in background on home screen
      try {
        if (!SecureEncryptionService.isInitialized) {
          await SecureEncryptionService.initialize();
          debugPrint(
              '✅ [Splash] Encryption initialized (${stopwatch.elapsedMilliseconds}ms)');
        }
      } catch (e) {
        debugPrint('⚠️ [Splash] Encryption init failed: $e');
        // Continue anyway - will retry on home screen
      }

      if (!mounted) return;

      // Navigate to home immediately - sync happens in background there
      debugPrint(
          '🚀 [Splash] Navigating to home (${stopwatch.elapsedMilliseconds}ms total)');
      context.go(HomeScreen.kRouteName);
    } else {
      debugPrint(
          '⚠️ [Splash] Not authenticated, navigating to auth (${stopwatch.elapsedMilliseconds}ms)');

      // Initialize encryption without cloud sync (will be synced after login)
      if (!SecureEncryptionService.isInitialized) {
        await SecureEncryptionService.initialize();
      }

      if (!mounted) return;
      context.go(AuthScreen.kRouteName);
    }
  }

  @override
  Widget build(BuildContext context) => SplashView(showLateCaption: _late);
}

/// The Flutter splash, shown while the database opens, keys unwrap and auth
/// resolves: the brand sticker drops in with a spring (scale 0.8 → 1,
/// rotation 0 → −7°) while the doodle swooshes draw on behind it (900ms).
///
/// Purely presentational, so the static frame can be golden-tested.
class SplashView extends StatefulWidget {
  const SplashView({super.key, this.showLateCaption = false});

  /// Show "Unlocking your notes…" — startup is taking longer than usual.
  final bool showLateCaption;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drop = AnimationController.unbounded(
    vsync: this,
  );

  /// Underdamped, so the sticker overshoots a touch and settles (~0.5s).
  static const SpringDescription _spring =
      SpringDescription(mass: 1, stiffness: 260, damping: 18);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (SketchMotion.enabled(context)) {
      _drop.animateWith(SpringSimulation(_spring, 0, 1, 0));
    } else {
      _drop.value = 1;
    }
  }

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    // The 200px doodle band sits just behind the sticker.
    final doodleTop = MediaQuery.sizeOf(context).height / 2 - 190;

    return Scaffold(
      backgroundColor: s.bg,
      body: DoodleBackground(
        top: doodleTop,
        squiggle: true,
        animate: true,
        child: SafeArea(
          child: SizedBox.expand(
            child: Column(
              children: [
                const Spacer(flex: 5),
                AnimatedBuilder(
                  animation: _drop,
                  builder: (context, child) {
                    final v = _drop.value;
                    return Transform.rotate(
                      angle: -7 * v * math.pi / 180,
                      child:
                          Transform.scale(scale: 0.8 + 0.2 * v, child: child),
                    );
                  },
                  // The rotation is animated above, so the sticker itself
                  // starts upright.
                  child: const ExcludeSemantics(
                    child: BrandSticker(size: 112, angle: 0, shadow: true),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Pinpoint', style: t.screenTitle),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SketchSpace.screenX),
                  child: Text(
                    l10n.obSplashTagline,
                    textAlign: TextAlign.center,
                    style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
                  ),
                ),
                const Spacer(flex: 4),
                SizedBox(
                  height: 48,
                  child: AnimatedOpacity(
                    opacity: widget.showLateCaption ? 1 : 0,
                    duration: SketchMotion.of(context, SketchMotion.base),
                    child: widget.showLateCaption
                        ? Semantics(
                            liveRegion: true,
                            child: Text(
                              l10n.obSplashUnlocking,
                              textAlign: TextAlign.center,
                              style: t.caption,
                            ),
                          )
                        : const SizedBox.shrink(),
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
