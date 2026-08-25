import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:provider/provider.dart';

// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:pinpoint/design_system/theme.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/screens/subscription_screen.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/locale_controller.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/subscription_service.dart';

import 'support/analytics_recorder.dart';
import 'support/fake_in_app_purchase.dart';

/// THE regression test for the P0 revenue bug.
///
/// `_SubscriptionScreenState.dispose()` used to call
/// `SubscriptionService.dispose()`, which cancelled the process-wide
/// `purchaseStream` subscription. Nothing ever re-subscribed (HomeScreen guards
/// its one `initialize()` with a `static bool`), so from the moment the user
/// closed the paywall for the first time, every purchase, restore and deferred
/// payment for the rest of the session was dropped on the floor: the store
/// charged the card and the app never granted premium.
///
/// This pumps the real screen, disposes it by navigating away, reopens it,
/// disposes it again, and only then pushes a purchase onto the store stream.
/// Against the old code the listener is dead by that point and nothing is
/// handled; the assertions on `hasActivePurchaseListener`,
/// `store_purchase_confirmed` and `completePurchase` all fail.
void main() {
  late FakeInAppPurchasePlatform fake;
  late RecordingAnalyticsFacade analytics;

  setUpAll(() {
    // `SubscriptionService`'s `_iap` field initializer resolves
    // `InAppPurchase.instance`, and under `flutter test` defaultTargetPlatform
    // is forced to android — which would register the REAL Android platform
    // (opening a live BillingClient connection) and clobber any fake. Force the
    // one-time resolution to happen on a platform the plugin does not register,
    // then put the debug variable back: the test binding fails any test that
    // leaves a foundation debug variable set.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SubscriptionService();
    debugDefaultTargetPlatformOverride = null;

    // ApiService's `static final String baseUrl` reads dotenv, and constructing
    // SubscriptionManager constructs ApiService. Same workaround widget_test
    // uses.
    dotenv.loadFromString(
      envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
''',
    );
    // main.dart does this; without it google_fonts would try to fetch faces
    // over the network from inside a test.
    GoogleFonts.config.allowRuntimeFetching = false;
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

  // The exact delegate list main.dart installs. Without the material_ui spread
  // the widget test crashes: packages that have migrated to package:material_ui
  // (fleather, go_router) resolve a *different* MaterialLocalizations type that
  // flutter_localizations cannot satisfy. See material_ui_localizations_test.
  const delegates = <LocalizationsDelegate<dynamic>>[
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    ...material_ui.GlobalMaterialLocalizations.delegates,
  ];

  Widget harness(GlobalKey<NavigatorState> navKey) {
    return ChangeNotifierProvider<SubscriptionManager>.value(
      value: SubscriptionManager(),
      child: MaterialApp(
        navigatorKey: navKey,
        // The real app theme: the paywall reads PinpointTheme's ThemeExtensions
        // (glassSurface et al) and a bare ThemeData has none of them.
        theme: PinpointTheme.light(),
        darkTheme: PinpointTheme.dark(),
        localizationsDelegates: delegates,
        supportedLocales: LocaleController.supportedLocales,
        home: const _Elsewhere(),
      ),
    );
  }

  /// Fixed-duration pumps rather than pumpAndSettle: the paywall runs
  /// flutter_animate entrance animations and pumpAndSettle would be at their
  /// mercy.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
      'a purchase arriving after the paywall is opened, closed and reopened is '
      'still received and processed', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(navKey));
    await tester.pump();

    // App startup: HomeScreen's one-and-only SubscriptionService.initialize().
    await SubscriptionService.initialize();
    // restorePurchases() schedules a bare 3s Future.delayed; drain it so the
    // test does not end with a pending timer.
    await tester.pump(const Duration(seconds: 4));

    expect(SubscriptionService().purchaseListenerStarts, 1);
    expect(fake.hasListener, isTrue);

    // --- open the paywall ---
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
    );
    await settle(tester);
    expect(find.byType(SubscriptionScreen), findsOneWidget);

    // --- close it (this is what used to kill the listener) ---
    navKey.currentState!.pop();
    await settle(tester);
    expect(find.byType(SubscriptionScreen), findsNothing);

    // --- reopen it ---
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
    );
    await settle(tester);
    expect(find.byType(SubscriptionScreen), findsOneWidget);

    // --- and close it again ---
    navKey.currentState!.pop();
    await settle(tester);
    expect(find.byType(SubscriptionScreen), findsNothing);

    // The listener is app-lifetime: no route may take it down.
    expect(
      SubscriptionService().hasActivePurchaseListener,
      isTrue,
      reason: 'Closing the paywall must not cancel the app-wide purchase '
          'listener — a screen does not own a process-global singleton.',
    );
    expect(
      fake.hasListener,
      isTrue,
      reason: 'The store-side stream still has a subscriber.',
    );
    expect(
      SubscriptionService().purchaseListenerStarts,
      1,
      reason: 'Reopening the paywall must not re-subscribe either.',
    );

    // --- the store finally delivers the purchase ---
    analytics.clear();
    fake.emit([
      fakePurchase(
        productId: SubscriptionService.premiumMonthly,
        purchaseId: 'late-delivery-1',
        status: PurchaseStatus.purchased,
      ),
    ]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      analytics.names,
      contains('store_purchase_confirmed'),
      reason: 'The purchase was never handled — the listener was dead.',
    );
    expect(
      fake.completedPurchaseIds,
      contains('late-delivery-1'),
      reason: 'completePurchase() is how the store learns the entitlement was '
          'delivered; on Android an uncompleted purchase auto-refunds.',
    );
  });

  testWidgets(
      'canary: the OLD behaviour drops the very same purchase', (tester) async {
    // Proves the test above is not vacuous, without reintroducing the bug into
    // lib/. `_LegacyPaywallHost` wraps the real screen and tears the service
    // down from `State.dispose()` — which is exactly what
    // `_SubscriptionScreenState.dispose()` used to do via the now-deleted
    // `SubscriptionService.dispose()` (whose whole body was
    // `_subscription?.cancel();`). Nothing re-subscribes, matching the shipped
    // app: HomeScreen guards its single `initialize()` with a `static bool`.
    //
    // Run against the old code, the headline test above would arrive here:
    // no listener, no events, no completePurchase.
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(navKey));
    await tester.pump();

    await SubscriptionService.initialize();
    await tester.pump(const Duration(seconds: 4));
    expect(SubscriptionService().hasActivePurchaseListener, isTrue);

    // open -> close -> reopen -> close, with the old dispose() semantics
    for (var visit = 0; visit < 2; visit++) {
      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _LegacyPaywallHost()),
      );
      await settle(tester);
      navKey.currentState!.pop();
      await settle(tester);
    }

    expect(
      SubscriptionService().hasActivePurchaseListener,
      isFalse,
      reason: 'This is the bug, reproduced.',
    );

    analytics.clear();
    fake.emit([
      fakePurchase(
        productId: SubscriptionService.premiumMonthly,
        purchaseId: 'dropped-1',
        status: PurchaseStatus.purchased,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(analytics.names, isEmpty, reason: 'The user paid and got nothing.');
    expect(fake.completedPurchaseIds, isEmpty);
  });

  testWidgets('the paywall does not re-initialize the service on each visit',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(harness(navKey));
    await tester.pump();

    await SubscriptionService.initialize();
    await tester.pump(const Duration(seconds: 4));
    final restoresAfterStartup = fake.restoreCalls;

    for (var i = 0; i < 3; i++) {
      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
      );
      await settle(tester);
      navKey.currentState!.pop();
      await settle(tester);
    }

    expect(SubscriptionService().purchaseListenerStarts, 1);
    expect(
      fake.restoreCalls,
      restoresAfterStartup,
      reason: 'Opening the paywall must not trigger a restore storm; only the '
          'explicit "Restore purchases" button does that.',
    );
  });
}

class _Elsewhere extends StatelessWidget {
  const _Elsewhere();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home')));
}

/// The paywall as it used to behave: owning, and tearing down, a process-wide
/// singleton from a route's `State.dispose()`. Used only by the canary test.
class _LegacyPaywallHost extends StatefulWidget {
  const _LegacyPaywallHost();

  @override
  State<_LegacyPaywallHost> createState() => _LegacyPaywallHostState();
}

class _LegacyPaywallHostState extends State<_LegacyPaywallHost> {
  @override
  Widget build(BuildContext context) => const SubscriptionScreen();

  @override
  void dispose() {
    // Stands in for the deleted `_subscriptionService.dispose()`.
    SubscriptionService().resetForTesting();
    super.dispose();
  }
}
