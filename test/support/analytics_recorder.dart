import 'package:flutter/foundation.dart';
import 'package:pinpoint/services/analytics/analytics_client.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';

/// One captured analytics event.
class RecordedEvent {
  RecordedEvent(this.name, this.params);

  final String name;
  final Map<String, String> params;

  @override
  String toString() => params.isEmpty ? name : '$name $params';
}

/// Records what the app emits, at the seam the app actually uses.
///
/// `SubscriptionService` and the screens reach analytics through
/// `getIt<AnalyticsFacade>()`, and the facade is a concrete class, so the
/// cheapest faithful fake is a subclass. Nothing is forwarded to the real
/// logger/Firebase paths.
///
/// The event names and parameter keys below are the ones the leaf clients put
/// on the wire; `analytics_wire_shape_test.dart` pins them to
/// `LoggerAnalyticsClient`'s real output so this file cannot drift.
class RecordingAnalyticsFacade extends AnalyticsFacade {
  RecordingAnalyticsFacade();

  final List<RecordedEvent> events = <RecordedEvent>[];

  List<String> get names => [for (final e in events) e.name];

  bool contains(String name) => names.contains(name);

  List<RecordedEvent> all(String name) =>
      [for (final e in events) if (e.name == name) e];

  RecordedEvent one(String name) {
    final matches = all(name);
    if (matches.length != 1) {
      throw StateError('Expected exactly one "$name" event, got '
          '${matches.length}. Recorded: $names');
    }
    return matches.single;
  }

  /// Every parameter value across every captured event — the thing a privacy
  /// guard scans for note content, tokens and raw error text.
  List<String> get allParameterValues =>
      [for (final e in events) ...e.params.values];

  void clear() => events.clear();

  void _rec(String name, [Map<String, String> params = const {}]) =>
      events.add(RecordedEvent(name, params));

  // --- Search -------------------------------------------------------------

  @override
  Future<void> trackSearchPerformed({required int queryLength}) async =>
      _rec('search_performed',
          {'query_length_bucket': searchLengthBucket(queryLength)});

  // --- Subscription -------------------------------------------------------

  @override
  Future<void> trackSubscriptionScreenViewed() async =>
      _rec('subscription_screen_viewed');

  @override
  Future<void> trackCheckoutStarted({required String productId}) async =>
      _rec('checkout_started', {'product_id': productId});

  @override
  Future<void> trackCheckoutLaunchSucceeded({
    required String productId,
  }) async =>
      _rec('checkout_launch_succeeded', {'product_id': productId});

  @override
  Future<void> trackCheckoutLaunchFailed({
    required String productId,
    required String reason,
  }) async =>
      _rec('checkout_launch_failed',
          {'product_id': productId, 'reason': reason});

  @override
  Future<void> trackCheckoutCancelled({required String productId}) async =>
      _rec('checkout_cancelled', {'product_id': productId});

  @override
  Future<void> trackCheckoutPending({required String productId}) async =>
      _rec('checkout_pending', {'product_id': productId});

  @override
  Future<void> trackCheckoutError({
    required String productId,
    required String reason,
  }) async =>
      _rec('checkout_error', {'product_id': productId, 'reason': reason});

  @override
  Future<void> trackStorePurchaseConfirmed({
    required String productId,
    required String source,
  }) async =>
      _rec('store_purchase_confirmed',
          {'product_id': productId, 'source': source});

  @override
  Future<void> trackPurchaseVerified({
    required String productId,
    required String platform,
    required String source,
  }) async =>
      _rec('purchase_verified', {
        'product_id': productId,
        'platform': platform,
        'source': source,
      });

  @override
  Future<void> trackVerificationFailed({
    required String productId,
    required String reason,
  }) async =>
      _rec('verification_failed',
          {'product_id': productId, 'reason': reason});

  @override
  Future<void> trackRestorePurchaseInitiated() async =>
      _rec('restore_purchase_initiated');

  // --- Everything else the screens happen to call -------------------------

  @override
  Future<void> trackScreenView({required String screenName}) async =>
      _rec('screen_view', {'screen_name': screenName});
}

/// Intercepts `debugPrint` and parses `[Analytics] <name> {k: v, ...}` lines.
///
/// Used to assert the REAL wire shape of `LoggerAnalyticsClient`, which is
/// written as a matched pair with `FirebaseAnalyticsClient` (same event names,
/// same parameter keys).
///
/// `debugPrint` is a foundation debug variable: never leave it swapped when a
/// `testWidgets` body ends, or the binding's invariant check fails the test.
class LoggerCapture {
  final List<RecordedEvent> events = <RecordedEvent>[];
  final List<String> lines = <String>[];

  static final RegExp _pattern = RegExp(r'^\[Analytics\] (\S+)(?: \{(.*)\})?$');

  DebugPrintCallback? _previous;

  void start() {
    _previous ??= debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        final match = _pattern.firstMatch(message);
        if (match != null) {
          lines.add(message);
          events.add(RecordedEvent(match.group(1)!, _parse(match.group(2))));
          return;
        }
      }
      _previous?.call(message, wrapWidth: wrapWidth);
    };
  }

  void stop() {
    if (_previous != null) {
      debugPrint = _previous!;
      _previous = null;
    }
  }

  void clear() {
    events.clear();
    lines.clear();
  }

  List<String> get names => [for (final e in events) e.name];

  RecordedEvent one(String name) {
    final matches = [for (final e in events) if (e.name == name) e];
    if (matches.length != 1) {
      throw StateError('Expected exactly one "$name" event, got '
          '${matches.length}. Recorded: $names');
    }
    return matches.single;
  }

  static Map<String, String> _parse(String? body) {
    if (body == null || body.isEmpty) return const <String, String>{};
    final result = <String, String>{};
    for (final pair in body.split(', ')) {
      final i = pair.indexOf(': ');
      if (i == -1) {
        result[pair] = '';
      } else {
        result[pair.substring(0, i)] = pair.substring(i + 2);
      }
    }
    return result;
  }
}
