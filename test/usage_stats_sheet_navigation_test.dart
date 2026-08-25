import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/widgets/usage_stats_bottom_sheet.dart';

/// Behaviour tests for the "Upgrade to Premium" button in the usage-stats
/// sheet.
///
/// The sheet is presented with `showModalBottomSheet`, so it lives on the
/// Navigator, not on GoRouter's route stack. The button used to call
/// `context.pop()`, which asks GoRouter to pop its OWN stack; which route that
/// actually removed depended on router internals, and in some states
/// `_findCurrentNavigators()` walks into a `ShellRouteMatch` and dereferences
/// `walker.navigatorKey.currentState!` on a branch navigator that was never
/// built, throwing "Null check operator used on a null value"
/// (go_router delegate.dart:126). It now pops the Navigator directly.
///
/// HONEST SCOPE: these tests do NOT reproduce that crash. They pass against
/// the old `context.pop()` too. Reproducing it needs the specific router state
/// that leaves a shell branch's navigator unbuilt while a shell match is last
/// in `currentConfiguration` — in this app the editor that opens this sheet is
/// pushed on the ROOT navigator (`parentNavigatorKey: rootNavigatorKey`), so
/// the usual configuration never enters that loop at all. What these tests do
/// pin is the intended behaviour: the sheet is dismissed, the paywall opens,
/// and the host route is still reachable afterwards. That is enough to catch a
/// regression that pops the wrong navigator, which is the realistic way this
/// gets broken again.
void main() {
  const delegates = <LocalizationsDelegate<dynamic>>[
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    ...material_ui.GlobalMaterialLocalizations.delegates,
  ];

  final shellKey = GlobalKey<NavigatorState>();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              navigatorKey: shellKey,
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const _HostScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/subscription',
          builder: (context, state) =>
              const Scaffold(body: Text('subscription-screen')),
        ),
      ],
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    // The sheet is taller than the default 800x600 test surface, which would
    // report a RenderFlex overflow that has nothing to do with what is under
    // test. Use a phone-shaped viewport instead.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: buildRouter(),
        localizationsDelegates: delegates,
        supportedLocales: LocaleController.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('upgrade button dismisses the sheet and opens the paywall',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
    expect(find.byType(UsageStatsBottomSheet), findsOneWidget);

    final upgrade = find.widgetWithText(
      FilledButton,
      AppL10n.of(tester.element(find.byType(UsageStatsBottomSheet)))
          .usageUpgradeToPremium,
    );
    expect(upgrade, findsOneWidget);

    await tester.tap(upgrade);
    await tester.pumpAndSettle();

    // Not the original crash (see the note above), but it does catch a fix
    // that pops the wrong navigator or leaves the sheet on screen.
    expect(
      tester.takeException(),
      isNull,
      reason: 'Tapping upgrade must not throw.',
    );
    expect(find.byType(UsageStatsBottomSheet), findsNothing,
        reason: 'The sheet must actually be dismissed.');
    expect(find.text('subscription-screen'), findsOneWidget,
        reason: 'The paywall must be pushed after the sheet closes.');
  });

  testWidgets('the host route is still poppable afterwards', (tester) async {
    // Guards against "fixing" the crash by popping the wrong navigator, which
    // would tear down the shell branch instead of the modal.
    await pumpApp(tester);

    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(
      FilledButton,
      AppL10n.of(tester.element(find.byType(UsageStatsBottomSheet)))
          .usageUpgradeToPremium,
    ));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('subscription-screen'));
    GoRouter.of(context).pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('open-sheet'), findsOneWidget,
        reason: 'Popping the paywall must return to the host screen.');
  });
}

class _HostScreen extends StatelessWidget {
  const _HostScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const UsageStatsBottomSheet(),
          ),
          child: const Text('open-sheet'),
        ),
      ),
    );
  }
}
