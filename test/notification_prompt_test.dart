import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/shared/notification_prompt.dart';

import 'support/sketch_harness.dart';

/// The notification ask: a preview of a reminder arriving, what Pinpoint
/// notifies about, and two choices. Regenerate with
/// `flutter test --update-goldens test/notification_prompt_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSketchFonts);

  Widget sheet() => const Align(
        alignment: Alignment.bottomCenter,
        child: NotificationPromptSheet(),
      );

  for (final b in Brightness.values) {
    testWidgets('looks right in ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 760) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sketchApp(sheet(), brightness: b));
      await tester.pumpAndSettle();

      expect(find.text('Turn on notifications'), findsOneWidget);
      expect(find.text('Only the reminders you set'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/notification_prompt_${b.name}.png'),
      );
    });
  }

  testWidgets('fits in Arabic, right to left', (tester) async {
    tester.view.physicalSize = const Size(360, 760) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(sketchApp(sheet(), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/notification_prompt_ar.png'),
    );
  });

  testWidgets('Turn on returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(sketchApp(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const Scaffold(body: NotificationPromptSheet())),
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on notifications'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
