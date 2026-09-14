import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/backend_auth_service.dart';
import 'package:pinpoint/services/logger_service.dart';
import 'package:pinpoint/services/premium_service.dart';
import 'package:pinpoint/services/purchases/iap_client.dart';
import 'package:pinpoint/services/purchases/purchase_mapping.dart';
import 'package:pinpoint/services/subscription_manager.dart';

/// Raised when an Android subscription carries no purchasable offer.
///
/// Google rejects a subscription purchase submitted without an offer token, so
/// there is nothing to launch; this is reported as a launch failure rather
/// than thrown at the caller.
class _MissingOfferException implements Exception {
  const _MissingOfferException();
}

/// Owns the app's single, app-lifetime in-app-purchase listeners.
///
/// Runs on OpenIAP (`flutter_inapp_purchase`), which is Play Billing 9.1 on
/// Android and StoreKit 2 on iOS. Three consequences of that shape drive the
/// code below, and none of them applied to the old `in_app_purchase` plugin:
///
///   * outcomes arrive on TWO streams — purchases on one, failures and
///     cancellations on the other — and both must be attached before
///     `initConnection()`, or the first events of a fast purchase are lost;
///   * a restore no longer re-emits anything on the stream. Owned items are
///     read back with `getAvailablePurchases()`, which returns EVERY entitled
///     item every time it is called;
///   * because of that, delivery has to be deduplicated explicitly. The
///     billing sheet closing is itself an app resume, so the stream event and
///     the resume sweep routinely see the same fresh purchase within a second.
///
/// Testing: the plugin singleton has no public setter, so [IapClient] is the
/// seam — assign [debugIapClient] before touching this singleton, and call
/// [resetForTesting] between cases because this is process-global.
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  IapClient _client = LiveIapClient();

  /// Swap in a fake store. TESTS ONLY.
  @visibleForTesting
  set debugIapClient(IapClient client) => _client = client;

  // Product IDs (must match Google Play Console / App Store Connect)
  static const String premiumMonthly = 'pinpoint_premium_monthly';
  static const String premiumYearly = 'pinpoint_premium_yearly';
  static const String premiumLifetime = 'pinpoint_premium_lifetime';

  /// Recurring plans, queried as `subs`.
  static const List<String> subscriptionIds = [premiumMonthly, premiumYearly];

  /// One-time entitlements, queried as `in-app`. OpenIAP needs the two kinds
  /// fetched separately; a single mixed query returns neither.
  static const List<String> oneTimeIds = [premiumLifetime];

  static const List<String> productIds = [
    premiumMonthly,
    premiumYearly,
    premiumLifetime,
  ];

  /// Identities of purchases already delivered, so a re-sighting grants
  /// nothing twice and emits no second conversion event.
  static const String _deliveredKey = 'iap_delivered_purchase_ids';

  /// Enough to cover every entitlement a user can hold several times over,
  /// while keeping the persisted blob small.
  static const int _maxDeliveredIds = 100;

  List<ProductCommon> _products = [];
  List<ProductCommon> get products => _products;
  bool get hasProducts => _products.isNotEmpty;

  /// The two and only store subscriptions.
  ///
  /// These are APP-LIFETIME. The store delivers purchases, restores and
  /// deferred-payment resolutions at any moment — including long after the
  /// paywall route has closed — so they must never be cancelled by UI. There
  /// is deliberately no public `dispose()`; see [resetForTesting].
  StreamSubscription<Purchase>? _purchaseSubscription;
  StreamSubscription<PurchaseError>? _errorSubscription;
  int _purchaseListenerStarts = 0;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  // Idempotency guards. [_initialized] answers "has initialization already
  // succeeded"; [_initializing] lets concurrent callers await the SAME work
  // instead of racing into a second listener and a second reconcile storm.
  bool _initialized = false;
  Future<void>? _initializing;

  /// Whether initialization has completed successfully at least once.
  bool get isInitialized => _initialized;

  /// Whether a purchase-stream listener is currently attached.
  bool get hasActivePurchaseListener => _purchaseSubscription != null;

  /// How many purchase-stream listeners have been created in this process.
  /// Must never exceed 1 — anything higher means every purchase event is being
  /// handled (and verified, and finished) more than once.
  int get purchaseListenerStarts => _purchaseListenerStarts;

  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;

  /// Identities currently being verified, so the stream event and the resume
  /// sweep cannot both fulfil the same purchase. Without this the backend gets
  /// two concurrent verifications of one receipt.
  final Set<String> _fulfilling = <String>{};

  /// Identities already delivered, loaded once from disk.
  Set<String>? _delivered;

  /// Analytics sink, or null when the locator has not been initialized (tests).
  AnalyticsFacade? get _analytics =>
      getIt.isRegistered<AnalyticsFacade>() ? getIt<AnalyticsFacade>() : null;

  /// Static initialize method for use at app startup.
  ///
  /// Safe to call repeatedly: the second and later calls are no-ops (or await
  /// the in-flight first call). Callers who want a genuinely fresh restore
  /// should call [restorePurchases] directly instead.
  static Future<void> initialize() => _instance._initialize();

  /// Initialize subscription service (idempotent + concurrency-safe).
  Future<void> _initialize() {
    if (_initialized) return Future.value();
    // `??=` only evaluates the right-hand side when nothing is in flight, so
    // two concurrent callers share one _runInitialize().
    return _initializing ??=
        _runInitialize().whenComplete(() => _initializing = null);
  }

  Future<void> _runInitialize() async {
    // Listeners FIRST. `initConnection()` can deliver an unfinished purchase
    // from a previous session the moment it completes, and OpenIAP drops
    // events that arrive with nothing attached.
    _attachListeners();

    try {
      _isAvailable = await _client.initConnection();
    } on PurchaseError catch (error) {
      _isAvailable = false;
      log.w('In-app purchases unavailable: ${reasonCodeFor(error.code)}');
    } catch (e) {
      _isAvailable = false;
      log.e('Store connection failed: $e');
    }

    if (!_isAvailable) {
      // Leave _initialized false: the store may become available later, and a
      // retry must be able to run the rest of this.
      log.w('In-app purchases not available');
      return;
    }

    await loadProducts();

    _initialized = true;

    // Pick up anything owned but not yet delivered — a purchase completed
    // while the app was closed, or a deferred payment that has since cleared.
    // Deliberately NOT restorePurchases(): that syncs with the App Store and
    // can prompt for an Apple ID password, which must only ever happen when
    // the user explicitly asks to restore.
    await reconcileStoreState();
  }

  void _attachListeners() {
    if (_purchaseSubscription != null) return;

    _purchaseListenerStarts++;
    _purchaseSubscription = _client.purchaseUpdated.listen(
      (purchase) => unawaited(_onPurchaseUpdated(purchase)),
      onError: (Object error) => log.e('Purchase stream error: $error'),
    );
    _errorSubscription = _client.purchaseError.listen(
      _onPurchaseError,
      onError: (Object error) => log.e('Purchase error stream failed: $error'),
    );
  }

  /// Load subscription and one-time products from the active store.
  ///
  /// Two queries, because OpenIAP types them separately: `subs` will not
  /// return the lifetime unlock and `in-app` will not return the plans.
  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    try {
      final subscriptions = await _client.fetchProducts<ProductSubscription>(
        skus: subscriptionIds,
        type: ProductQueryType.Subs,
      );
      final oneTime = await _client.fetchProducts<Product>(
        skus: oneTimeIds,
        type: ProductQueryType.InApp,
      );

      _products = <ProductCommon>[...subscriptions, ...oneTime];
      log.i('Loaded ${_products.length}/${productIds.length} products: '
          '${_products.map((p) => p.id).toList()}');

      // A missing id is the #1 symptom of a store-config mismatch: the product
      // doesn't exist / isn't Approved / bundle-id mismatch (iOS) or isn't
      // active (Android). Surface it instead of a silently empty paywall.
      final found = _products.map((p) => p.id).toSet();
      final missing = productIds.where((id) => !found.contains(id)).toList();
      if (missing.isNotEmpty) {
        log.w('⚠️ Products NOT found in store (check IDs/approval/status): '
            '$missing');
      }
    } catch (e) {
      log.e('Error loading products: $e');
    }
  }

  /// Get product by ID
  ProductCommon? getProduct(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  /// Launch the store's billing sheet for [productId].
  ///
  /// The returned bool only says whether the sheet was LAUNCHED — under
  /// OpenIAP the purchase outcome arrives on the listeners and never as a
  /// return value. The launch-stage analytics are emitted here rather than
  /// from the paywall because this is the only place that can tell the failure
  /// modes apart.
  Future<bool> purchase(String productId) async {
    if (!_isAvailable) {
      log.e('In-app purchases not available');
      _analytics?.trackCheckoutLaunchFailed(
          productId: productId, reason: PurchaseReasonCodes.storeUnavailable);
      return false;
    }

    final product = getProduct(productId);
    if (product == null) {
      log.e('Product not found: $productId');
      _analytics?.trackCheckoutLaunchFailed(
          productId: productId, reason: PurchaseReasonCodes.productNotFound);
      return false;
    }

    try {
      await _client.requestPurchase(_buildRequest(product));
      _analytics?.trackCheckoutLaunchSucceeded(productId: productId);
      return true;
    } on _MissingOfferException {
      // Play Console has the subscription but no offer this user can buy.
      log.e('No purchasable offer for $productId');
      _analytics?.trackCheckoutLaunchFailed(
          productId: productId, reason: PurchaseReasonCodes.noOfferToken);
      return false;
    } catch (e) {
      // Raw detail stays on-device; analytics gets a coarse code only.
      log.e('Purchase error: $e');
      _analytics?.trackCheckoutLaunchFailed(
          productId: productId, reason: _coarseCodeForException(e));
      return false;
    }
  }

  /// Builds the platform-specific purchase request.
  ///
  /// Both platform slots are always filled where possible; the native side
  /// reads only its own. Which slot is populated is decided by the concrete
  /// product type — the store's own answer — rather than by `Platform.isX`,
  /// so the shape stays verifiable off-device.
  RequestPurchaseProps _buildRequest(ProductCommon product) {
    final accountId = _accountId();

    if (isOneTimeProduct(product.id)) {
      return RequestPurchaseProps.inApp((
        apple: RequestPurchaseIosProps(
          sku: product.id,
          appAccountToken: _appleAccountToken(accountId),
        ),
        google: RequestPurchaseAndroidProps(
          skus: [product.id],
          obfuscatedAccountId: accountId,
        ),
      ));
    }

    RequestSubscriptionAndroidProps? google;
    if (product is ProductSubscriptionAndroid) {
      // Android rejects a subscription purchase with no offer token, so this
      // is fatal to the launch rather than something to submit and hope about.
      final offer = selectAndroidOffer(product.subscriptionOffers);
      final token = offer?.offerTokenAndroid;
      if (token == null || token.isEmpty) throw const _MissingOfferException();

      google = RequestSubscriptionAndroidProps(
        skus: [product.id],
        subscriptionOffers: [
          AndroidSubscriptionOfferInput(sku: product.id, offerToken: token),
        ],
        obfuscatedAccountId: accountId,
      );
    }

    return RequestPurchaseProps.subs((
      apple: RequestSubscriptionIosProps(
        sku: product.id,
        appAccountToken: _appleAccountToken(accountId),
      ),
      google: google,
    ));
  }

  /// The signed-in user's backend id, tagged onto the purchase so a deferred
  /// payment that resolves days later can still be attributed to the account.
  /// Null when signed out — a device-only purchase is still fully supported.
  String? _accountId() {
    final auth = BackendAuthService();
    return auth.isAuthenticated ? auth.userId : null;
  }

  /// Apple *throws* on an `appAccountToken` that is not a UUID (it would
  /// otherwise be silently dropped), so anything else is omitted. Android's
  /// `obfuscatedAccountId` accepts any string and needs no such guard.
  static String? _appleAccountToken(String? accountId) {
    if (accountId == null) return null;
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(accountId);
    return isUuid ? accountId : null;
  }

  /// Maps a thrown store error to a short, bounded code. Never returns free
  /// text: a [PurchaseError]'s message can carry Play's debugMessage or an iOS
  /// `NSError.userInfo`, neither of which may leave the device.
  String _coarseCodeForException(Object error) {
    if (error is PurchaseError) return reasonCodeFor(error.code);
    return PurchaseReasonCodes.unknown;
  }

  /// Restore previous purchases, on the user's explicit request.
  ///
  /// On iOS this syncs with the App Store, which may prompt for an Apple ID
  /// password — so it must never run unprompted. Nothing is re-emitted on the
  /// purchase stream any more; the owned items come back from
  /// `getAvailablePurchases()` and are fulfilled here.
  ///
  /// [onComplete] receives the number of owned entitlements found.
  Future<void> restorePurchases({
    Function(int restoredCount, bool hasError)? onComplete,
  }) async {
    if (!_isAvailable) {
      onComplete?.call(0, true);
      return;
    }

    _isRestoring = true;
    try {
      await _client.restorePurchases();
      final restored = await _processOwnedPurchases(source: 'restore');
      _isRestoring = false;
      log.i('Restore completed: $restored purchases restored');
      onComplete?.call(restored, false);
    } catch (e) {
      _isRestoring = false;
      log.e('Restore error: $e');
      onComplete?.call(0, true);
    }
  }

  /// Fulfil anything the store says is owned but the app has not delivered.
  ///
  /// Safe and cheap to call on every app resume and once after sign-in, which
  /// is what closes the gap left by a purchase completing while the app was
  /// backgrounded, killed, or offline. Unlike [restorePurchases] this never
  /// syncs with the App Store, so it cannot raise a password prompt.
  Future<int> reconcileStoreState() async {
    if (!_isAvailable) return 0;
    try {
      return await _processOwnedPurchases(source: 'restore');
    } catch (e) {
      log.e('Store reconcile failed: $e');
      return 0;
    }
  }

  Future<int> _processOwnedPurchases({required String source}) async {
    final owned = await _client.getAvailablePurchases();
    var count = 0;
    for (final purchase in owned) {
      if (purchase.purchaseState != PurchaseState.Purchased) continue;
      count++;
      await _fulfil(purchase, source: source);
    }
    return count;
  }

  /// Handle one store purchase event.
  ///
  /// Every stream-sourced analytics event is emitted from here, never from the
  /// paywall — the store can deliver an outcome minutes after the paywall
  /// route closed, and this listener outlives it.
  Future<void> _onPurchaseUpdated(Purchase purchase) async {
    log.i('Purchase update: ${purchase.productId} - ${purchase.purchaseState}');

    switch (purchase.purchaseState) {
      case PurchaseState.Pending:
        // Deferred payment, parental approval, cash-at-counter. Grant nothing
        // and finish nothing: finishing a pending purchase acknowledges money
        // that has not been taken, and it arrives again once it clears.
        log.i('Purchase pending: ${purchase.productId}');
        _analytics?.trackCheckoutPending(productId: purchase.productId);

      case PurchaseState.Purchased:
        await _fulfil(purchase, source: 'purchase');

      case PurchaseState.Unknown:
        log.w('Purchase in unknown state: ${purchase.productId}');
        _analytics?.trackCheckoutError(
            productId: purchase.productId,
            reason: PurchaseReasonCodes.unknown);
    }
  }

  /// Handle a failure from the store.
  ///
  /// Cancellation is an ordinary outcome, not an error: the user dismissed the
  /// billing sheet. Reporting it as an error made the funnel look broken.
  void _onPurchaseError(PurchaseError error) {
    final productId = error.productId ?? '';

    if (isUserCancellation(error.code)) {
      log.i('Purchase cancelled: $productId');
      _analytics?.trackCheckoutCancelled(productId: productId);
      return;
    }

    // error.message / debugMessage can carry store prose — log it locally, but
    // send only the enum name onwards.
    log.e('Purchase error (${reasonCodeFor(error.code)}): ${error.message}');
    _analytics?.trackCheckoutError(
        productId: productId, reason: reasonCodeFor(error.code));
  }

  /// Verify, deliver and finish one purchased item.
  ///
  /// [source] is `'purchase'` for a new sale and `'restore'` for something the
  /// user already owned, keeping restores out of the conversion count. It is
  /// passed in rather than derived, because OpenIAP has no "restored" state to
  /// read: an owned item looks identical however it reached us.
  Future<void> _fulfil(Purchase purchase, {required String source}) async {
    final identity = purchaseIdentity(purchase);

    // The billing sheet closing IS an app resume, so the stream event and the
    // resume sweep see the same purchase within a second of each other.
    if (identity != null && !_fulfilling.add(identity)) return;

    try {
      final delivered = await _deliveredIds();
      if (identity != null && delivered.contains(identity)) {
        // Already granted in an earlier session. Finish again anyway: an
        // acknowledgement that failed last time would otherwise have Play
        // refund a purchase the user is still using.
        await _finish(purchase);
        return;
      }

      _analytics?.trackStorePurchaseConfirmed(
          productId: purchase.productId, source: source);

      final payload = backendPayloadFor(purchase);
      if (payload == null) {
        // No token means verification could not even be attempted. Do NOT
        // finish: on Android that would acknowledge an unverifiable purchase.
        log.e('❌ Purchase carries no token: ${purchase.productId}');
        _analytics?.trackVerificationFailed(
            productId: purchase.productId,
            reason: PurchaseReasonCodes.noPurchaseToken);
        return;
      }

      final result = await _verify(payload, source: source);

      if (!result.grantsEntitlement) {
        // The backend actively rejected it. Deliver nothing. On Android leave
        // it unacknowledged so Play refunds the user within three days; on iOS
        // finish it, or StoreKit replays it on every launch forever.
        if (purchase is PurchaseIOS) await _finish(purchase);
        return;
      }

      if (identity != null) await _markDelivered(identity);
      await _finish(purchase);
    } catch (e, stackTrace) {
      log.e('❌ Error handling purchase: $e');
      log.e('Stack trace: $stackTrace');
    } finally {
      if (identity != null) _fulfilling.remove(identity);
    }
  }

  Future<PurchaseVerificationResult> _verify(
    BackendPurchasePayload payload, {
    required String source,
  }) async {
    final subscriptionManager = SubscriptionManager();

    // Signed in, so the entitlement can follow the account onto a new device.
    // A signed-out purchase is still verified and still works — it is keyed to
    // the device id instead.
    final userId = _accountId();

    final result = await subscriptionManager.verifyPurchase(
      purchaseToken: payload.purchaseToken,
      productId: payload.productId,
      userId: userId,
      platform: payload.platform,
    );

    if (result.isConfirmed) {
      log.i('✅ Purchase verified: ${payload.productId}');

      // The single conversion event. It fires only for a backend-confirmed
      // purchase: a provisional grant reports itself separately below, so this
      // number is a count of real, verified sales.
      _analytics?.trackPurchaseVerified(
        productId: payload.productId,
        platform: payload.platform,
        source: source,
      );
    } else if (result.isProvisional) {
      // The store charged the user but the backend could not confirm it.
      // Premium is unlocked locally and the purchase is queued for retry; when
      // that retry confirms, SubscriptionManager emits the real
      // `purchase_verified` with source `retry`. NOT a conversion.
      log.w('⚠️ Provisional entitlement granted for ${payload.productId} '
          '(${result.reason})');
      _analytics?.trackPurchaseProvisionallyGranted(
        productId: payload.productId,
        platform: payload.platform,
        reason: result.reason ?? PurchaseReasonCodes.unknown,
      );
    } else {
      log.e('❌ Purchase verification failed for ${payload.productId}');
      _analytics?.trackVerificationFailed(
        productId: payload.productId,
        reason: result.reason ?? PurchaseReasonCodes.verificationRejected,
      );
    }

    if (result.grantsEntitlement) {
      // Isolated from the caller on purpose. Refreshing the UI's view of the
      // entitlement is a convenience; acknowledging the purchase with the
      // store is not. Letting a failure here escape would skip
      // finishTransaction, and Play refunds anything unacknowledged after
      // three days — so an offline status refresh would quietly undo a sale
      // the user had already been granted.
      try {
        await subscriptionManager.checkSubscriptionStatus(forceRefresh: true);

        // Feature gates read PremiumService, not SubscriptionManager directly,
        // so push the fresh entitlement into it right away — otherwise premium
        // features stay locked until the next app launch.
        await PremiumService().refreshPremiumStatus();
        log.i('✅ Subscription status refreshed');
      } catch (e) {
        log.e('Entitlement refresh failed after a granted purchase: $e');
      }
    }

    return result;
  }

  /// Acknowledge the purchase with the store.
  ///
  /// Never consumes: every Pinpoint product is an entitlement the user keeps,
  /// and consuming the lifetime unlock would put it back on sale.
  Future<void> _finish(Purchase purchase) async {
    try {
      await _client.finishTransaction(
        purchase: purchase,
        isConsumable: isConsumableProduct(purchase.productId),
      );
    } catch (e) {
      // Play retries acknowledgement on the next sighting; a throw here must
      // not lose the entitlement the user has already been granted.
      log.e('Failed to finish transaction for ${purchase.productId}: $e');
    }
  }

  Future<Set<String>> _deliveredIds() async {
    final cached = _delivered;
    if (cached != null) return cached;

    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_deliveredKey);
      final decoded = raw == null
          ? const <String>[]
          : (jsonDecode(raw) as List<dynamic>).cast<String>();
      return _delivered = decoded.toSet();
    } catch (e) {
      // A corrupt set must not block delivery; the backend is the real guard
      // against double-granting.
      log.w('Could not read delivered purchases: $e');
      return _delivered = <String>{};
    }
  }

  Future<void> _markDelivered(String identity) async {
    final delivered = await _deliveredIds();
    if (!delivered.add(identity)) return;

    try {
      final trimmed = delivered.length > _maxDeliveredIds
          ? delivered.skip(delivered.length - _maxDeliveredIds).toSet()
          : delivered;
      _delivered = trimmed;

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_deliveredKey, jsonEncode(trimmed.toList()));
    } catch (e) {
      log.w('Could not persist delivered purchase: $e');
    }
  }

  /// The recurring price to display for [product].
  String getDisplayPrice(ProductCommon product) => displayPriceFor(product);

  /// The free-trial length in days the store is offering on [product] TO THIS
  /// USER, or null when they would not get one.
  ///
  /// ALWAYS read from the store, never hardcoded, and never served from our
  /// own backend. Two independent reasons:
  ///
  /// 1. A trial is store *configuration* — a Play base-plan offer, an App
  ///    Store introductory offer. It can be shortened, lengthened or withdrawn
  ///    with no app release, and it varies by country.
  /// 2. More importantly, it is **per user**. Both stores grant a trial only
  ///    to someone who has not already used one in that subscription group.
  ///    Only the device can answer that: Play omits the offer from the queried
  ///    product for an ineligible user, and StoreKit answers it through
  ///    `isEligibleForIntroOfferIOS`. A server reading the catalogue knows
  ///    what offers *exist*, never who gets one — so backend-served trial copy
  ///    would promise a free trial to returning subscribers who are charged
  ///    immediately.
  ///
  /// Async because the StoreKit eligibility check is a platform call. Returns
  /// null on any failure: showing no trial copy is always safe, showing a
  /// trial that will not be granted is not.
  Future<int?> resolveTrialDays(ProductCommon product) async {
    try {
      if (product is ProductSubscriptionAndroid) {
        return androidTrialDays(product);
      }
      if (product is ProductSubscriptionIOS) {
        // Eligibility is per subscription GROUP, not per product: using one
        // trial in the group spends it for every plan in it.
        final groupId = product.subscriptionGroupIdIOS ?? product.id;
        final eligible = await _client.isEligibleForIntroOfferIOS(groupId);
        return iosTrialDaysIfEligible(product, isEligible: eligible);
      }
    } catch (e) {
      log.w('⚠️ resolveTrialDays failed for ${product.id}: $e');
    }
    return null;
  }

  /// Tear the singleton back down to its pre-[initialize] state.
  ///
  /// TESTS ONLY. There is intentionally no public `dispose()`: the purchase
  /// listeners are app-lifetime and must NEVER be cancelled by a widget — a
  /// paywall route closing used to kill them, after which no purchase, restore
  /// or deferred payment was ever processed again for the rest of the session.
  @visibleForTesting
  void resetForTesting() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _errorSubscription?.cancel();
    _errorSubscription = null;
    _purchaseListenerStarts = 0;
    _initialized = false;
    _initializing = null;
    _isAvailable = false;
    _products = [];
    _isRestoring = false;
    _fulfilling.clear();
    _delivered = null;
  }
}
