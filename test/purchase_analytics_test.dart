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

/// Truthfulness of the checkout funnel.
///
/// The old code emitted `purchase_completed` the moment the billing sheet
/// opened, before the user had paid anything and before the backend had
/// verified anything. Every abandoned checkout counted as a sale. The rule now
/// is: `purchase_verified` is the one and only conversion event, and it fires
/// only after verification succeeds.
///
/// The second rule these tests pin: analytics parameters carry coarse
/// closed-set codes, never store prose, exception strings or purchase tokens.
///
/// Since the move to OpenIAP these run deeper than they used to. The old
/// implementation branched on `dart:io Platform.isAndroid`, which is false on
/// a Windows or Linux host, so verification was unreachable and every purchase
/// ended at `no_purchase_token`. Verification is now keyed off the concrete
/// purchase type — the store's own answer — so the real path runs here: with
/// no backend reachable it lands on a provisional grant, which is exactly the
/// branch that must never be counted as a conversion.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const monthly = SubscriptionService.premiumMonthly;
  const yearly = SubscriptionService.premiumYearly;
  const lifetime = SubscriptionService.premiumLifetime;

  /// Values that must never leave the device.
  const secretToken = 'SECRET-PURCHASE-TOKEN-DO-NOT-LEAK';
  const storeProse =
      'Purchase failed for user jane@example.com, card ending 4242';

  late FakeIapClient fake;
  late RecordingAnalyticsFacade analytics;

  setUpAll(() {
    // Constructing SubscriptionManager constructs ApiService, whose
    // `static final baseUrl` reads dotenv. Nothing here talks to a server.
    dotenv.loadFromString(
      envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
''',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'device_id': 'test-device'});
    await SubscriptionManager().initialize();

    // The lifetime SKU is deliberately absent, so `product_not_found` has
    // something real to find.
    fake = FakeIapClient(knownProductIds: const [monthly, yearly]);

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

  /// Initialize and start from a clean analytics slate.
  Future<SubscriptionService> ready() async {
    await SubscriptionService.initialize();
    analytics.clear();
    return SubscriptionService();
  }

  /// Waits until the store event has been fully handled.
  ///
  /// The listener hands off with `unawaited`, and fulfilment now includes a
  /// real verification attempt, so the work outlives `pumpEventQueue` (which
  /// drains microtasks, not socket I/O). Waits for the recorder to go quiet
  /// rather than for the first event, because the interesting assertions are
  /// about the SECOND one — the verification outcome that follows the store
  /// confirmation.
  /// Pass [until] whenever the assertion depends on an event that only
  /// arrives after verification; otherwise this settles on quiescence.
  Future<void> settled({
    bool Function()? until,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var previous = -1;
    var quietTicks = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await pumpEventQueue();

      if (until != null) {
        if (until()) return;
        continue;
      }

      final count = analytics.events.length;
      if (count > 0 && count == previous) {
        if (++quietTicks >= 5) return;
      } else {
        previous = count;
        quietTicks = 0;
      }
    }
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
    test('a launched sheet is a LAUNCH, not a purchase', () async {
      final service = await ready();

      final launched = await service.purchase(monthly);

      expect(launched, isTrue);
      expect(analytics.names, ['checkout_launch_succeeded']);
      expect(analytics.one('checkout_launch_succeeded').params,
          {'product_id': monthly});
      expectNoConversion();
      expect(
        analytics.contains('store_purchase_confirmed'),
        isFalse,
        reason: 'Under OpenIAP the outcome arrives on the listeners, never as '
            'the return value of requestPurchase.',
      );
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
      expect(fake.requestedPurchases, isEmpty);
      expectNoConversion();
    });

    test('an unknown product reports product_not_found', () async {
      final service = await ready();

      final launched = await service.purchase(lifetime);

      expect(launched, isFalse);
      expect(analytics.one('checkout_launch_failed').params['reason'],
          'product_not_found');
      expect(fake.requestedPurchases, isEmpty);
      expectNoConversion();
    });

    test('a subscription with no purchasable offer reports no_offer_token',
        () async {
      // Android rejects a subscription request that carries no offer token, so
      // there is nothing to launch. Before this was caught the sheet simply
      // never appeared and the funnel recorded a successful launch.
      fake.knownProductIds = const [];
      await SubscriptionService.initialize();
      SubscriptionService().products.clear();
      SubscriptionService().products.add(
            fakeSubscriptionProduct(monthly,
                offers: [fakeOffer(id: 'base', offerToken: null)]),
          );
      analytics.clear();

      final launched = await SubscriptionService().purchase(monthly);

      expect(launched, isFalse);
      expect(analytics.one('checkout_launch_failed').params['reason'],
          'no_offer_token');
      expectNoConversion();
    });

    test('a store error is reduced to its code — never its message', () async {
      final service = await ready();
      fake.requestPurchaseThrows = PurchaseError(
        code: ErrorCode.BillingUnavailable,
        message: storeProse,
        debugMessage: secretToken,
      );

      final launched = await service.purchase(monthly);

      expect(launched, isFalse);
      final event = analytics.one('checkout_launch_failed');
      expect(event.params['reason'], 'billingunavailable');
      for (final value in analytics.allParameterValues) {
        expect(value, isNot(contains('jane@example.com')));
        expect(value, isNot(contains(secretToken)));
        expect(value, isNot(contains('4242')));
      }
    });

    test('a non-store throw is reduced to unknown', () async {
      final service = await ready();
      fake.requestPurchaseThrows = StateError(storeProse);

      await service.purchase(monthly);

      expect(
          analytics.one('checkout_launch_failed').params['reason'], 'unknown');
      for (final value in analytics.allParameterValues) {
        expect(value, isNot(contains('jane@example.com')));
      }
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

    test('the request carries the offer token Play requires', () async {
      final service = await ready();

      await service.purchase(monthly);

      final props = fake.requestedPurchases.single.toJson();
      final google = (props['requestSubscription']
          as Map<String, dynamic>)['google'] as Map<String, dynamic>;
      expect(props['type'], ProductQueryType.Subs.toJson());
      expect(google['subscriptionOffers'], isNotEmpty);
    });

    test('the lifetime unlock is requested as a one-time product', () async {
      // Requesting it as a subscription is a developer error on the native
      // side, and `subs` and `in-app` are separate queries besides.
      fake.knownProductIds = const [lifetime];
      final service = await ready();

      await service.purchase(lifetime);

      final props = fake.requestedPurchases.single.toJson();
      expect(props['type'], ProductQueryType.InApp.toJson());
      expect(props.containsKey('requestPurchase'), isTrue);
    });
  });

  group('purchase-stream outcomes', () {
    test('a pending purchase emits checkout_pending and no conversion',
        () async {
      await ready();

      fake.emit(fakePurchase(productId: monthly, state: PurchaseState.Pending));
      await settled();

      expect(analytics.names, ['checkout_pending']);
      expect(analytics.one('checkout_pending').params, {'product_id': monthly});
      expectNoConversion();
      expect(
        fake.finishedPurchaseIds,
        isEmpty,
        reason: 'Finishing a pending purchase acknowledges money that has not '
            'been taken yet.',
      );
    });

    test('a cancelled purchase emits checkout_cancelled and no conversion',
        () async {
      await ready();

      // Cancellation arrives on the error stream under OpenIAP, with its own
      // error code rather than a purchase status.
      fake.emitError(fakePurchaseError(
        code: ErrorCode.UserCancelled,
        productId: monthly,
        message: storeProse,
      ));
      await settled();

      expect(analytics.names, ['checkout_cancelled']);
      expect(
        analytics.contains('checkout_error'),
        isFalse,
        reason: 'A user backing out of the sheet is an ordinary outcome, not '
            'an error — reporting it as one makes the funnel look broken.',
      );
      expect(analytics.contains('verification_failed'), isFalse);
      expectNoConversion();
    });

    test('a store error emits checkout_error with a coarse code only',
        () async {
      await ready();

      fake.emitError(fakePurchaseError(
        code: ErrorCode.ServiceError,
        productId: monthly,
        message: '$storeProse token=$secretToken',
      ));
      await settled();

      expect(analytics.names, ['checkout_error']);
      expect(analytics.one('checkout_error').params,
          {'product_id': monthly, 'reason': 'serviceerror'});
      expectNoConversion();
      for (final value in analytics.allParameterValues) {
        expect(value, isNot(contains(secretToken)));
        expect(value, isNot(contains('jane@example.com')));
      }
    });

    test('a store error with no code falls back to unknown', () async {
      await ready();

      // PurchaseError.code is nullable in the shipped plugin.
      fake.emitError(
          fakePurchaseError(code: null, productId: monthly, message: storeProse));
      await settled();

      expect(analytics.one('checkout_error').params['reason'], 'unknown');
    });

    test('a confirmed purchase is a store confirmation, not yet a conversion',
        () async {
      await ready();

      fake.emit(fakePurchase(productId: monthly, purchaseId: 'confirmed-1'));
      await settled();

      expect(analytics.contains('store_purchase_confirmed'), isTrue);
      expect(analytics.one('store_purchase_confirmed').params,
          {'product_id': monthly, 'source': 'purchase'});
      expectNoConversion();
    });

    test('store_purchase_confirmed precedes any verification outcome',
        () async {
      await ready();

      fake.emit(fakePurchase(productId: monthly));
      await settled(until: () => analytics.names.length >= 2);

      expect(analytics.names.first, 'store_purchase_confirmed');
      expect(analytics.names, hasLength(2));
    });

    test('an unverifiable purchase is a provisional grant, not a conversion',
        () async {
      // The store charged the user; the backend is unreachable. Premium is
      // unlocked locally and the receipt is queued for retry — but this is NOT
      // a sale anyone may count.
      await ready();

      fake.emit(fakePurchase(productId: monthly, purchaseId: 'provisional-1'));
      await settled(
          until: () => analytics.contains('purchase_provisionally_granted'));

      expect(analytics.contains('purchase_provisionally_granted'), isTrue);
      expect(
        analytics.one('purchase_provisionally_granted').params['reason'],
        'backend_unreachable',
      );
      expectNoConversion();
      expect(
        fake.finishedPurchaseIds,
        contains('provisional-1'),
        reason: 'Play refunds anything unacknowledged after three days, and '
            'the user has actually paid.',
      );
    });

    test('a purchase with no token is never acknowledged', () async {
      // Nothing can be verified, so nothing is granted. Leaving it
      // unacknowledged is what gets the user their money back.
      await ready();

      fake.emit(fakePurchase(
          productId: monthly, purchaseId: 'tokenless', purchaseToken: null));
      await settled(until: () => analytics.contains('verification_failed'));

      expect(analytics.one('verification_failed').params,
          {'product_id': monthly, 'reason': 'no_purchase_token'});
      expect(fake.finishedPurchaseIds, isEmpty);
      expectNoConversion();
    });

    test('an owned purchase found by a restore is tagged source=restore',
        () async {
      await ready();
      fake.owned = [fakePurchase(productId: yearly, purchaseId: 'restored-1')];

      await SubscriptionService().restorePurchases();

      expect(analytics.one('store_purchase_confirmed').params,
          {'product_id': yearly, 'source': 'restore'});
      expectNoConversion();
      expect(
        fake.finishedPurchaseIds,
        contains('restored-1'),
        reason: 'Restored purchases must still be acknowledged.',
      );
    });

    test('a fresh purchase during an explicit restore is still source=purchase',
        () async {
      // REGRESSION GUARD. The source tag used to be derived from whether a
      // restore was in flight, so a genuine new sale that landed during one —
      // the user taps "Restore purchases", it finds nothing, they buy — was
      // tagged `restore` and silently dropped out of the conversion count.
      // The source is now a property of how the purchase reached us, not of
      // what else is happening at the time.
      final service = await ready();
      final restore = service.restorePurchases();

      fake.emit(fakePurchase(productId: yearly, purchaseId: 'fresh-1'));
      await settled();
      await restore;

      expect(
        analytics.all('store_purchase_confirmed').first.params['source'],
        'purchase',
      );
    });

    test('the purchase token never reaches an analytics parameter', () async {
      await ready();

      for (final state in PurchaseState.values) {
        fake.emit(fakePurchase(
          productId: monthly,
          purchaseId: 'p-${state.name}',
          state: state,
          purchaseToken: secretToken,
        ));
        await settled();
        analytics.clear();
      }
      fake.emitError(fakePurchaseError(
        productId: monthly,
        message: '$storeProse token=$secretToken',
      ));
      await settled();

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
          '.debugMessage',
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
        managerSource
            .contains('Future<PurchaseVerificationResult> verifyPurchase({'),
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

    test('the entitlement refresh cannot block acknowledgement', () {
      // Play refunds anything unacknowledged after three days, so an offline
      // status refresh must not be able to skip finishTransaction.
      final refresh = serviceSource.indexOf('checkSubscriptionStatus');
      expect(refresh, greaterThan(0));
      final guard = serviceSource.lastIndexOf('try {', refresh);
      final grant = serviceSource.lastIndexOf('if (result.grantsEntitlement)');
      expect(
        guard,
        greaterThan(grant),
        reason: 'The post-grant refresh must sit inside its own try/catch.',
      );
    });
  });
}
