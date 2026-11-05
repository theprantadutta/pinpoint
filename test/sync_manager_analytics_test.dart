import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/analytics_recorder.dart';

class _FakeSync extends SyncService {
  _FakeSync(this.run);
  final Future<SyncResult> Function() run;

  @override
  Future<SyncResult> sync({SyncDirection direction = SyncDirection.both}) =>
      run();
}

/// Syncs start from note saves, reconnects and sign-in far more often than
/// from the sync screen, so the manager is what reports them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingAnalyticsFacade analytics;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost
API_BASE_URL_PROD=http://localhost
''');
    FlutterSecureStorage.setMockInitialValues({});
    analytics = RecordingAnalyticsFacade();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    getIt.registerSingleton<AnalyticsFacade>(analytics);
    await SyncManager().init();
  });

  tearDown(() => getIt.unregister<AnalyticsFacade>());

  test('a failed sync reports a closed reason, never the message', () async {
    SyncManager().setSyncService(_FakeSync(() async =>
        SyncResult(success: false, message: 'Connection lost on "Taxes"')));

    await SyncManager().download();

    expect(analytics.names, ['sync_started', 'sync_failed']);
    expect(analytics.one('sync_failed').params.values, ['offline']);
  });

  test('a sync that throws is reported and still reaches the caller', () async {
    SyncManager().setSyncService(_FakeSync(() => throw StateError('boom')));

    await expectLater(SyncManager().download(), throwsStateError);

    expect(analytics.names, ['sync_started', 'sync_failed']);
    expect(SyncManager().isSyncing, isFalse);
  });

  test('a successful sync reports completion', () async {
    SyncManager().setSyncService(
        _FakeSync(() async => SyncResult(success: true, message: 'done')));

    await SyncManager().download();

    expect(analytics.names, ['sync_started', 'sync_completed']);
  });
}
