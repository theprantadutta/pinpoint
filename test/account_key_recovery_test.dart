import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/encryption_key_errors.dart';
import 'package:pinpoint/services/encryption_service.dart';

import 'support/project_source.dart';

/// A server that can be made to fail, remember keys, or already hold one.
class _Server {
  String? stored;
  Object? readFailure;
  bool rejectWrites = false;
  bool zeroKnowledge = false;
  int reads = 0;
  final writes = <String>[];

  Future<String?> getEncryptionKey() async {
    reads++;
    if (zeroKnowledge) throw const ZeroKnowledgeAccountException();
    final failure = readFailure;
    if (failure != null) throw failure;
    return stored;
  }

  Future<void> storeEncryptionKey(String key) async {
    writes.add(key);
    if (zeroKnowledge) throw const ZeroKnowledgeAccountException();
    if (stored != null && stored != key) throw const EncryptionKeyExistsException();
    stored = key;
  }
}

/// Review 2026-11-01, F2 + F3: failing to *read* an account's key used to
/// generate a new one and upload it over the real one, and a zero-knowledge
/// account was handed its raw key back on every start.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
'''));
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SecureEncryptionService.forgetKey();
  });

  final realKey = enc.Key.fromSecureRandom(32).base64;
  Future<String?> localKey() => const FlutterSecureStorage().read(key: 'encryption_key');

  test('a failed read never generates or uploads a key', () async {
    final server = _Server()
      ..stored = realKey
      ..readFailure = Exception('timeout');

    expect(await SecureEncryptionService.syncKeyFromCloud(server, maxRetries: 1), isFalse);
    expect(server.writes, isEmpty);
    expect(await localKey(), isNull);
    expect(SecureEncryptionService.keyConfirmedForCurrentAccount, isFalse);

    await expectLater(SecureEncryptionService.initialize(apiService: server),
        throwsA(isA<KeyRecoveryPendingException>()));
    expect(server.writes, isEmpty);
    expect(server.stored, realKey, reason: 'the account key is untouched');
  });

  test('once the server answers, the real key is used', () async {
    final server = _Server()
      ..stored = realKey
      ..readFailure = Exception('500');
    expect(await SecureEncryptionService.ensureAccountKey(server), isFalse);

    server.readFailure = null;
    expect(await SecureEncryptionService.ensureAccountKey(server), isTrue);
    expect(await localKey(), realKey);
    expect(SecureEncryptionService.keyConfirmedForCurrentAccount, isTrue);
  });

  test('a confirmed new account registers exactly one key', () async {
    final server = _Server();
    expect(await SecureEncryptionService.syncKeyFromCloud(server), isTrue);
    expect(server.writes, hasLength(1));
    expect(server.stored, await localKey());
  });

  test('if another device registered first, its key is adopted', () async {
    final server = _Server();
    // This device saw "no key" but loses the race to register.
    var first = true;
    final racing = _RacingServer(server, onFirstWrite: () {
      if (first) {
        first = false;
        server.stored = realKey;
      }
    });

    expect(await SecureEncryptionService.syncKeyFromCloud(racing), isTrue);
    expect(server.stored, realKey);
    expect(await localKey(), realKey, reason: 'one key for the account, on every device');
  });

  test('signing in as a guest: the account key replaces the guest key', () async {
    final guestKey = enc.Key.fromSecureRandom(32).base64;
    FlutterSecureStorage.setMockInitialValues({'encryption_key': guestKey});
    final server = _Server()..stored = realKey;

    expect(await SecureEncryptionService.syncKeyFromCloud(server), isTrue);

    expect(await localKey(), realKey);
    expect(server.stored, realKey);
    expect(server.writes, isEmpty);
  });

  test('a guest creating an account keeps the key they already have', () async {
    final guestKey = enc.Key.fromSecureRandom(32).base64;
    FlutterSecureStorage.setMockInitialValues({'encryption_key': guestKey});
    final server = _Server();

    expect(await SecureEncryptionService.syncKeyFromCloud(server), isTrue);

    expect(await localKey(), guestKey);
    expect(server.stored, guestKey);
  });

  test('a zero-knowledge account is never asked for, or given, a raw key', () async {
    FlutterSecureStorage.setMockInitialValues({'zk_mode': 'zero_knowledge', 'encryption_key': realKey});
    SecureEncryptionService.debugInitializeWithKey(enc.Key.fromBase64(realKey));
    final server = _Server()..zeroKnowledge = true;

    expect(await SecureEncryptionService.syncKeyFromCloud(server, force: true), isTrue);
    expect(server.reads, 0);
    expect(server.writes, isEmpty);
  });

  test('wired: absence is only the server\'s explicit code, and sync waits for the key', () {
    final api = readProjectFile('lib/services/api_service.dart');
    expect(api, contains("e.response?.statusCode == 404 && code == 'ENCRYPTION_KEY_NOT_FOUND'"));
    final sync = readProjectFile('lib/sync/sync_manager.dart');
    expect(sync, contains('if (!await _accountKeyReady())'));
    expect(readProjectFile('lib/services/encryption_service.dart'),
        isNot(contains('// Continue to generate new key')));
  });
}

/// Runs a hook before the first write reaches [server], to stage a race.
class _RacingServer {
  _RacingServer(this.server, {required this.onFirstWrite});
  final _Server server;
  final void Function() onFirstWrite;

  Future<String?> getEncryptionKey() => server.getEncryptionKey();
  Future<void> storeEncryptionKey(String key) async {
    onFirstWrite();
    return server.storeEncryptionKey(key);
  }
}
