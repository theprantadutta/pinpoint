import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clears what a previous install left in the iOS keychain.
///
/// Deleting an iOS app removes its preferences and its database file, but not
/// its keychain items. A reinstall therefore starts with an empty notebook,
/// shows onboarding and offers "Continue without an account" — while the old
/// install's sign-in tokens are still sitting in the keychain. On the next
/// launch the app found them and quietly signed in, so notes written as a
/// guest went into the previous account and synced, against the promise that
/// they stay on this phone until the user signs in.
///
/// Preferences are the tell: an install that has ever run has some, a fresh
/// container has none. So when the marker is missing and preferences are
/// empty, this is a reinstall and the keychain is wiped before anything reads
/// it. An app updated from an earlier version has preferences, so it only
/// gets the marker and keeps everything.
///
/// Firebase Auth keeps its signed-in user in the keychain too, under its own
/// service, so [signOutLeftoverFirebaseUser] ends that session once Firebase
/// is up — otherwise the home screen still greets the previous account.
///
/// iOS only. Android removes the keystore-backed storage with the app.
abstract final class ReinstallGuard {
  static const String markerKey = 'install_marker_v1';

  /// Whether this launch cleared a previous install's keychain.
  static bool get clearedThisLaunch => _clearedThisLaunch;
  static bool _clearedThisLaunch = false;

  /// Must run before anything reads or writes preferences or secure storage.
  /// Never throws: a failure here must not stop the app from starting.
  static Future<void> run({
    @visibleForTesting bool? isIOS,
    @visibleForTesting FlutterSecureStorage? storage,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(markerKey) == true) return;

      final freshContainer = preferences.getKeys().isEmpty;
      if (freshContainer && (isIOS ?? Platform.isIOS)) {
        await (storage ?? const FlutterSecureStorage()).deleteAll();
        _clearedThisLaunch = true;
        debugPrint('🧹 [ReinstallGuard] Cleared keychain left by a previous install');
      }

      await preferences.setBool(markerKey, true);
    } catch (e) {
      debugPrint('⚠️ [ReinstallGuard] Skipped: $e');
    }
  }

  /// Signs out a Firebase user restored from a previous install's keychain.
  /// Call once Firebase is initialised. Never throws.
  static Future<void> signOutLeftoverFirebaseUser() async {
    if (!_clearedThisLaunch) return;
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
        debugPrint('🧹 [ReinstallGuard] Signed out a Firebase user left by a previous install');
      }
    } catch (e) {
      debugPrint('⚠️ [ReinstallGuard] Firebase sign-out skipped: $e');
    }
  }
}
