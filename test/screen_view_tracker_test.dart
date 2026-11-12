import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/services/analytics/screen_view_tracker.dart';

import 'support/analytics_recorder.dart';

/// Each screen the user lands on is one screen_view, tabs and the return from
/// a pushed screen included, and only its route name ever leaves the app.
void main() {
  late GoRouter router;
  late RecordingAnalyticsFacade analytics;
  late StatefulNavigationShell shell;

  List<String> screens() =>
      [for (final e in analytics.all('screen_view')) e.params['screen_name']!];

  setUp(() {
    analytics = RecordingAnalyticsFacade();
    final root = GlobalKey<NavigatorState>();
    router = GoRouter(
      navigatorKey: root,
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return navigationShell;
          },
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/home',
                  name: 'Home',
                  builder: (_, __) => const Text('home')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/notes',
                  name: 'Notes',
                  builder: (_, __) => const Text('notes')),
            ]),
          ],
        ),
        GoRoute(
          parentNavigatorKey: root,
          path: '/folder/:title',
          name: 'Folder Screen',
          builder: (_, __) => const Text('folder'),
        ),
      ],
    );
    addTearDown(router.dispose);
    ScreenViewTracker(router, analytics).start();
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('the first screen is reported once', (tester) async {
    await show(tester);
    expect(screens(), ['Home']);
  });

  testWidgets('tabs are reported, including going back to one', (tester) async {
    await show(tester);
    shell.goBranch(1);
    await tester.pumpAndSettle();
    shell.goBranch(0);
    await tester.pumpAndSettle();
    expect(screens(), ['Home', 'Notes', 'Home']);
  });

  testWidgets('returning from a pushed screen reports the screen underneath',
      (tester) async {
    await show(tester);
    router.push('/folder/Taxes');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(screens(), ['Home', 'Folder Screen', 'Home']);
  });

  testWidgets('a path, which can hold a folder title, is never sent',
      (tester) async {
    await show(tester);
    router.push('/folder/Taxes');
    await tester.pumpAndSettle();
    expect(analytics.allParameterValues.join(' '), isNot(contains('Taxes')));
  });
}
