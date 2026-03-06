import 'package:flutter/material.dart';
import 'analytics_facade.dart';

/// NavigatorObserver that automatically tracks screen_view events
/// for routes pushed onto the root navigator.
class AnalyticsRouteObserver extends NavigatorObserver {
  final AnalyticsFacade _analytics;

  AnalyticsRouteObserver(this._analytics);

  void _trackRoute(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      _analytics.trackScreenView(screenName: name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _trackRoute(previousRoute);
  }
}
