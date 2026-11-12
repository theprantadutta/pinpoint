import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pinpoint/constants/shared_preference_keys.dart';
import 'package:pinpoint/services/walkthrough_service.dart';
import 'package:pinpoint/walkthrough/walkthrough_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/sketch_harness.dart';

/// Settings → Replay tutorial pops Settings and then asks for the tour. It
/// used to show it from Settings' own context, which was unmounted by then, so
/// nothing appeared; it also cleared the completed flag, so the tour popped up
/// on the next launch instead.
void main() {
  testWidgets('replay shows the tour on home after Settings closes',
      (tester) async {
    SharedPreferences.setMockInitialValues({kHasCompletedWalkthroughKey: true});

    late BuildContext settingsContext;
    await tester.pumpWidget(sketchApp(Builder(
      builder: (homeContext) => Column(
        children: [
          IconButton(
            key: WalkthroughKeys.searchKey,
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          TextButton(
            onPressed: () => Navigator.of(homeContext).push(MaterialPageRoute(
              builder: (c) {
                settingsContext = c;
                return const Scaffold(body: Text('Settings'));
              },
            )),
            child: const Text('Open settings'),
          ),
        ],
      ),
    )));
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    // What _replayTutorial does.
    Navigator.of(settingsContext).pop();
    // The tour pulses forever, so pump fixed steps rather than settle.
    final replay = WalkthroughService().replay(settle: Duration.zero);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await replay;

    expect(find.text('Settings'), findsNothing);
    expect(find.text('Skip'), findsOneWidget,
        reason: 'the tour should be on screen over home');

    await tester.tap(find.text('Skip'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kHasCompletedWalkthroughKey), isTrue,
        reason: 'a replay must not bring the tour back on the next launch');
  });
}
