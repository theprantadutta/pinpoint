import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/analytics/analytics_client.dart';
import 'package:pinpoint/services/search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/project_source.dart';

/// Review 2026-11-01, F8 and F12: note content stays out of unencrypted
/// storage, logs and analytics, and a note being typed survives the app
/// going to the background.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sync failures reach analytics as closed codes, never text', () {
    expect(syncFailureReason('SocketException: Connection refused'), 'offline');
    expect(syncFailureReason('DioException 401 Unauthorized'), 'unauthorized');
    expect(syncFailureReason('Sync limit reached. Upgrade to premium'), 'limit');
    expect(syncFailureReason('Your encryption key is not available yet.'), 'encryption_key');
    expect(syncFailureReason('HTTP 503 from server'), 'server_error');
    expect(syncFailureReason('Note "Divorce lawyer" failed'), 'unknown');
    expect(readProjectFile('lib/services/analytics/firebase_analytics_client.dart'),
        contains("parameters: {'reason': reason}"));
  });

  test('recent searches are not kept in SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({'search_history': ['old secret query']});
    await SearchService().initialize();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('search_history'), isNull);
    expect(readProjectFile('lib/services/search_service.dart'), isNot(contains('setStringList(')));
  });

  test('notification titles and bodies are never logged', () {
    final src = readProjectFile('lib/services/firebase_notification_service.dart');
    expect(src, isNot(contains('notification?.title}')));
    expect(src, isNot(contains('notification?.body}')));
    expect(src, isNot(contains("'Data: \${message.data}'")));
  });

  test('the editor saves when the app is backgrounded', () {
    final src = readProjectFile('lib/screens/create_note_screen_v2.dart');
    expect(src, contains('with WidgetsBindingObserver'));
    expect(src, contains('void didChangeAppLifecycleState(AppLifecycleState state)'));
    expect(src, contains('_autoSaveNote();'));
  });
}
