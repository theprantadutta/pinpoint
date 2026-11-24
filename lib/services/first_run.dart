import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/shared_preference_keys.dart';
import 'analytics/analytics_client.dart';
import 'analytics/analytics_facade.dart';
import 'encryption_service.dart';
import 'guest_mode.dart';

/// The steps between installing Pinpoint and writing the first note.
///
/// Every screen before the first note loses people (in Nov 2026, 19% left at
/// a terms checkbox screen alone), so a new person goes from the one
/// onboarding page straight into a blank note: tapping either onboarding
/// button, under "By continuing you agree to the Terms and Privacy Policy",
/// is the agreement, and "Get started" starts guest mode.
class FirstRun {
  FirstRun._();

  /// `first_run_flow` user property for people who went through this flow,
  /// so they can be compared with installs from before it.
  static const String flowWriteFirst = 'write_first';

  /// `onboarding_choice` values.
  static const String choiceGetStarted = 'get_started';
  static const String choiceLogIn = 'log_in';

  /// `guest_started` sources.
  static const String guestFromOnboarding = 'onboarding';
  static const String guestFromAuthScreen = 'auth_screen';

  /// Whether the splash must send this install to the onboarding page:
  /// it has never finished it, or finished it before agreeing to the terms
  /// (the old checkbox screen came after it). The onboarding page now carries
  /// the consent line, so it covers both.
  static bool needsOnboarding(SharedPreferences prefs) =>
      !(prefs.getBool(kHasCompletedOnboardingKey) ?? false) ||
      !(prefs.getBool(kHasAcceptedTermsKey) ?? false);

  /// Records that this install agreed to the Terms and Privacy Policy, under
  /// the same keys and analytics event the checkbox screen used, so the
  /// funnel stays comparable.
  static Future<void> acceptTerms(
    SharedPreferences prefs,
    AnalyticsFacade analytics,
  ) async {
    await prefs.setBool(kHasAcceptedTermsKey, true);
    await prefs.setString(
        kTermsAcceptedDateKey, DateTime.now().toIso8601String());
    analytics.trackTermsAccepted(method: 'inline');
  }

  /// Starts using the app without an account (see [GuestMode]).
  ///
  /// The splash initialises encryption for signed-out people before they
  /// reach the sign-in screen, but a brand-new install goes to the onboarding
  /// page before that point, so this makes sure the local data key exists
  /// (without an API service no key is ever uploaded). A failure here is not
  /// fatal: notes live in the database under its own at-rest key, and the
  /// splash retries on the next start.
  ///
  /// [source] is [guestFromOnboarding] or [guestFromAuthScreen].
  static Future<void> startAsGuest(
    AnalyticsFacade analytics, {
    required String source,
  }) async {
    if (!SecureEncryptionService.isInitialized) {
      try {
        await SecureEncryptionService.initialize();
      } catch (e) {
        debugPrint('⚠️ [FirstRun] Encryption init failed: $e');
      }
    }
    await GuestMode.start();
    analytics.trackGuestStarted(source: source);
  }
}

/// Reports `guest_converted` when someone who was using the app as a guest
/// signs in or signs up on the sign-in screen.
///
/// Created when the screen opens, because a successful sign-in ends guest
/// mode ([GuestMode] listens for it) and the fact would be gone by the time
/// it is reported. Reports at most once, however many attempts it takes.
class GuestConversion {
  GuestConversion({required this.wasGuest, required String entry})
      : entry = AuthEntry.parse(entry);

  /// Reads whether this person is a guest right now.
  factory GuestConversion.now({required String entry}) =>
      GuestConversion(wasGuest: GuestMode.isGuest, entry: entry);

  final bool wasGuest;

  /// One of [AuthEntry]'s values.
  final String entry;

  bool _reported = false;

  /// Call once the account is signed in. [method] is `google`, `apple` or
  /// `email`.
  void signedIn(AnalyticsFacade analytics, {required String method}) {
    if (!wasGuest || _reported) return;
    _reported = true;
    analytics.trackGuestConverted(method: method, entry: entry);
  }
}
