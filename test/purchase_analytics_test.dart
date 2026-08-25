import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/subscription_service.dart';

import 'support/analytics_recorder.dart';
import 'support/fake_in_app_purchase.dart';
import 'support/project_source.dart';

/// Truthfulness of the checkout funnel.
///
/// The old code emitted `purchase_completed` the moment `buyNonConsumable()`
/// returned true — i.e. when the billing SHEET opened, before the user had paid
/// anything and before the backend had verified anything. Every abandoned
/// checkout counted as a sale. The rule now is: `purchase_verified` is the one
/// and only conversion event, and it fires only after verification succeeds.
///
/// The second rule these tests pin: analytics parameters carry coarse
/// closed-set codes, never store prose, exception strings or purchase tokens.
void main() {
  const monthly = SubscriptionService.premiumMonthly;
  const yearly = SubscriptionService.premiumYearly;
  const lifetime = SubscriptionService.premiumLifetime;

  /// Values that must never leave the device.
  const secretToken = 'SECRET-PURCHASE-TOKEN-DO-NOT-LEAK';
  const storeProse =
      'Purchase failed for user jane@example.com, card ending 4242';

  late FakeInAppPurchasePlatform fake;
  late RecordingAnalyticsFacade analytics;

  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SubscriptionService();
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    fake = FakeInAppPurchasePlatform(
      knownProductIds: const [monthly, yearly],
    );
    InAppPurchasePlatform.instance = fake;

    analytics = RecordingAnalyticsFacade();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    getIt.registerSingleton<AnalyticsFacade>(analytics);

    SubscriptionService().resetForTesting();
  });

  tearDown(() async {
    SubscriptionService().resetForTesting();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    await fake.close();
  });

  /// Initialize, and get past the restore window `initialize()` opens.
  ///
  /// `initialize()` ends with `restorePurchases()`, which leaves `_isRestoring`
  /// true until a bare 3-second `Future.delayed` fires. The window no longer
  /// affects the `source` tag (see the regression guards below), but it does
  /// drive `_restoredCount`, so tests that care about a clean starting state
  /// close it here. Letting the store reject the restore closes it
  /// synchronously instead of burning three real seconds per test.
  Future<SubscriptionService> ready() async {
    fake.restorePurchasesThrows = StateError('no restore in this test');
    await SubscriptionService.initialize();
    fake.restorePurchasesThrows = null;
    expect(SubscriptionService().isRestoring, isFalse);
    analytics.clear();
    return SubscriptionService();
  }

  /// The events that must never appear for anything short of a verified sale.
  void expectNoConversion() {
    expect(
      analytics.contains('purchase_verified'),
      isFalse,
      reason: 'purchase_verified is the conversion event; only a successful '
          'backend verification may emit it. Recorded: ${analytics.names}',
    );
    // The pre-fix event names must be gone from the wire entirely.
    expect(analytics.contains('purchase_completed'), isFalse);
    expect(analytics.contains('purchase_initiated'), isFalse);
    expect(analytics.contains('purchase_failed'), isFalse);
  }

  group('launching the billing sheet', () {
    test('buyNonConsumable() returning true is a LAUNCH, not a purchase',
        () async {
      final service = await ready();
      fake.buyNonConsumableResult = true;

      final launched = await service.purchase(monthly);

      expect(launched, isTrue);
      expect(analytics.names, ['checkout_launch_succeeded']);
      expect(analytics.one('checkout_launch_succeeded').params,
          {'product_id': monthly});
      expectNoConversion();
      expect(
        analytics.contains('store_purchase_confirmed'),
        isFalse,
        reason: 'Nothing has come back on the purchase stream yet.',
      );
    });

    test('a rejected launch reports launch_rejected', () async {
      final service = await ready();
      fake.buyNonConsumableResult = false;

      final launched = await service.purchase(monthly);

      expect(launched, isFalse);
      expect(analytics.names, ['checkout_launch_failed']);
      expect(analytics.one('checkout_launch_failed').params,
          {'product_id': monthly, 'reason': 'launch_rejected'});
      expectNoConversion();
    });

    test('an unavailable store reports store_unavailable and never calls it',
        () async {
      fake.available = false;
      await SubscriptionService.initialize();
      analytics.clear();

      final launched = await SubscriptionService().purchase(monthly);

      expect(launched, isFalse);
      expect(analytics.one('checkout_launch_failed').params['reason'],
          'store_unavailable');
      expect(fake.buyCalls, 0);
      expectNoConversion();
    });

    test('an unknown product reports product_not_found', () async {
      final service = await ready();

      // `lifetime` is deliberately absent from the fake store's catalogue.
      final launched = await service.purchase(lifetime);

      expect(launched, isFalse);
      expect(analytics.one('checkout_launch_failed').params['reason'],
          'product_not_found');
      expect(fake.buyCalls, 0);
      expectNoConversion();
    });

    test('a PlatformException is reduced to its code — never its message',
        () async {
      final service = await ready();
      fake.buyNonConsumableThrows = PlatformException(
        code: 'BILLING_UNAVAILABLE',
        message: storeProse,
        details: {'token': secretToken},
      );

      final launched = await service.purchase(monthly);

      expect(launched, isFalse);
      final event = analytics.one('checkout_launch_failed');
      expect(event.params['reason'], 'billing_unavailable');
      for (final value in analytics.allParameterValues) {
        expect(value, isNot(contains('jane@example.com')));
        expect(value, isNot(contains(secretToken)));
        expect(value, isNot(contains('4242')));
      }
    });

    test('a non-PlatformException throw is reduced to unknown', () async {
      final service = await ready();
      fake.buyNonConsumableThrows = StateError(storeProse);

      await service.purchase(monthly);

      expect(analytics.one('checkout_launch_failed').params['reason'],
          'unknown');
      for (final value in analytics.allParameterValues) {
        expect(value, isNot(contains('jane@example.com')));
      }
    });

    test('an absurdly long store code is lower-cased and clamped', () async {
      final service = await ready();
      final longCode = 'E${'X' * 300}';
      fake.buyNonConsumableThrows =
          PlatformException(code: longCode, message: storeProse);

      await service.purchase(monthly);

      final reason = analytics.one('checkout_launch_failed').params['reason']!;
      expect(reason.length, 100, reason: 'Firebase caps parameter values.');
      expect(reason, reason.toLowerCase());
      expect(reason, longCode.toLowerCase().substring(0, 100));
    });

    test('the paywall — not the service — owns checkout_started', () async {
      final service = await ready();

      await service.purchase(monthly);

      expect(
        analytics.contains('checkout_started'),
        isFalse,
        reason: 'checkout_started is the user\'s tap, emitted by the screen. '
            'Emitting it here too would double-count the funnel entry.',
      );
    });
  });

  group('purchase-stream outcomes', () {
    test('a pending purchase emits checkout_pending and no conversion',
        () async {
      await ready();

      fake.emit([
        fakePurchase(productId: monthly, status: PurchaseStatus.pending),
      ]);
      await pumpEventQueue();

      expect(analytics.names, ['checkout_pending']);
      expect(analytics.one('checkout_pending').params, {'product_id': monthly});
      expectNoConversion();
      expect(
        fake.completedPurchaseIds,
        isEmpty,
        reason: 'Completing a pending purchase throws in the plugin.',
      );
    });

    test('a cancelled purchase emits checkout_cancelled and no conversion',
        () async {
      await ready();

      fake.emit([
        fakePurchase(productId: monthly, status: PurchaseStatus.canceled),
      ]);
      await pumpEventQueue();

      expect(
        analytics.names,
        ['checkout_cancelled'],
        reason: 'Cancellation had NO branch at all before the fix — it was '
            'silently swallowed.',
      );
      expect(
        analytics.contains('verification_failed'),
        isFalse,
        reason: 'A user backing out of the sheet is not a verification error.',
      );
      expectNoConversion();
    });

    test('a cancelled purchase is only completed when the store asks',
        () async {
      await ready();

      fake.emit([
        fakePurchase(
          productId: monthly,
          purchaseId: 'cancel-no-complete',
          status: PurchaseStatus.canceled,
        ),
      ]);
      await pumpEventQueue();
      expect(fake.completedPurchaseIds, isEmpty);

      fake.emit([
        fakePurchase(
          productId: monthly,
          purchaseId: 'cancel-needs-complete',
          status: PurchaseStatus.canceled,
          pendingCompletePurchase: true,
        ),
      ]);
      await pumpEventQueue();
      expect(fake.completedPurchaseIds, ['cancel-needs-complete']);
    });

    test('a store error emits checkout_error with a coarse code only',
        () async {
      await ready();

      fake.emit([
        fakePurchase(
          productId: monthly,
          purchaseId: 'errored',
          status: PurchaseStatus.error,
          error: IAPError(
            source: 'google_play',
            code: 'PURCHASE_ERROR',
            message: storeProse,
            details: {'purchaseToken': secretToken},
          ),
        ),
      ]);
      await pumpEventQueue();

      expect(analytics.names, ['checkout_error']);
      expect(analytics.one('checkout_error').params,
          {'product_id': monthly, 'reason': 'purchase_error'});
      expectNoConversion();
      for (final value in analytics.allParameterValues) {
        expect(value, isNot(contains(secretToken)));
        expect(value, isNot(contains('jane@example.com')));
      }
      expect(fake.completedPurchaseIds, ['errored']);
    });

    test('a store error with no code falls back to unknown', () async {
      await ready();

      fake.emit([
        fakePurchase(
          productId: monthly,
          status: PurchaseStatus.error,
          error: IAPError(
            source: 'google_play',
            code: '   ',
            message: storeProse,
          ),
        ),
      ]);
      await pumpEventQueue();

      expect(analytics.one('checkout_error').params['reason'], 'unknown');
    });

    test(
        'a confirmed purchase is a store confirmation, not yet a conversion',
        () async {
      await ready();

      fake.emit([
        fakePurchase(
          productId: monthly,
          purchaseId: 'confirmed-1',
          status: PurchaseStatus.purchased,
        ),
      ]);
      await pumpEventQueue();

      expect(analytics.contains('store_purchase_confirmed'), isTrue);
      expect(analytics.one('store_purchase_confirmed').params,
          {'product_id': monthly, 'source': 'purchase'});
      // On this host no purchase token can be obtained (see the note at the
      // bottom of this file), so verification cannot even be attempted.
      expect(analytics.one('verification_failed').params,
          {'product_id': monthly, 'reason': 'no_purchase_token'});
      expectNoConversion();
    });

    test('store_purchase_confirmed precedes any verification outcome',
        () async {
      await ready();

      fake.emit([
        fakePurchase(productId: monthly, status: PurchaseStatus.purchased),
      ]);
      await pumpEventQueue();

      expect(analytics.names,
          ['store_purchase_confirmed', 'verification_failed']);
    });

    test('a restored purchase is tagged source=restore and is no conversion',
        () async {
      await ready();

      fake.emit([
        fakePurchase(
          productId: yearly,
          purchaseId: 'restored-1',
          status: PurchaseStatus.restored,
        ),
      ]);
      await pumpEventQueue();

      expect(analytics.one('store_purchase_confirmed').params,
          {'product_id': yearly, 'source': 'restore'});
      expectNoConversion();
      expect(
        fake.completedPurchaseIds,
        contains('restored-1'),
        reason: 'Restored purchases must still be completed.',
      );
    });

    test('a fresh purchase during an explicit restore is still source=purchase',
        () async {
      // REGRESSION GUARD. `_sourceFor` used to also consult `_isRestoring`, so
      // a genuine new sale that landed while a restore was in flight — the user
      // taps "Restore purchases", it finds nothing, they buy — was tagged
      // `restore` and silently dropped out of the conversion count. The store's
      // own status is the only trustworthy signal.
      final service = await ready();
      await service.restorePurchases();
      expect(service.isRestoring, isTrue,
          reason: 'The restore window must be open for this test to mean '
              'anything.');
      analytics.clear();

      fake.emit([
        fakePurchase(productId: yearly, status: PurchaseStatus.purchased),
      ]);
      await pumpEventQueue();

      expect(analytics.one('store_purchase_confirmed').params['source'],
          'purchase');
    });

    test('the startup restore window does not mislabel a fresh purchase',
        () async {
      // `initialize()` always ends with `restorePurchases()`, and `_isRestoring`
      // stays true until a bare 3-second `Future.delayed` fires — a time
      // window, not a completion signal. A real sale landing inside it must
      // still count as a sale.
      await SubscriptionService.initialize();
      expect(SubscriptionService().isRestoring, isTrue);
      analytics.clear();

      fake.emit([
        fakePurchase(productId: monthly, status: PurchaseStatus.purchased),
      ]);
      await pumpEventQueue();

      expect(analytics.one('store_purchase_confirmed').params['source'],
          'purchase');
    });

    test('status is the only input to the source tag', () async {
      // Belt-and-braces on the same regression: whatever the restore state,
      // `restored` means restore and `purchased` means purchase.
      final service = await ready();

      for (final restoring in const [false, true]) {
        if (restoring) await service.restorePurchases();
        expect(service.isRestoring, restoring);

        for (final entry in const {
          PurchaseStatus.purchased: 'purchase',
          PurchaseStatus.restored: 'restore',
        }.entries) {
          analytics.clear();
          fake.emit([fakePurchase(productId: monthly, status: entry.key)]);
          await pumpEventQueue();

          expect(
            analytics.one('store_purchase_confirmed').params['source'],
            entry.value,
            reason: '${entry.key} must tag "${entry.value}" whether or not a '
                'restore is in flight (isRestoring=$restoring).',
          );
        }
      }
    });

    test('the purchase token never reaches an analytics parameter', () async {
      await ready();

      for (final status in PurchaseStatus.values) {
        fake.emit([
          fakePurchase(
            productId: monthly,
            purchaseId: 'p-${status.name}',
            status: status,
            serverVerificationData: secretToken,
            error: status == PurchaseStatus.error
                ? IAPError(
                    source: 'google_play',
                    code: 'PURCHASE_ERROR',
                    message: '$storeProse token=$secretToken',
                  )
                : null,
          ),
        ]);
        await pumpEventQueue();
      }

      expect(analytics.events, isNotEmpty);
      for (final value in analytics.allParameterValues) {
        expect(value, isNot(contains(secretToken)));
        expect(value, isNot(contains('jane@example.com')));
      }
    });
  });

  group('source guards', () {
    final serviceSource =
        readProjectFile('lib/services/subscription_service.dart');
    final screenSource = readProjectFile('lib/screens/subscription_screen.dart');

    test('the pre-fix event names are gone from lib/ entirely', () {
      final offenders = <String>[];
      for (final entry in dartFilesUnder('lib')) {
        for (final gone in const [
          'trackPurchaseCompleted',
          'trackPurchaseInitiated',
          'trackPurchaseFailed',
          "'purchase_completed'",
          "'purchase_initiated'",
          "'purchase_failed'",
        ]) {
          if (entry.value.contains(gone)) {
            offenders.add('${entry.key}: $gone');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'purchase_completed used to fire when the billing sheet '
            'merely opened. It must not come back.',
      );
    });

    test('the paywall emits nothing but the user\'s intent', () {
      expect(screenSource, contains('trackCheckoutStarted'));
      for (final downstream in const [
        'trackPurchaseVerified',
        'trackCheckoutLaunchSucceeded',
        'trackCheckoutLaunchFailed',
        'trackStorePurchaseConfirmed',
        'trackVerificationFailed',
      ]) {
        expect(
          screenSource.contains(downstream),
          isFalse,
          reason: '$downstream must come from SubscriptionService, which keeps '
              'listening after the paywall route is gone.',
        );
      }
    });

    test('no analytics call in the service carries raw detail', () {
      // Every `_analytics?.track...` argument list must be built from the
      // closed-set codes, never from an exception, a message or a token.
      final calls = RegExp(r'_analytics\?\.\w+\((?:[^;])*?\);', dotAll: true)
          .allMatches(serviceSource)
          .map((m) => m.group(0)!)
          .toList();
      expect(calls, isNotEmpty, reason: 'The regex must still match.');

      for (final call in calls) {
        for (final forbidden in const [
          'toString()',
          'purchaseToken',
          'verificationData',
          '.message',
          '.details',
          'serverVerificationData',
        ]) {
          expect(
            call.contains(forbidden),
            isFalse,
            reason: 'Analytics call leaks "$forbidden": $call',
          );
        }
      }
    });

    test('purchase_verified is emitted only under a CONFIRMED verification',
        () {
      // The positive path cannot run on a Windows/Linux host — see the note at
      // the bottom of this file — so its guard is structural: the only call
      // site sits inside `if (result.isConfirmed)`. A provisional grant must
      // NOT reach it, or the conversion count over-reports again.
      final index = serviceSource.indexOf('trackPurchaseVerified');
      expect(index, greaterThan(0));
      expect(
        serviceSource.indexOf('trackPurchaseVerified', index + 1),
        -1,
        reason: 'There must be exactly one conversion-event call site.',
      );
      final before = serviceSource.substring(0, index);
      expect(
        before.lastIndexOf('if (result.isConfirmed) {'),
        greaterThan(before.lastIndexOf('final result = await')),
        reason: 'trackPurchaseVerified must sit inside the confirmed branch, '
            'after the awaited verifyPurchase() call.',
      );
    });

    test('a provisional grant reports itself, and never as a conversion', () {
      final index = serviceSource.indexOf('trackPurchaseProvisionallyGranted');
      expect(index, greaterThan(0),
          reason: 'A provisional grant must be observable.');
      final before = serviceSource.substring(0, index);
      expect(
        before.lastIndexOf('} else if (result.isProvisional) {'),
        greaterThan(before.lastIndexOf('if (result.isConfirmed) {')),
        reason: 'trackPurchaseProvisionallyGranted must sit in the provisional '
            'branch, which is mutually exclusive with the confirmed one.',
      );
    });

    test('verifyPurchase reports an outcome, not a bare bool', () {
      // The bool was what made purchase_verified over-count: it returned true
      // for a confirmed sale AND for a provisional grant. Pin the result type
      // so nobody collapses it back.
      final managerSource =
          readProjectFile('lib/services/subscription_manager.dart');
      expect(
        managerSource.contains(
            'Future<PurchaseVerificationResult> verifyPurchase({'),
        isTrue,
        reason: 'verifyPurchase must return PurchaseVerificationResult.',
      );
      for (final outcome in const [
        'PurchaseVerificationResult.confirmed()',
        'PurchaseVerificationResult.provisional(',
        'PurchaseVerificationResult.failed(',
      ]) {
        expect(managerSource.contains(outcome), isTrue,
            reason: 'verifyPurchase must be able to return $outcome.');
      }
    });
  });
}

// NOTE on coverage.
//
// `_handleSuccessfulPurchase` branches on `dart:io Platform.isAndroid` /
// `Platform.isIOS`, not on `defaultTargetPlatform`, so on a Windows or Linux
// host neither branch is taken: no purchase token is obtained,
// `SubscriptionManager`/`BackendAuthService`/`PremiumService` are never
// constructed, and the code always reaches the `no_purchase_token` branch.
// That is what makes these tests cheap (no ApiService, no dotenv, no
// SharedPreferences, no network) — but it also means the SUCCESSFUL
// verification path, and therefore a positive `purchase_verified` assertion,
// is unreachable from here. It is covered structurally by the source guards
// above.
//
// `SubscriptionManager.verifyPurchase()` now returns a
// `PurchaseVerificationResult`, so confirmed and provisional outcomes are
// distinguishable — the guards pin which branch each event is emitted from.
// What still blocks a behavioural test is only the `dart:io Platform` branch
// in `_handleSuccessfulPurchase`; reaching it needs a seam there (e.g. an
// injectable token extractor) plus a fake ApiService behind SubscriptionManager.
