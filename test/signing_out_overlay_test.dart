import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/components/settings/signing_out_overlay.dart';
import 'package:pinpoint/services/logout_service.dart';

import 'support/project_source.dart';
import 'support/sketch_harness.dart';

/// Signing out covers the app with a progress card until the sign-in screen
/// is up. Regenerate with
/// `flutter test --update-goldens test/signing_out_overlay_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSketchFonts);

  test('each phase maps to its step', () {
    expect(SigningOutOverlay.stepOf(LogoutPhase.validating), 0);
    expect(SigningOutOverlay.stepOf(LogoutPhase.syncing), 0);
    expect(SigningOutOverlay.stepOf(LogoutPhase.signingOut), 1);
    expect(SigningOutOverlay.stepOf(LogoutPhase.cleaningData), 2);
    expect(SigningOutOverlay.stepOf(LogoutPhase.completed), 3);
  });

  Future<void> pump(WidgetTester tester, Widget child,
      {Brightness brightness = Brightness.light, Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(390, 760) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(sketchApp(child, brightness: brightness, locale: locale));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final b in Brightness.values) {
    testWidgets('looks right in ${b.name}', (tester) async {
      final phase = ValueNotifier(LogoutPhase.signingOut);
      await pump(tester, SigningOutOverlay(phase: phase), brightness: b);

      expect(find.text('Signing you out'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'step 1 done');
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'step 2 running');
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/signing_out_${b.name}.png'));
    });
  }

  testWidgets('fits in Arabic, right to left', (tester) async {
    await pump(tester, SigningOutOverlay(phase: ValueNotifier(LogoutPhase.cleaningData)),
        locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/signing_out_ar.png'));
  });

  testWidgets('back does not dismiss it', (tester) async {
    late BuildContext ctx;
    await pump(tester, Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    }));
    final close = SigningOutOverlay.show(ctx, ValueNotifier(LogoutPhase.syncing));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SigningOutOverlay), findsOneWidget);

    close();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SigningOutOverlay), findsNothing);
    close(); // already gone: a no-op
  });

  test('force sign-out really signs out', () {
    final actions = readProjectFile('lib/components/settings/settings_account_actions.dart');
    expect(actions, contains('performLogout(skipSync: true)'));
  });
}
