import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/database/database.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_client.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/encryption_service.dart';
import 'package:pinpoint/sync/api_sync_service.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';

/// GA4, 24-26 Nov 2026: 27 of 30 `sync_failed` events said `server_error`,
/// yet the server and Traefik logged no 5xx on any sync endpoint in that
/// time. The reason was read from error text, and a phone with no network
/// fails with ApiService's "Unable to connect to server." (and a slow one
/// with "Server is taking too long to respond."): both contain "server".
/// Reasons now come from the error's type and status code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ApiError api(ApiErrorType type, {int? status, String message = 'x'}) =>
      ApiError(userMessage: message, type: type, statusCode: status);

  group('reason from the error type', () {
    test('no network is offline, not a server error', () {
      expect(
          syncFailureReason(api(ApiErrorType.network,
              message: 'Unable to connect to server.')),
          'offline');
      expect(syncFailureReason(const SocketException('Failed host lookup')),
          'offline');
      expect(syncFailureReason(const HttpException('Connection closed')),
          'offline');
    });

    test('a timeout is a timeout, not a server error', () {
      expect(
          syncFailureReason(api(ApiErrorType.timeout,
              message: 'Server is taking too long to respond.')),
          'timeout');
      expect(syncFailureReason(TimeoutException('slow')), 'timeout');
    });

    test('only a 5xx answer is a server error', () {
      expect(syncFailureReason(api(ApiErrorType.serverError, status: 500)),
          'server_error');
      expect(syncFailureReason(api(ApiErrorType.maintenance, status: 503)),
          'server_error');
      // Cloudflare's own 52x pages (origin down) reach the default branch.
      expect(syncFailureReason(api(ApiErrorType.unknown, status: 522)),
          'server_error');
    });

    test('a refused request is not a server error', () {
      expect(syncFailureReason(api(ApiErrorType.unauthorized, status: 401)),
          'unauthorized');
      expect(syncFailureReason(api(ApiErrorType.unknown, status: 400)),
          'rejected');
      expect(syncFailureReason(api(ApiErrorType.unknown, status: 413)),
          'rejected');
      expect(syncFailureReason(api(ApiErrorType.conflict, status: 409)),
          'rejected');
      expect(syncFailureReason(api(ApiErrorType.forbidden, status: 403)),
          'rejected');
      expect(syncFailureReason(RateLimitExceededException('slow down')),
          'rate_limited');
    });

    test('an error with no response and no known cause is unknown', () {
      expect(syncFailureReason(api(ApiErrorType.unknown)), 'unknown');
      expect(syncFailureReason(StateError('boom')), 'unknown');
    });
  });

  group('reason from text (results that carry no error)', () {
    test('the key message is encryption_key, though it mentions the connection',
        () {
      expect(
          syncFailureReason('Your encryption key is not available yet. '
              'Check your connection and try again.'),
          'encryption_key');
    });

    test("ApiService's own wording is never read as a server error", () {
      expect(syncFailureReason('Exception: Upload failed: Upload failed: '
              'Unable to connect to server.'),
          'offline');
      expect(syncFailureReason('Folder sync failed: Folder upload failed: '
              'Server is taking too long to respond.'),
          'timeout');
    });

    test('codes stay a closed set', () {
      const codes = {
        'offline', 'timeout', 'unauthorized', 'limit', 'rate_limited',
        'encryption_key', 'rejected', 'server_error', 'unknown',
      };
      for (final input in <Object?>[
        null, '', 'Note "Divorce lawyer" failed', 'HTTP 503',
        api(ApiErrorType.notFound, status: 404), Exception('whatever'),
      ]) {
        expect(codes, contains(syncFailureReason(input)), reason: '$input');
      }
    });
  });

  group('end to end, through the real ApiService', () {
    late AppDatabase db;
    late RecordingAnalyticsFacade analytics;

    setUpAll(() => dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://127.0.0.1:1
API_BASE_URL_PROD=http://127.0.0.1:1
GOOGLE_WEB_CLIENT_ID=test-client-id
'''));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      SecureEncryptionService.debugInitializeWithKey(
          enc.Key.fromSecureRandom(32));
      db = AppDatabase.forTesting(NativeDatabase.memory());
      if (getIt.isRegistered<AppDatabase>()) getIt.unregister<AppDatabase>();
      getIt.registerSingleton<AppDatabase>(db);
      analytics = RecordingAnalyticsFacade();
      if (getIt.isRegistered<AnalyticsFacade>()) {
        getIt.unregister<AnalyticsFacade>();
      }
      getIt.registerSingleton<AnalyticsFacade>(analytics);
      await SyncManager().init();
    });

    tearDown(() async {
      getIt.unregister<AnalyticsFacade>();
      getIt.unregister<AppDatabase>();
      await db.close();
    });

    test('a sync with the server unreachable is reported as offline',
        () async {
      // Port 1 refuses the connection: what a phone without network sees.
      // flutter_test answers every request with a 400 unless real sockets
      // are put back.
      final mocked = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = mocked);
      SyncManager().setSyncService(
          ApiSyncService(apiService: ApiService(), database: db));

      final result = await SyncManager().sync();

      expect(result.success, isFalse);
      expect(analytics.names, ['sync_started', 'sync_failed']);
      expect(analytics.one('sync_failed').params, {'reason': 'offline'});
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('the failure behind a result is kept for classification', () async {
      SyncManager().setSyncService(_FailingSync(
          api(ApiErrorType.network, message: 'Unable to connect to server.')));

      final result = await SyncManager().upload();

      expect(result.success, isFalse);
      expect(result.error, isA<ApiError>());
      expect(analytics.one('sync_failed').params, {'reason': 'offline'});
    });
  });
}

/// Upload fails the way ApiSyncService does: the error is caught and returned.
class _FailingSync extends SyncService {
  _FailingSync(this.cause);
  final Object cause;

  @override
  Future<SyncResult> uploadChanges() async =>
      SyncResult(success: false, message: 'Upload failed: $cause', error: cause);
}
