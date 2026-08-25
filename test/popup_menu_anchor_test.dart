import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/widgets/pinpoint_popup_menu_button.dart';

/// Tests for [PinpointPopupMenuButton], the replacement for `PopupMenuButton`
/// used across the app.
///
/// ## What it is for
///
/// `PopupMenuButton` re-derives its position from the button's render object on
/// every relayout of the OPEN menu, guarding only `attached` — never whether
/// the box was laid out. Crashlytics reported the consequence:
///
/// ```
/// Bad state: RenderBox was not laid out: RenderTransform#b91c5
///   at PopupMenuButtonState._positionBuilder (popup_menu.dart:1671)
/// ```
///
/// It happens when an ancestor transform is NEWLY inserted — a page transition
/// starting while the menu is open — so it has never been laid out at the
/// moment the menu's LayoutBuilder reads it. [PinpointPopupMenuButton] resolves
/// the anchor once at open time and hands `showMenu` a fixed rect, so nothing
/// later can reach the button's render object at all.
///
/// ## HONEST SCOPE
///
/// These tests do NOT reproduce that crash. An attempt using `Offstage` failed:
/// hiding a button that has already been laid out leaves its size cached, so
/// `size` does not throw. Reproducing it needs an ancestor transform created
/// between frames and laid out after the overlay — order-dependent enough that
/// chasing it was not worth the time against a fix that removes the whole class
/// of failure by construction.
///
/// What these tests do pin is the replacement's behaviour: it opens, reports
/// selection and cancellation, closes, and declines to open an empty menu —
/// i.e. that swapping it in did not regress the four menus that use it.
void main() {
  /// Pumps [menuButton] inside a toggleable [Offstage] and returns a setter
  /// that hides it.
  Future<void Function()> pumpMenu(
    WidgetTester tester,
    Widget menuButton,
  ) async {
    late StateSetter setState;
    var hidden = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return Offstage(
              offstage: hidden,
              child: Scaffold(
                appBar: AppBar(actions: [menuButton]),
                body: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    return () => setState(() => hidden = true);
  }

  List<PopupMenuEntry<String>> items(BuildContext context) =>
      const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'a', child: Text('Item A')),
        PopupMenuItem<String>(value: 'b', child: Text('Item B')),
      ];

  testWidgets('an open menu survives its host being hidden', (tester) async {
    // Not the reported crash (see the note above), but it is the nearest
    // sequence that can be expressed in a test, and it is cheap to keep.
    final hide = await pumpMenu(
      tester,
      PinpointPopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: items,
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Item A'), findsOneWidget);

    hide();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'The anchor is resolved once at open time, so no relayout of '
          'the open menu reaches the button at all.',
    );
  });

  testWidgets('opens, reports selection, and closes', (tester) async {
    String? selected;
    var opened = 0;

    await pumpMenu(
      tester,
      PinpointPopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: items,
        onOpened: () => opened++,
        onSelected: (value) => selected = value,
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(opened, 1);

    await tester.tap(find.text('Item B'));
    await tester.pumpAndSettle();

    expect(selected, 'b');
    expect(find.text('Item B'), findsNothing, reason: 'Menu must close.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports cancellation when dismissed without a selection',
      (tester) async {
    var cancelled = 0;

    await pumpMenu(
      tester,
      PinpointPopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: items,
        onCanceled: () => cancelled++,
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap the modal barrier.
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();

    expect(cancelled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty item list opens nothing', (tester) async {
    var opened = 0;

    await pumpMenu(
      tester,
      PinpointPopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (_) => const <PopupMenuEntry<String>>[],
        onOpened: () => opened++,
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(opened, 0, reason: 'onOpened must not fire for an empty menu.');
    expect(tester.takeException(), isNull);
  });
}
