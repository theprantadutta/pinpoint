import 'package:google_sign_in/google_sign_in.dart';

import '../google_sign_in_service.dart';
import 'drive_backup_client.dart';

/// Drive credentials from the user's Google account.
///
/// Signing in and *authorizing Drive* are separate grants in google_sign_in 7,
/// and kept separate here: signing in to Pinpoint never asks for Drive, and
/// somebody who signed in with email can still back up to any Google account
/// they choose when they turn backups on.
class GoogleDriveAuthorization implements DriveAuthorization {
  const GoogleDriveAuthorization();

  static const List<String> _scopes = [DriveBackupClient.scope];

  @override
  Future<Map<String, String>?> headers({bool interactive = false}) async {
    await GoogleSignInService().ready;
    return GoogleSignIn.instance.authorizationClient
        .authorizationHeaders(_scopes, promptIfNecessary: interactive);
  }

  /// Whether Drive access has been granted, without asking.
  Future<bool> isAuthorized() async {
    try {
      return await headers(interactive: false) != null;
    } catch (_) {
      return false;
    }
  }

  /// Ask for Drive access. Only from something the user pressed.
  Future<bool> requestAccess() async => await headers(interactive: true) != null;

  /// Give the permission back, without signing the user out of anything else.
  Future<void> revoke() async {
    await GoogleSignInService().ready;
    final client = GoogleSignIn.instance.authorizationClient;
    final authorization = await client.authorizationForScopes(_scopes);
    if (authorization == null) return;
    await client.clearAuthorizationToken(accessToken: authorization.accessToken);
  }
}
