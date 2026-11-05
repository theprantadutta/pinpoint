import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/guest_mode.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingSync extends SyncService {
  int runs = 0;

  @override
  Future<SyncResult> sync({SyncDirection direction = SyncDirection.both}) async {
    runs++;
    return SyncResult(success: true, message: 'done');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.loadFromString(envString: '''
API_BASE_URL_DEV=http://localhost
API_BASE_URL_PROD=http://localhost
''');
    await GuestMode.end();
  });

  test('choosing it survives a restart', () async {
    await GuestMode.start();
    expect(GuestMode.isGuest, isTrue);

    GuestMode.active.value = false;
    await GuestMode.load();

    expect(GuestMode.isGuest, isTrue);
  });

  test('someone who never chose it is not a guest', () async {
    await GuestMode.load();
    expect(GuestMode.isGuest, isFalse);
  });

  test('a guest never syncs: nothing leaves the phone', () async {
    final service = _CountingSync();
    await SyncManager().init();
    SyncManager().setSyncService(service);
    await GuestMode.start();

    await SyncManager().sync();
    expect(service.runs, 0);

    await GuestMode.end();
    await SyncManager().download();
    expect(service.runs, 1);
  });
}
