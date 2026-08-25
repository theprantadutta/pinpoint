import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/main.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';

void main() {
  setUpAll(() {
    // Initialize GetIt before any tests run
    initServiceLocators();

    // The real .env is loaded by main(), which this test bypasses by pumping
    // MyApp directly. ApiService reads its base URL in a static initialiser, so
    // the very first widget build throws NotInitializedError without this.
    // Values are dummies — nothing here performs a request.
    dotenv.loadFromString(
      envString: '''
API_BASE_URL_DEV=http://localhost:8645
API_BASE_URL_PROD=http://localhost:8645
GOOGLE_WEB_CLIENT_ID=test-client-id
''',
    );
  });

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
