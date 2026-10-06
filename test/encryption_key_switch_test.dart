import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/encryption_service.dart';

import 'support/project_source.dart';

class _FakeKeyApi {
  _FakeKeyApi(this.key);
  String key;
  int fetches = 0;
  Future<String?> getEncryptionKey() async {
    fetches++;
    return key;
  }

  Future<void> storeEncryptionKey(String k) async {}
}

/// Signing out and into another account without restarting the app must load
/// the new account's key. The old one stayed in memory, the key sync was
/// skipped as "already synced this session", and every note of the second
/// account failed to decrypt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The key sync asks BackendAuthService which account is signed in, which
  // constructs ApiService, which reads dotenv. Nothing here talks to a server.
  setUpAll(() => dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
'''));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final keyA = enc.Key.fromSecureRandom(32).base64;
  final keyB = enc.Key.fromSecureRandom(32).base64;

  test('after sign-out the next key sync fetches the new account key', () async {
    final api = _FakeKeyApi(keyA);
    expect(await SecureEncryptionService.syncKeyFromCloud(api, force: true), isTrue);
    final fromA = SecureEncryptionService.encrypt('note of account A');

    SecureEncryptionService.forgetKey();
    expect(() => SecureEncryptionService.encrypt('x'), throwsException,
        reason: 'no key in memory once signed out');

    api.key = keyB;
    expect(await SecureEncryptionService.syncKeyFromCloud(api), isTrue);
    expect(api.fetches, 2, reason: 'not skipped as "already synced"');
    final fromB = SecureEncryptionService.encrypt('note of account B');
    expect(SecureEncryptionService.decrypt(fromB), 'note of account B');
    expect(() => SecureEncryptionService.decrypt(fromA), throwsException,
        reason: 'account B is now on its own key');
  });

  test('sign-out forgets the key in memory, not only in storage', () {
    expect(readProjectFile('lib/services/logout_service.dart'),
        contains('SecureEncryptionService.forgetKey()'));
  });
}
