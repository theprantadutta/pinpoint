import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/crash_breadcrumbs.dart';

/// [CrashBreadcrumbs] exists to explain crashes, so the one property it must
/// never violate is causing one.
///
/// These run with no Firebase initialised and no platform channels mocked —
/// the same situation as a release build where `Firebase.initializeApp` failed,
/// which is exactly when the breadcrumb calls are most likely to be reached and
/// least likely to have been exercised.
void main() {
  test('breadcrumb calls are safe with no Firebase available', () {
    expect(() => CrashBreadcrumbs.log('hello'), returnsNormally);
    expect(() => CrashBreadcrumbs.setKey('k', 'v'), returnsNormally);
    expect(() => CrashBreadcrumbs.popupMenuOpened('notes.sort'), returnsNormally);
    expect(() => CrashBreadcrumbs.popupMenuClosed('notes.sort'), returnsNormally);
    expect(
      () => CrashBreadcrumbs.popupMenuClosed('notes.sort', selected: 'sort:title'),
      returnsNormally,
    );
  });

  testWidgets('a menu wired the way the app wires it opens and selects cleanly',
      (tester) async {
    // Mirrors the onOpened/onCanceled/onSelected trio added to all four
    // PopupMenuButtons, so a breadcrumb call placed in the wrong callback
    // signature is caught here rather than in the field.
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onOpened: () => CrashBreadcrumbs.popupMenuOpened('test.menu'),
                onCanceled: () => CrashBreadcrumbs.popupMenuClosed('test.menu'),
                onSelected: (value) {
                  CrashBreadcrumbs.popupMenuClosed('test.menu', selected: value);
                  selected = value;
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(value: 'a', child: Text('Item A')),
                ],
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Item A'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(selected, 'a');
  });
}
