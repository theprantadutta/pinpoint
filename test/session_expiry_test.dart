import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/navigation/session_expiry.dart';
import 'package:pinpoint/services/api_service.dart';

/// Nov 2026, A24: on a fresh install a startup request was refused (no
/// session), the session-expired handler queued "go to sign-in" for the next
/// frame, and the still onboarding page drew none until its first tap, so
/// "Get started" and the legal links all landed on the sign-in screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
'''));

  group('sessionExpiryShouldRedirect', () {
    test('never from the screens a signed-out person belongs on', () {
      for (final path in const [
        '/splash',
        '/onboarding',
        '/terms-acceptance',
        '/auth',
      ]) {
        expect(sessionExpiryShouldRedirect(path), isFalse, reason: path);
      }
    });

    test('from the app itself', () {
      expect(sessionExpiryShouldRedirect('/home'), isTrue);
      expect(sessionExpiryShouldRedirect('/settings'), isTrue);
    });
  });

  group('ApiService.hadSession', () {
    test('a fresh install has no session to expire', () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await ApiService().hadSession(), isFalse);
    });

    test('a refresh token alone is a session', () async {
      FlutterSecureStorage.setMockInitialValues({'refresh_token': 'r'});
      final keys = await const FlutterSecureStorage().readAll();
      // Only meaningful if the key name matches ApiService's.
      expect(keys.containsKey('refresh_token'), isTrue);
      expect(await ApiService().hadSession(), isTrue);
    });
  });
}
