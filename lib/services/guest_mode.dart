import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_auth_service.dart';

/// Using the app without an account: notes stay on this phone, in the same
/// encrypted database, and nothing is sent anywhere.
///
/// Signing in later needs no key migration. The local database has its own
/// at-rest key, and notes are only encrypted with the data key as they leave
/// for the server, so a guest's data key has protected nothing that must
/// survive. Sign-in replaces it with the account's key, or registers it if
/// the account is new, and the first sync uploads the notes under that key.
/// Backups are the one thing that would depend on the guest key, which is why
/// they stay signed-in only.
class GuestMode {
  GuestMode._();

  static const String prefsKey = 'guest_mode_active';

  static final ValueNotifier<bool> active = ValueNotifier(false);
  static bool _listening = false;

  /// True while someone is using the app without an account. Signed-out users
  /// who never chose this stay false, and keep going to the sign-in screen.
  static bool get isGuest =>
      active.value && !BackendAuthService().isAuthenticated;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    active.value = prefs.getBool(prefsKey) ?? false;
    _endOnSignIn();
  }

  static Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
    active.value = true;
    _endOnSignIn();
  }

  static Future<void> end() async {
    active.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  static void _endOnSignIn() {
    if (_listening) return;
    _listening = true;
    BackendAuthService().addListener(() {
      if (BackendAuthService().isAuthenticated && active.value) end();
    });
  }
}
