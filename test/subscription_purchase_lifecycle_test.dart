import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/subscription_service.dart';

import 'support/analytics_recorder.dart';
import 'support/fake_iap_client.dart';
import 'support/project_source.dart';

/// Lifecycle contract of the app's single in-app-purchase listener.
///
/// The store can deliver a purchase, a restore or a deferred-payment
/// resolution at any moment — including long after the paywall route closed —
/// so the listener is owned by the process, created exactly once, and
/// cancelled by nothing.
///
/// Under OpenIAP there are two streams (purchases and errors) and both must be
/// attached before `initConnection()`, which makes "exactly once" harder to
/// get right, not easier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeIapClient fake;
  late RecordingAnalyticsFacade analytics;

  setUpAll(() {
    // Constructing SubscriptionManager constructs ApiService, whose
    // `static final baseUrl` reads dotenv. Nothing here talks to a server —
    // the point is that verification now runs far enough to fail honestly.
    dotenv.loadFromString(
      envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
''',
    );
  });

  setUp(() async {
    // A device id is what lets SubscriptionManager attempt a verification at
    // all. With no backend reachable the attempt fails, which is the realistic
    // "store charged, server unavailable" path: premium is granted
    // provisionally, the receipt is queued for retry, and — crucially — the
    // purchase is still acknowledged so Play does not refund it.
    SharedPreferences.setMockInitialValues(
        <String, Object>{'device_id': 'test-device'});
    await SubscriptionManager().initialize();

    fake = FakeIapClient(knownProductIds: SubscriptionService.productIds);

    analytics = RecordingAnalyticsFacade();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    getIt.registerSingleton<AnalyticsFacade>(analytics);

    SubscriptionService().resetForTesting();
    SubscriptionService().debugIapClient = fake;
  });

  tearDown(() async {
    SubscriptionService().resetForTesting();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    await fake.close();
  });

  /// Waits for a stream-delivered purchase to finish being fulfilled.
  ///
  /// The listener hands off with `unawaited`, and fulfilment now includes a
  /// real verification attempt against an unreachable backend, so the work
  /// outlives `pumpEventQueue` (which drains microtasks, not socket I/O).
  Future<void> waitFor(
    bool Function() done, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

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
            'finishTransaction is called twice.',
      );
      expect(
        fake.availablePurchaseCalls,
        1,
        reason: 'A repeated initialize() must not re-run the reconcile sweep.',
      );
      expect(
        fake.fetchProductCalls,
        2,
        reason: 'One products load: subs and in-app are separate queries.',
      );
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
      expect(fake.availablePurchaseCalls, 1);
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
      fake.emit(fakePurchase(
        productId: SubscriptionService.premiumMonthly,
        purchaseId: 'once-only',
      ));
      await waitFor(() => fake.finishedPurchaseIds.isNotEmpty);

      expect(
        analytics.all('store_purchase_confirmed'),
        hasLength(1),
        reason: 'A duplicated listener would double-handle the purchase.',
      );
      expect(fake.finishedPurchaseIds, ['once-only']);
    });

    test('an unavailable store creates no listener and stays uninitialized',
        () async {
      fake.available = false;

      await SubscriptionService.initialize();

      expect(
        SubscriptionService().isInitialized,
        isFalse,
        reason: 'The store may become available later; a retry must be able '
            'to succeed.',
      );
      expect(SubscriptionService().isAvailable, isFalse);
    });

    test('a store that refuses the connection is not fatal', () async {
      // initConnection throws PurchaseError rather than returning false when
      // billing is unavailable — an unhandled throw here would take down app
      // startup for anyone without Play Services.
      fake.initConnectionThrows =
          PurchaseError(code: ErrorCode.InitConnection, message: 'no billing');

      await SubscriptionService.initialize();

      expect(SubscriptionService().isAvailable, isFalse);
      expect(SubscriptionService().isInitialized, isFalse);
    });

    test('a retry after the store becomes available starts one listener',
        () async {
      fake.available = false;
      await SubscriptionService.initialize();
      expect(SubscriptionService().isInitialized, isFalse);

      fake.available = true;
      await SubscriptionService.initialize();

      expect(SubscriptionService().purchaseListenerStarts, 1);
      expect(SubscriptionService().isInitialized, isTrue);
    });

    test('products are fetched as subs and in-app separately', () async {
      // OpenIAP types the two kinds apart: a `subs` query will not return the
      // lifetime unlock and an `in-app` query will not return the plans, so a
      // single mixed call silently yields an empty paywall.
      await SubscriptionService.initialize();

      expect(fake.fetchedTypes,
          containsAll([ProductQueryType.Subs, ProductQueryType.InApp]));
      expect(
        SubscriptionService().products.map((p) => p.id),
        containsAll(SubscriptionService.productIds),
      );
    });
  });

  group('the listener outlives the UI', () {
    test('the exact sequence the paywall performs leaves the listener alive',
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
      fake.emit(fakePurchase(
        productId: SubscriptionService.premiumYearly,
        purchaseId: 'deferred-1',
      ));
      await waitFor(() => fake.finishedPurchaseIds.contains('deferred-1'));

      expect(analytics.names, contains('store_purchase_confirmed'));
      expect(fake.finishedPurchaseIds, contains('deferred-1'));
    });

    test('a deferred payment that resolves later is still seen', () async {
      await SubscriptionService.initialize();

      analytics.clear();
      fake.emit(fakePurchase(
        productId: SubscriptionService.premiumMonthly,
        purchaseId: 'deferred-2',
        state: PurchaseState.Pending,
      ));
      await pumpEventQueue();

      expect(analytics.names, ['checkout_pending']);
      expect(
        fake.finishedPurchaseIds,
        isEmpty,
        reason: 'Finishing a pending purchase acknowledges money that has not '
            'been taken.',
      );

      // Hours later, the parent approves.
      analytics.clear();
      fake.emit(fakePurchase(
        productId: SubscriptionService.premiumMonthly,
        purchaseId: 'deferred-2',
      ));
      await waitFor(() => fake.finishedPurchaseIds.contains('deferred-2'));

      expect(analytics.names, contains('store_purchase_confirmed'));
      expect(fake.finishedPurchaseIds, contains('deferred-2'));
    });
  });

  group('reconciling with the store', () {
    test('an owned purchase completed while the app was away is delivered',
        () async {
      // OpenIAP never re-announces this on the stream — getAvailablePurchases
      // is the only thing that surfaces it, which is why the resume hook in
      // main.dart exists.
      await SubscriptionService.initialize();

      analytics.clear();
      fake.owned = [
        fakePurchase(
          productId: SubscriptionService.premiumYearly,
          purchaseId: 'while-away',
        ),
      ];
      await SubscriptionService().reconcileStoreState();

      expect(analytics.names, contains('store_purchase_confirmed'));
      expect(fake.finishedPurchaseIds, contains('while-away'));
    });

    test('a second reconcile grants nothing twice', () async {
      // getAvailablePurchases returns every owned item every time it is
      // called, so without dedup every resume would re-verify and re-report
      // the same sale.
      await SubscriptionService.initialize();
      fake.owned = [
        fakePurchase(
          productId: SubscriptionService.premiumYearly,
          purchaseId: 'owned-1',
        ),
      ];

      await SubscriptionService().reconcileStoreState();
      analytics.clear();
      await SubscriptionService().reconcileStoreState();

      expect(
        analytics.contains('store_purchase_confirmed'),
        isFalse,
        reason: 'Already delivered; re-reporting it inflates the funnel.',
      );
    });

    test('an already-delivered purchase is still finished again', () async {
      // An acknowledgement that failed the first time would otherwise leave
      // Play to refund a purchase the user is actively using.
      await SubscriptionService.initialize();
      fake.owned = [
        fakePurchase(
          productId: SubscriptionService.premiumYearly,
          purchaseId: 'owned-2',
        ),
      ];

      await SubscriptionService().reconcileStoreState();
      await SubscriptionService().reconcileStoreState();

      expect(
        fake.finishedPurchaseIds.where((id) => id == 'owned-2'),
        hasLength(2),
      );
    });

    test('a pending purchase in the owned list grants nothing', () async {
      await SubscriptionService.initialize();

      analytics.clear();
      fake.owned = [
        fakePurchase(
          productId: SubscriptionService.premiumMonthly,
          purchaseId: 'still-pending',
          state: PurchaseState.Pending,
        ),
      ];
      await SubscriptionService().reconcileStoreState();

      expect(analytics.names, isEmpty);
      expect(fake.finishedPurchaseIds, isEmpty);
    });

    test('nothing is ever finished as a consumable', () async {
      // Consuming the lifetime unlock would put it back on sale.
      await SubscriptionService.initialize();
      fake.owned = [
        fakePurchase(
          productId: SubscriptionService.premiumLifetime,
          purchaseId: 'lifetime-1',
        ),
      ];
      await SubscriptionService().reconcileStoreState();

      expect(fake.finishedAsConsumable, everyElement(isFalse));
    });

    test('an explicit restore reports how many entitlements were found',
        () async {
      await SubscriptionService.initialize();
      fake.owned = [
        fakePurchase(
            productId: SubscriptionService.premiumYearly, purchaseId: 'r1'),
      ];

      int? restored;
      bool? failed;
      await SubscriptionService().restorePurchases(
        onComplete: (count, hasError) {
          restored = count;
          failed = hasError;
        },
      );

      // The count is real now: the old plugin re-emitted restores on the
      // stream and the service guessed at the total after a 3-second timer.
      expect(restored, 1);
      expect(failed, isFalse);
      expect(fake.restoreCalls, 1);
      expect(SubscriptionService().isRestoring, isFalse);
    });

    test('a failed restore reports the error and clears the flag', () async {
      await SubscriptionService.initialize();
      fake.restorePurchasesThrows = StateError('sync failed');

      bool? failed;
      await SubscriptionService()
          .restorePurchases(onComplete: (_, hasError) => failed = hasError);

      expect(failed, isTrue);
      expect(SubscriptionService().isRestoring, isFalse);
    });

    test('startup never syncs with the App Store', () async {
      // restorePurchases() calls AppStore.sync on iOS, which can raise an
      // Apple ID password prompt. It must only ever run when the user asks.
      await SubscriptionService.initialize();

      expect(fake.restoreCalls, 0);
      expect(fake.availablePurchaseCalls, 1);
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
      final cancelSites = RegExp(r'_(purchase|error)Subscription\??\.cancel\(\)')
          .allMatches(serviceSource)
          .length;
      expect(
        cancelSites,
        2,
        reason: 'Exactly one cancel site per stream is expected, both inside '
            'resetForTesting.',
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

    test('the old in_app_purchase plugin is gone from lib/', () {
      final offenders = <String>[];
      for (final entry in dartFilesUnder('lib')) {
        if (RegExp(r'package:in_app_purchase').hasMatch(entry.value)) {
          offenders.add(entry.key);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Play Billing 8+ is mandatory; the old plugin was pinned to a '
            'version Google no longer accepts.',
      );
    });
  });
}
