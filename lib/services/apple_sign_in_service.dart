import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:pinpoint/services/logger_service.dart';

/// Service to handle Sign in with Apple authentication flow.
///
/// Required by App Store Review Guideline 4.8: because Pinpoint offers a
/// third-party login (Google), it must also offer Sign in with Apple on iOS.
///
/// This mirrors [GoogleSignInService]: it authenticates with Apple, exchanges
/// the Apple credential for a Firebase credential, and produces a Firebase ID
/// token that the Pinpoint backend verifies via the existing /auth/firebase
/// endpoint (no backend endpoint changes required).
class AppleSignInService {
  static final AppleSignInService _instance = AppleSignInService._internal();
  factory AppleSignInService() => _instance;
  AppleSignInService._internal();

  // Lazy access so we never touch FirebaseAuth before Firebase is initialized.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Current Firebase user (may have been set by any provider).
  User? get currentUser => _auth.currentUser;

  /// Whether Sign in with Apple is available on this device/platform.
  static Future<bool> isAvailable() => SignInWithApple.isAvailable();

  /// Generate a cryptographically secure random nonce.
  ///
  /// The SHA-256 hash of this value is sent to Apple; the raw value is handed
  /// to Firebase so it can verify the returned identity token was minted for
  /// this request (replay protection).
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Sign in with Apple and authenticate with Firebase.
  ///
  /// Returns a [UserCredential] on success, or null if the flow could not
  /// produce an identity token. Throws on user cancellation / errors so the
  /// caller can surface a message (same contract as [GoogleSignInService]).
  Future<UserCredential?> signInWithApple() async {
    try {
      log.i('Starting Sign in with Apple...');

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        log.e('Failed to get Apple identity token');
        throw Exception('Failed to get Apple identity token');
      }

      // Build a Firebase OAuth credential for the apple.com provider.
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      log.i('Creating Firebase credential for Apple...');
      final result = await _auth.signInWithCredential(oauthCredential);

      // Apple returns the user's name ONLY on the very first authorization.
      // Persist it to the Firebase profile if we got it and don't have one yet.
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final currentDisplayName = result.user?.displayName;
      if ((currentDisplayName == null || currentDisplayName.isEmpty) &&
          (givenName != null || familyName != null)) {
        final displayName = [givenName, familyName]
            .where((p) => p != null && p.isNotEmpty)
            .join(' ')
            .trim();
        if (displayName.isNotEmpty) {
          await result.user?.updateDisplayName(displayName);
          await result.user?.reload();
        }
      }

      if (result.user != null) {
        log.i('Firebase Apple sign-in successful: ${result.user!.uid}');
      }
      return result;
    } on SignInWithAppleAuthorizationException catch (e) {
      // User cancelled or Apple rejected the request.
      log.w('Sign in with Apple cancelled/failed: ${e.code} - ${e.message}');
      rethrow;
    } on FirebaseAuthException catch (e) {
      log.e('Firebase Auth error during Apple Sign-In: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      log.e('Error signing in with Apple', e, stackTrace);
      rethrow;
    }
  }

  /// Get Firebase ID token for backend authentication.
  Future<String?> getFirebaseIdToken() async {
    try {
      final user = currentUser;
      if (user == null) {
        log.w('Cannot get ID token: no user signed in');
        return null;
      }
      final token = await user.getIdToken();
      log.i('Retrieved Firebase ID token (Apple)');
      return token;
    } catch (e, stackTrace) {
      log.e('Error getting Firebase ID token (Apple)', e, stackTrace);
      return null;
    }
  }
}
