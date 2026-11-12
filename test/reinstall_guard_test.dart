import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinpoint/services/reinstall_guard.dart';

/// An iOS reinstall keeps the previous install's keychain. Without the guard,
/// "Continue without an account" after a reinstall quietly signed back in to
/// the old account and synced the guest's notes into it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();
  const leftover = {'auth_token': 'old-token', 'db_at_rest_key_v1': 'old-key'};

  Future<Map<String, String>> keychain() => storage.readAll();

  test('a reinstall on iOS clears the keychain left behind', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(Map.of(leftover));

    await ReinstallGuard.run(isIOS: true, storage: storage);

    expect(await keychain(), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(ReinstallGuard.markerKey), isTrue);
  });

  test('an update from an earlier version keeps everything', () async {
    // Earlier versions never wrote the marker, but they did write preferences.
    SharedPreferences.setMockInitialValues({'device_id': 'ios-device'});
    FlutterSecureStorage.setMockInitialValues(Map.of(leftover));

    await ReinstallGuard.run(isIOS: true, storage: storage);

    expect(await keychain(), leftover);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(ReinstallGuard.markerKey), isTrue);
  });

  test('once marked, later launches never clear anything', () async {
    SharedPreferences.setMockInitialValues({ReinstallGuard.markerKey: true});
    FlutterSecureStorage.setMockInitialValues(Map.of(leftover));

    await ReinstallGuard.run(isIOS: true, storage: storage);

    expect(await keychain(), leftover);
  });

  test('Android is left alone: its secure storage goes with the app', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(Map.of(leftover));

    await ReinstallGuard.run(isIOS: false, storage: storage);

    expect(await keychain(), leftover);
  });
}
