import 'package:go_router/go_router.dart';

import 'analytics_facade.dart';

/// Reports one screen_view each time the user lands on a different screen.
///
/// It listens to the router rather than the navigator: the tabs live on nested
/// navigators, and a root navigator observer never sees them, or the return to
/// them when a pushed screen is popped. Only the route's name is sent, never
/// its path, which can carry folder titles and note ids.
class ScreenViewTracker {
  ScreenViewTracker(this._router, this._analytics);

  final GoRouter _router;
  final AnalyticsFacade _analytics;
  String? _current;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _router.routerDelegate.addListener(_report);
    _report();
  }

  void _report() {
    // Empty for a moment on first load, and while a pop is being resolved.
    if (_router.routerDelegate.currentConfiguration.isEmpty) return;
    final name = _router.state.name;
    if (name == null || name == _current) return;
    _current = name;
    _analytics.trackScreenView(screenName: name);
  }
}
