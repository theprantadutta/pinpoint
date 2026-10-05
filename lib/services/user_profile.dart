import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'backend_auth_service.dart';

/// How the user signed in, for "Signed in with …" copy.
enum SignInProvider { google, apple, email, none }

/// Who is signed in, as the Sketchbook header, drawer and settings card show
/// it. Read-only and synchronous: Firebase core is initialised before
/// `runApp`, and the backend email is cached locally, so nothing here waits
/// on the network — it works offline.
class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.firstName,
    required this.email,
    required this.provider,
    this.photoUrl,
  });

  /// Full name if known, else the email's local part, else null.
  final String? displayName;

  /// The first word of [displayName], for "Hello, {firstName}".
  final String? firstName;
  final String? email;
  final SignInProvider provider;
  final String? photoUrl;

  static UserProfile current() {
    User? user;
    try {
      if (Firebase.apps.isNotEmpty) user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase unavailable (tests, a failed init): fall back to the cache.
    }

    final email = user?.email ?? BackendAuthService().userEmail;
    var name = user?.displayName?.trim();
    if (name == null || name.isEmpty) {
      name = _nameFromEmail(email);
    }

    var provider = SignInProvider.none;
    for (final info in user?.providerData ?? const <UserInfo>[]) {
      if (info.providerId == 'google.com') provider = SignInProvider.google;
      if (info.providerId == 'apple.com') provider = SignInProvider.apple;
    }
    if (provider == SignInProvider.none && email != null) {
      provider = SignInProvider.email;
    }

    return UserProfile(
      displayName: name,
      firstName: name?.split(RegExp(r'\s+')).first,
      email: email,
      provider: provider,
      photoUrl: user?.photoURL,
    );
  }

  /// "jane.doe@x.com" → "Jane". Private-relay Apple addresses are random
  /// strings, so those yield nothing rather than a nonsense name.
  static String? _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return null;
    if (email.endsWith('privaterelay.appleid.com')) return null;
    final local = email.split('@').first.split(RegExp(r'[._+\-]')).first;
    if (local.isEmpty || RegExp(r'\d').hasMatch(local)) return null;
    return local[0].toUpperCase() + local.substring(1).toLowerCase();
  }
}
