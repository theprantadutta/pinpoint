import 'package:shared_preferences/shared_preferences.dart';

import '../constants/shared_preference_keys.dart';

/// What the app owes a user on launch, onboarding-wise.
enum OnboardingAction {
  /// Never finished onboarding: show the full flow.
  fullOnboarding,

  /// Finished an older onboarding: show the one-time "What's new" sheet.
  whatsNew,

  /// Up to date.
  none,
}

/// Versioned onboarding.
///
/// New installs see the full onboarding once, which records [current].
/// Installs that completed an earlier onboarding (the legacy
/// [kHasCompletedOnboardingKey] bool, with no or an older
/// [kOnboardingVersionKey]) get a single "What's new" sheet instead; showing
/// it records [current] too. Bump [current] when the onboarding or the
/// What's-new content changes enough to be worth showing again.
class OnboardingVersion {
  OnboardingVersion._();

  /// See [kCurrentOnboardingVersion].
  static const int current = kCurrentOnboardingVersion;

  /// Pure decision, so it can be unit-tested without preferences.
  static OnboardingAction decide({
    required bool hasCompletedOnboarding,
    required int? seenVersion,
  }) {
    if (!hasCompletedOnboarding) return OnboardingAction.fullOnboarding;
    if ((seenVersion ?? 1) < current) return OnboardingAction.whatsNew;
    return OnboardingAction.none;
  }

  static OnboardingAction read(SharedPreferences prefs) => decide(
        hasCompletedOnboarding:
            prefs.getBool(kHasCompletedOnboardingKey) ?? false,
        seenVersion: prefs.getInt(kOnboardingVersionKey),
      );

  /// Records that this install has seen the current onboarding generation
  /// (either the full flow or the What's-new sheet).
  static Future<void> markSeen(SharedPreferences prefs) =>
      prefs.setInt(kOnboardingVersionKey, current);
}
