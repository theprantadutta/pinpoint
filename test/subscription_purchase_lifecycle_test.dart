import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/subscription_service.dart';

import 'support/analytics_recorder.dart';
import 'support/fake_in_app_purchase.dart';
import 'support/project_source.dart';

/// Lifecycle contract of the app's single in-app-purchase stream listener.
///
/// The store can deliver a purchase, a restore or a deferred-payment
/// resolution at any moment — including long after the paywall route closed —
/// so the listener is owned by the process, created exactly once, and cancelled
/// by nothing.
void main() {
  late FakeInAppPurchasePlatform fake;
  late RecordingAnalyticsFacade analytics;

  setUpAll(() {
    // See FakeInAppPurchasePlatform's doc comment: resolve
    // `InAppPurchase.instance` once on a platform the plugin does not register
    // for, so the real Android BillingClient is never constructed.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SubscriptionService();
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    fake = FakeInAppPurchasePlatform(
      knownProductIds: SubscriptionService.productIds,
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

  group('initialize() idempotency', () {
    test('a single initialize() starts exactly one listener', () async {
      await SubscriptionService.initialize();

      expect(SubscriptionService().purchaseListenerStarts, 1);
      expect(SubscriptionService().hasActivePurchaseListener, isTrue);
      expect(SubscriptionService().isInitialized, isTrue);
      expect(fake.hasListener, isTrue);
    });

    test('calling initialize() twice in sequence starts exactly one listener',
        () async {
      await SubscriptionService.initialize();
      await SubscriptionService.initialize();
      await SubscriptionService.initialize();

      expect(
        SubscriptionService().purchaseListenerStarts,
        1,
        reason: 'Two listeners means every purchase is verified twice and '
            'completePurchase is called twice.',
      );
      expect(
        fake.restoreCalls,
        1,
        reason: 'A repeated initialize() must not re-run the restore storm.',
      );
      expect(fake.queryProductCalls, 1);
    });

    test('two concurrent initialize() calls share one initialization',
        () async {
      // Both callers must await the SAME in-flight work; a naive guard that
      // only sets a flag at the end lets both race past it into two listeners.
      await Future.wait<void>([
        SubscriptionService.initialize(),
        SubscriptionService.initialize(),
      ]);

      expect(SubscriptionService().purchaseListenerStarts, 1);
      expect(fake.restoreCalls, 1);
    });

    test('four concurrent initialize() calls still start one listener',
        () async {
      await Future.wait<void>([
        for (var i = 0; i < 4; i++) SubscriptionService.initialize(),
      ]);

      expect(SubscriptionService().purchaseListenerStarts, 1);
      expect(fake.hasListener, isTrue);
    });

    test(
        'exactly one purchase-stream event is handled after repeated '
        'initialize()', () async {
      await SubscriptionService.initialize();
      await SubscriptionService.initialize();

      analytics.clear();
      fake.emit([
        fakePurchase(
          productId: SubscriptionService.premiumMonthly,
          purchaseId: 'once-only',
          status: PurchaseStatus.purchased,
        ),
      ]);
      await pumpEventQueue();

      expect(
        analytics.all('store_purchase_confirmed'),
        hasLength(1),
        reason: 'A duplicated listener would double-handle the purchase.',
      );
      expect(fake.completedPurchaseIds, ['once-only']);
    });

    test('an unavailable store creates no listener and stays uninitialized',
        () async {
      fake.available = false;

      await SubscriptionService.initialize();

      expect(SubscriptionService().purchaseListenerStarts, 0);
      expect(SubscriptionService().hasActivePurchaseListener, isFalse);
      expect(
        SubscriptionService().isInitialized,
        isFalse,
        reason: 'The store may become available later; a retry must be able '
            'to succeed. Nothing was subscribed, so nothing can duplicate.',
      );
    });

    test('a retry after the store becomes available starts one listener',
        () async {
      fake.available = false;
      await SubscriptionService.initialize();
      expect(SubscriptionService().purchaseListenerStarts, 0);

      fake.available = true;
      await SubscriptionService.initialize();

      expect(SubscriptionService().purchaseListenerStarts, 1);
      expect(SubscriptionService().isInitialized, isTrue);
    });
  });

  group('the listener outlives the UI', () {
    test(
        'the exact sequence the paywall performs leaves the listener alive',
        () async {
      await SubscriptionService.initialize();

      // What _SubscriptionScreenState does across its whole lifetime:
      // didChangeDependencies() grabs the singleton and loads products (it can
      // run more than once per State), the user restores, and then the route
      // closes. None of it may touch the subscription.
      for (var visit = 0; visit < 3; visit++) {
        final service = SubscriptionService(); // didChangeDependencies
        await service.loadProducts();
        await service.loadProducts(); // inherited-widget change re-runs it
        // ...State.dispose() — which now does nothing to the service at all.
      }

      expect(SubscriptionService().hasActivePurchaseListener, isTrue);
      expect(SubscriptionService().purchaseListenerStarts, 1);
      expect(fake.hasListener, isTrue);
    });

    test('a purchase delivered long after the paywall closed is processed',
        () async {
      await SubscriptionService.initialize();
      final service = SubscriptionService();
      await service.loadProducts();
      // Paywall closed here.

      analytics.clear();
      fake.emit([
        fakePurchase(
          productId: SubscriptionService.premiumYearly,
          purchaseId: 'deferred-1',
          status: PurchaseStatus.purchased,
        ),
      ]);
      await pumpEventQueue();

      expect(analytics.names, contains('store_purchase_confirmed'));
      expect(fake.completedPurchaseIds, contains('deferred-1'));
    });

    test('a deferred payment that resolves later is still seen', () async {
      await SubscriptionService.initialize();
      final purchase = fakePurchase(
        productId: SubscriptionService.premiumMonthly,
        purchaseId: 'deferred-2',
        status: PurchaseStatus.pending,
      );

      analytics.clear();
      fake.emit([purchase]);
      await pumpEventQueue();
      expect(analytics.names, ['checkout_pending']);

      // Hours later, the parent approves.
      purchase.status = PurchaseStatus.purchased;
      analytics.clear();
      fake.emit([purchase]);
      await pumpEventQueue();

      expect(analytics.names, contains('store_purchase_confirmed'));
      expect(fake.completedPurchaseIds, contains('deferred-2'));
    });
  });

  group('API surface', () {
    // A source guard, because the regression was a *callable member*: as long
    // as SubscriptionService offers a public teardown, some widget will
    // eventually call it from State.dispose() again. These read the shipped
    // source so they fail against the old code without needing to run it.
    final serviceSource =
        readProjectFile('lib/services/subscription_service.dart');
    final screenSource = readProjectFile('lib/screens/subscription_screen.dart');

    test('SubscriptionService exposes no public way to cancel the listener',
        () {
      expect(
        RegExp(r'^\s*(void|Future<void>)\s+dispose\s*\(', multiLine: true)
            .hasMatch(serviceSource),
        isFalse,
        reason: 'A public dispose() on a process-global singleton is what let '
            'the paywall kill the app-wide purchase listener.',
      );
      // The only member allowed to cancel is the test-only reset hook.
      final cancelSites = RegExp(r'_subscription\??\.cancel\(\)')
          .allMatches(serviceSource)
          .length;
      expect(
        cancelSites,
        1,
        reason: 'Exactly one cancel site is expected, inside resetForTesting.',
      );
      expect(
        serviceSource,
        contains('@visibleForTesting'),
        reason: 'resetForTesting must stay marked test-only.',
      );
    });

    test('the paywall does not tear down the subscription service', () {
      expect(
        screenSource.contains('_subscriptionService.dispose()'),
        isFalse,
        reason: 'THE P0 revenue bug: closing the paywall cancelled the '
            'app-wide purchase listener for the rest of the session.',
      );
      expect(
        RegExp(r'SubscriptionService\(\)\.dispose\(\)').hasMatch(screenSource),
        isFalse,
      );
      expect(
        screenSource.contains('resetForTesting'),
        isFalse,
        reason: 'The test-only reset hook must never be called from UI.',
      );
    });

    test('nothing in lib/ calls a teardown on SubscriptionService', () {
      final offenders = <String>[];
      for (final entry in dartFilesUnder('lib')) {
        final source = entry.value;
        if (!source.contains('SubscriptionService')) continue;
        if (RegExp(r'[sS]ubscriptionService(\(\))?\.dispose\(\)')
                .hasMatch(source) ||
            source.contains('subscriptionService.resetForTesting')) {
          offenders.add(entry.key);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
