import 'package:flutter_test/flutter_test.dart';

import 'package:pinpoint/services/analytics/analytics_client.dart';
import 'package:pinpoint/services/analytics/logger_analytics_client.dart';

import 'support/analytics_recorder.dart';
import 'support/project_source.dart';

/// Pins the event names and parameter keys that go on the wire.
///
/// Two things are checked, and together they close the loop for the other test
/// files:
///
/// 1. `RecordingAnalyticsFacade` (the fake the purchase tests assert against)
///    produces exactly what `LoggerAnalyticsClient` really emits, so those
///    assertions are about production strings and not about the fake.
/// 2. `FirebaseAnalyticsClient` — which cannot be executed in a unit test,
///    it needs a live Firebase — declares the same names and keys. The two
///    leaf clients are written as a matched pair and must stay one.
void main() {
  /// Every subscription/search call, invoked identically on both clients.
  final calls = <String, Future<void> Function(AnalyticsClient)>{
    'search_performed': (c) => c.trackSearchPerformed(queryLength: 7),
    'subscription_screen_viewed': (c) => c.trackSubscriptionScreenViewed(),
    'checkout_started': (c) => c.trackCheckoutStarted(productId: 'p'),
    'checkout_launch_succeeded': (c) =>
        c.trackCheckoutLaunchSucceeded(productId: 'p'),
    'checkout_launch_failed': (c) =>
        c.trackCheckoutLaunchFailed(productId: 'p', reason: 'launch_rejected'),
    'checkout_cancelled': (c) => c.trackCheckoutCancelled(productId: 'p'),
    'checkout_pending': (c) => c.trackCheckoutPending(productId: 'p'),
    'checkout_error': (c) =>
        c.trackCheckoutError(productId: 'p', reason: 'purchase_error'),
    'store_purchase_confirmed': (c) =>
        c.trackStorePurchaseConfirmed(productId: 'p', source: 'purchase'),
    'purchase_verified': (c) => c.trackPurchaseVerified(
        productId: 'p', platform: 'android', source: 'purchase'),
    'verification_failed': (c) => c.trackVerificationFailed(
        productId: 'p', reason: 'verification_rejected'),
    'restore_purchase_initiated': (c) => c.trackRestorePurchaseInitiated(),
  };

  test('the recording fake emits exactly what LoggerAnalyticsClient emits',
      () async {
    final capture = LoggerCapture()..start();
    addTearDown(capture.stop);

    for (final entry in calls.entries) {
      capture.clear();
      final fake = RecordingAnalyticsFacade();

      await entry.value(LoggerAnalyticsClient());
      await entry.value(fake);

      expect(capture.names, [entry.key],
          reason: 'LoggerAnalyticsClient emitted the wrong event name for '
              '${entry.key}.');
      expect(fake.names, [entry.key]);
      expect(
        fake.one(entry.key).params,
        capture.one(entry.key).params,
        reason: 'The test fake and the real client disagree about '
            '${entry.key}. One of them has drifted.',
      );
    }
  });

  test('FirebaseAnalyticsClient declares the same names and keys', () {
    final source =
        readProjectFile('lib/services/analytics/firebase_analytics_client.dart');
    final logger =
        readProjectFile('lib/services/analytics/logger_analytics_client.dart');

    for (final name in calls.keys) {
      expect(source, contains("name: '$name'"),
          reason: 'Firebase client is missing the $name event.');
      expect(logger, contains("_log('$name'"),
          reason: 'Logger client is missing the $name event.');
    }

    for (final key in const [
      'query_length_bucket',
      'product_id',
      'reason',
      'source',
      'platform',
    ]) {
      expect(source, contains("'$key'"));
      expect(logger, contains("'$key'"));
    }
  });

  test('the deleted events are gone from every analytics file', () {
    for (final path in const [
      'lib/services/analytics/analytics_client.dart',
      'lib/services/analytics/analytics_facade.dart',
      'lib/services/analytics/firebase_analytics_client.dart',
      'lib/services/analytics/logger_analytics_client.dart',
    ]) {
      final source = readProjectFile(path);
      for (final gone in const [
        'trackPurchaseCompleted',
        'trackPurchaseInitiated',
        'trackPurchaseFailed',
        // Quoted, so `restore_purchase_initiated` — which is still a real
        // event — does not match as a substring.
        "'purchase_completed'",
        "'purchase_initiated'",
        "'purchase_failed'",
      ]) {
        expect(source.contains(gone), isFalse, reason: '$path still has $gone');
      }
    }
  });
}
