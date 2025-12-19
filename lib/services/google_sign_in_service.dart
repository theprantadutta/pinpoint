import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pinpoint/services/logger_service.dart';

/// Service to handle Google Sign-In authentication flow
///
/// This service coordinates between Google Sign-In, Firebase Authentication,
/// and the Pinpoint backend to provide a complete authentication solution.
class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;

  // Lazy initialization - don't access FirebaseAuth until actually needed
  // This prevents errors when Firebase isn't initialized yet
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInService._internal() {
    // Initialize Google Sign-In with client ID from environment
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (webClientId != null && webClientId.isNotEmpty) {
      _googleSignIn.initialize(
        serverClientId: webClientId,
      );
      log.i('Google Sign-In initialized with Web Client ID');
    } else {
      log.w('GOOGLE_WEB_CLIENT_ID not found in environment variables');
    }
  }

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in to Firebase
  bool get isSignedIn => currentUser != null;

  /// Stream of Firebase auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google and authenticate with Firebase
  ///
  /// Returns a [UserCredential] on success, null on failure
  ///
  /// Flow:
  /// 1. Check if Google Sign-In authenticate is supported
  /// 2. Trigger Google Sign-In flow
  /// 3. Get Google authentication tokens
  /// 4. Create Firebase credential
  /// 5. Sign in to Firebase with the credential
  Future<UserCredential?> signInWithGoogle() async {
    try {
      log.i('Starting Google Sign-In...');

      // Check if authentication is supported on this platform
      if (_googleSignIn.supportsAuthenticate()) {
        // Use authenticate method for supported platforms
        final GoogleSignInAccount googleUser =
            await _googleSignIn.authenticate();

        log.i('Google user signed in: ${googleUser.email}');

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        if (googleAuth.idToken == null) {
          log.e('Failed to get Google ID token');
          throw Exception('Failed to get Google ID token');
        }

        // Create a new Firebase credential
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        log.i('Creating Firebase credential...');

        // Sign in to Firebase with the credential
        final UserCredential result =
            await _auth.signInWithCredential(credential);

        if (result.user != null) {
          log.i('Firebase sign-in successful: ${result.user!.uid}');
        }

        return result;
      } else {
        log.e('Google Sign-In authenticate not supported on this platform');
        return null;
      }
    } on FirebaseAuthException catch (e) {
      log.e(
          'Firebase Auth error during Google Sign-In: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      log.e('Error signing in with Google', e, stackTrace);
      rethrow;
    }
  }

  /// Get Firebase ID token for backend authentication
  ///
  /// This token should be sent to the backend for verification
  Future<String?> getFirebaseIdToken() async {
    try {
      final user = currentUser;
      if (user == null) {
        log.w('Cannot get ID token: no user signed in');
        return null;
      }

      final token = await user.getIdToken();
      log.i('Retrieved Firebase ID token');
      return token;
    } catch (e, stackTrace) {
      log.e('Error getting Firebase ID token', e, stackTrace);
      return null;
    }
  }

  /// Sign out from both Google and Firebase
  Future<void> signOut() async {
    try {
      log.i('Signing out from Google and Firebase...');
      await _googleSignIn.signOut();
      await _auth.signOut();
      log.i('Sign out successful');
    } catch (e, stackTrace) {
      log.e('Error signing out', e, stackTrace);
      rethrow;
    }
  }
}
