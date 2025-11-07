import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/main.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';

void main() {
  setUpAll(() {
    // Initialize GetIt before any tests run
    initServiceLocators();
  });

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
