import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
// PricingPhaseWrapper lives here, not in the package's main export.
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/premium_service.dart';
import 'package:pinpoint/services/logger_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';

/// Coarse, closed-set reason codes for checkout/verification analytics.
///
/// Analytics parameters must never carry an exception string, a store debug
/// message, a purchase token or verification data — raw detail goes to the
/// device log via `log.e` only. Anything not in this list is reported as
/// [_ReasonCodes.unknown].
abstract final class _ReasonCodes {
  static const String storeUnavailable = 'store_unavailable';
  static const String productNotFound = 'product_not_found';
  static const String launchRejected = 'launch_rejected';
  static const String noPurchaseToken = 'no_purchase_token';
  static const String verificationRejected = 'verification_rejected';
  static const String unknown = 'unknown';

  /// Firebase caps string parameter values at 100 chars; store error codes are
  /// short enums in practice, but clamp defensively.
  static const int maxLength = 100;
}

/// Owns the app's single, app-lifetime in-app-purchase stream listener.
///
/// Testing: `InAppPurchase` delegates every call to `InAppPurchasePlatform
/// .instance`, which has a public setter, so a test drives purchases by
/// assigning a fake platform (`extends InAppPurchasePlatform`, backed by a
/// broadcast `StreamController<List<PurchaseDetails>>`) before touching this
/// singleton — no injection point is needed here. Set
/// `debugDefaultTargetPlatformOverride = TargetPlatform.windows` first so the
/// plugin does not register the real Android platform over the fake, and call
/// [resetForTesting] between cases because the singleton is process-global.
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  // Subscription product IDs (must match Google Play Console)
  static const String premiumMonthly = 'pinpoint_premium_monthly';
  static const String premiumYearly = 'pinpoint_premium_yearly';
  static const String premiumLifetime = 'pinpoint_premium_lifetime';

  static const List<String> productIds = [
    premiumMonthly,
    premiumYearly,
    premiumLifetime,
  ];

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;
  bool get hasProducts => _products.isNotEmpty;

  /// The one and only purchase-stream subscription.
  ///
  /// This listener is APP-LIFETIME. The store delivers purchases, restores and
  /// deferred-payment resolutions on it at any moment — including long after
  /// the paywall route has closed — so it must never be cancelled by UI. There
  /// is deliberately no public `dispose()`; see [resetForTesting].
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  int _purchaseListenerStarts = 0;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  // Idempotency guards. [_initialized] answers "has initialization already
  // succeeded"; [_initializing] lets concurrent callers await the SAME work
  // instead of racing into a second listener and a second restore storm.
  bool _initialized = false;
  Future<void>? _initializing;

  /// Whether initialization has completed successfully at least once.
  bool get isInitialized => _initialized;

  /// Whether a purchase-stream listener is currently attached.
  bool get hasActivePurchaseListener => _subscription != null;

  /// How many purchase-stream listeners have been created in this process.
  /// Must never exceed 1 — anything higher means every purchase event is being
  /// handled (and verified, and completed) more than once.
  int get purchaseListenerStarts => _purchaseListenerStarts;

  // Track restore state
  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;
  int _restoredCount = 0;
  Function(int restoredCount, bool hasError)? _onRestoreComplete;

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
    // Check if in-app purchases are available
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      // Leave _initialized false: the store may become available later, and
      // no listener was created so there is nothing to duplicate.
      log.w('In-app purchases not available');
      return;
    }

    // Load products
    await loadProducts();

    // Listen to purchase updates — exactly once per process.
    if (_subscription == null) {
      _purchaseListenerStarts++;
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (error) {
          log.e('Purchase stream error: $error');
        },
      );
    }

    _initialized = true;

    // Restore previous purchases
    await restorePurchases();
  }

  /// Load subscription products from the active store (Google Play / App Store).
  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(productIds.toSet());

      if (response.error != null) {
        log.e('Failed to load products: ${response.error}');
        return;
      }

      _products = response.productDetails;
      log.i('Loaded ${_products.length}/${productIds.length} products: '
          '${_products.map((p) => p.id).toList()}');

      // notFoundIDs is the #1 symptom of a store-config mismatch: the product
      // ID doesn't exist / isn't Approved / bundle-id mismatch (iOS) or isn't
      // active (Android). Surface it clearly instead of a silently empty paywall.
      if (response.notFoundIDs.isNotEmpty) {
        log.w('⚠️ Products NOT found in store (check IDs/approval/status): '
            '${response.notFoundIDs}');
      }
    } catch (e) {
      log.e('Error loading products: $e');
    }
  }

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Launch the store's billing sheet for [productId].
  ///
  /// The returned bool only says whether the sheet was LAUNCHED — the actual
  /// purchase outcome arrives later on the purchase stream. The launch-stage
  /// analytics are emitted here rather than from the paywall because this is
  /// the only place that can tell the failure modes apart.
  Future<bool> purchase(String productId) async {
    if (!_isAvailable) {
      log.e('In-app purchases not available');
      _analytics?.trackCheckoutLaunchFailed(
          productId: productId, reason: _ReasonCodes.storeUnavailable);
      return false;
    }

    final product = getProduct(productId);
    if (product == null) {
      log.e('Product not found: $productId');
      _analytics?.trackCheckoutLaunchFailed(
          productId: productId, reason: _ReasonCodes.productNotFound);
      return false;
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // Both subscriptions and the lifetime SKU are non-consumable purchases.
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (success) {
        _analytics?.trackCheckoutLaunchSucceeded(productId: productId);
      } else {
        _analytics?.trackCheckoutLaunchFailed(
            productId: productId, reason: _ReasonCodes.launchRejected);
      }
      return success;
    } catch (e) {
      // Raw detail stays on-device; analytics gets a coarse code only.
      log.e('Purchase error: $e');
      _analytics?.trackCheckoutLaunchFailed(
          productId: productId, reason: _coarseCodeForException(e));
      return false;
    }
  }

  /// Maps a thrown store error to a short, bounded code. Never returns free
  /// text: `PlatformException.message`/`details` can carry Play's debugMessage
  /// or iOS `NSError.userInfo`, neither of which may leave the device.
  String _coarseCodeForException(Object error) {
    final code = error is PlatformException ? error.code : null;
    return _sanitizeCode(code);
  }

  /// Normalises a store-supplied code into a lower-case, length-capped token.
  String _sanitizeCode(String? code) {
    if (code == null || code.trim().isEmpty) return _ReasonCodes.unknown;
    final normalized = code.trim().toLowerCase();
    return normalized.length <= _ReasonCodes.maxLength
        ? normalized
        : normalized.substring(0, _ReasonCodes.maxLength);
  }

  /// Restore previous purchases
  ///
  /// [onComplete] is called when restore finishes with the count of restored purchases
  Future<void> restorePurchases({
    Function(int restoredCount, bool hasError)? onComplete,
  }) async {
    if (!_isAvailable) {
      onComplete?.call(0, true);
      return;
    }

    try {
      _isRestoring = true;
      _restoredCount = 0;
      _onRestoreComplete = onComplete;

      await _iap.restorePurchases();
      log.i('Restore purchases initiated');

      // Give the purchase stream time to process restored purchases
      // Then complete the restore operation
      Future.delayed(const Duration(seconds: 3), () {
        if (_isRestoring) {
          _finishRestore(hasError: false);
        }
      });
    } catch (e) {
      log.e('Restore error: $e');
      _finishRestore(hasError: true);
    }
  }

  void _finishRestore({required bool hasError}) {
    _isRestoring = false;
    _onRestoreComplete?.call(_restoredCount, hasError);
    _onRestoreComplete = null;
    log.i('Restore completed: $_restoredCount purchases restored');
  }

  /// Handle purchase updates.
  ///
  /// Every stream-sourced analytics event is emitted from here, never from the
  /// paywall — the store can deliver an outcome minutes after the paywall route
  /// closed, and this listener outlives it.
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      log.i('Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Payment pending (deferred payment, parental approval, …)
          log.i('Purchase pending: ${purchase.productID}');
          _analytics?.trackCheckoutPending(productId: purchase.productID);

        case PurchaseStatus.purchased:
          _analytics?.trackStorePurchaseConfirmed(
              productId: purchase.productID, source: _sourceFor(purchase));
          await _handleSuccessfulPurchase(purchase);

        case PurchaseStatus.canceled:
          // The user dismissed the billing sheet. Previously this fell through
          // the if/else chain unhandled, so cancellations were invisible.
          log.i('Purchase cancelled: ${purchase.productID}');
          _analytics?.trackCheckoutCancelled(productId: purchase.productID);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

        case PurchaseStatus.error:
          // purchase.error.message/details can carry store prose — log it
          // locally, but send only the coarse code onwards.
          log.e('Purchase error: ${purchase.error}');
          _analytics?.trackCheckoutError(
              productId: purchase.productID,
              reason: _sanitizeCode(purchase.error?.code));
          await _iap.completePurchase(purchase);

        case PurchaseStatus.restored:
          log.i('Processing restored purchase: ${purchase.productID}');
          _analytics?.trackStorePurchaseConfirmed(
              productId: purchase.productID, source: _sourceFor(purchase));
          await _handleSuccessfulPurchase(purchase);

          // Track restored count
          if (_isRestoring) {
            _restoredCount++;
          }
      }
    }
  }

  /// `'restore'` for anything the user already owned, `'purchase'` for a new
  /// sale. Keeps restores from inflating the conversion count.
  ///
  /// The status is the ONLY input. It deliberately does not consult
  /// `_isRestoring`: a restore runs a 3-second window during which a genuine
  /// new purchase can land — a user who taps buy while a restore is in flight,
  /// or whose deferred payment resolves then — and tagging that `restore`
  /// silently dropped a real sale out of the conversion count.
  String _sourceFor(PurchaseDetails purchase) =>
      purchase.status == PurchaseStatus.restored ? 'restore' : 'purchase';

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    try {
      log.i('🔔 _handleSuccessfulPurchase called for: ${purchase.productID}');

      // Verify purchase with backend
      String? purchaseToken;
      String platform = 'android';

      if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
        purchaseToken = purchase.billingClientPurchase.purchaseToken;
        platform = 'android';
        // Never log any part of the token — `log` writes to the device log in
        // release builds too. Length is enough to confirm we got one.
        log.i('📦 Got Google Play purchase token (${purchaseToken.length} chars)');
      } else if (Platform.isIOS) {
        // StoreKit 2: serverVerificationData is the JWS signed transaction the
        // backend verifies against Apple's certificate chain.
        purchaseToken = purchase.verificationData.serverVerificationData;
        platform = 'ios';
        if (purchaseToken.isEmpty) {
          log.w('⚠️ Empty iOS serverVerificationData');
          purchaseToken = null;
        } else {
          log.i('📦 Got StoreKit JWS transaction (${purchaseToken.length} chars)');
        }
      } else {
        log.w('⚠️ Unsupported platform / purchase type for verification');
      }

      if (purchaseToken != null) {
        final subscriptionManager = SubscriptionManager();
        final deviceId = subscriptionManager.deviceId;
        log.i('📱 Device ID: $deviceId');

        if (deviceId == null) {
          log.e('❌ Device ID is null! SubscriptionManager may not be initialized');
        }

        // Get user ID if authenticated (to sync subscription with user record)
        final backendAuthService = BackendAuthService();
        final userId = backendAuthService.isAuthenticated
            ? backendAuthService.userId
            : null;
        log.i('👤 User authenticated: ${backendAuthService.isAuthenticated}, userId: $userId');

        log.i('🚀 Calling verifyPurchase...');
        final result = await subscriptionManager.verifyPurchase(
          purchaseToken: purchaseToken,
          productId: purchase.productID,
          userId: userId, // Sync with user record if authenticated
          platform: platform,
        );

        if (result.isConfirmed) {
          log.i('✅ Purchase verified: ${purchase.productID}, userId: $userId');

          // The single conversion event. It fires only for a backend-confirmed
          // purchase: a provisional grant reports itself separately below, so
          // this number is a count of real, verified sales.
          _analytics?.trackPurchaseVerified(
            productId: purchase.productID,
            platform: platform,
            source: _sourceFor(purchase),
          );
        } else if (result.isProvisional) {
          // The store charged the user but the backend could not confirm it.
          // Premium is unlocked locally and the purchase is queued for retry;
          // when that retry confirms, SubscriptionManager emits the real
          // `purchase_verified` with source `retry`. NOT a conversion.
          log.w('⚠️ Provisional entitlement granted for ${purchase.productID} '
              '(${result.reason})');
          _analytics?.trackPurchaseProvisionallyGranted(
            productId: purchase.productID,
            platform: platform,
            reason: result.reason ?? _ReasonCodes.unknown,
          );
        } else {
          log.e('❌ Purchase verification failed for ${purchase.productID}');
          _analytics?.trackVerificationFailed(
            productId: purchase.productID,
            reason: result.reason ?? _ReasonCodes.verificationRejected,
          );
        }

        if (result.grantsEntitlement) {
          // Force refresh subscription status to update UI immediately
          await subscriptionManager.checkSubscriptionStatus(forceRefresh: true);

          // Feature gates read PremiumService, not SubscriptionManager directly,
          // so push the fresh entitlement into it right away — otherwise premium
          // features stay locked until the next app launch.
          await PremiumService().refreshPremiumStatus();
          log.i('✅ Subscription status refreshed');
        }
      } else {
        // No token means verification could not even be attempted.
        log.e('❌ Purchase token is null!');
        _analytics?.trackVerificationFailed(
            productId: purchase.productID,
            reason: _ReasonCodes.noPurchaseToken);
      }

      // Complete the purchase
      await _iap.completePurchase(purchase);
      log.i('✅ Purchase completed');
    } catch (e, stackTrace) {
      log.e('❌ Error handling purchase: $e');
      log.e('Stack trace: $stackTrace');
    }
  }

  /// The recurring price to display for a product.
  ///
  /// Google Play exposes `ProductDetails.price` as the FIRST pricing phase of
  /// the subscription offer. This digs into the offer's pricing phases and
  /// returns the first PAID phase (priceAmountMicros > 0), i.e. the real
  /// recurring price, so any zero-priced intro phase is skipped. Falls back to
  /// `product.price` (non-Android / no offer details).
  String getDisplayPrice(ProductDetails product) {
    try {
      final phases = _pricingPhasesOf(product);
      if (phases != null) {
        final paid = phases.where((p) => p.priceAmountMicros > 0).toList();
        if (paid.isNotEmpty) return paid.last.formattedPrice;
      }
    } catch (e) {
      log.w('⚠️ getDisplayPrice fallback for ${product.id}: $e');
    }
    return product.price;
  }

  /// The free-trial length in days the store is offering on [product] TO THIS
  /// USER, or null when they would not get one.
  ///
  /// ALWAYS read from the store, never hardcoded, and never served from our own
  /// backend. Two independent reasons:
  ///
  /// 1. A trial is store *configuration* — a Play base-plan offer, an App Store
  ///    introductory offer. It can be shortened, lengthened or withdrawn with no
  ///    app release, and it varies by country.
  /// 2. More importantly, it is **per user**. Both stores grant a trial only to
  ///    someone who has not already used one in that subscription group. Only
  ///    the device can answer that: Play omits the offer from the queried
  ///    product for an ineligible user, and StoreKit answers it through
  ///    `isIntroductoryOfferEligible`. A server reading the catalogue knows what
  ///    offers *exist*, never who gets one — so backend-served trial copy would
  ///    promise a free trial to returning subscribers who are charged
  ///    immediately.
  ///
  /// Async because the StoreKit eligibility check is a platform call. Returns
  /// null on any failure: showing no trial copy is always safe, showing a trial
  /// that will not be granted is not.
  Future<int?> resolveTrialDays(ProductDetails product) async {
    try {
      if (product is GooglePlayProductDetails) return _playTrialDays(product);
      if (product is AppStoreProduct2Details) {
        return await _appStoreTrialDays(product);
      }
    } catch (e) {
      log.w('⚠️ resolveTrialDays failed for ${product.id}: $e');
    }
    return null;
  }

  /// Play: the zero-priced pricing phase of the selected offer.
  ///
  /// No eligibility call is needed. Play only returns offers the user qualifies
  /// for, so an ineligible user simply has no free phase to find.
  int? _playTrialDays(GooglePlayProductDetails product) {
    final phases = _pricingPhasesOf(product);
    if (phases == null) return null;
    for (final phase in phases) {
      if (phase.priceAmountMicros != 0) continue;
      final days = _daysInBillingPeriod(phase.billingPeriod);
      if (days != null && days > 0) return days;
    }
    return null;
  }

  /// App Store: the introductory offer, confirmed against this user's
  /// eligibility.
  ///
  /// Note the plugin's field name is a misnomer — `promotionalOffers` carries
  /// EVERY offer the native side found (win-back, promotional AND introductory);
  /// `SK2SubscriptionOffer.type` is what separates them. Reading the list
  /// without filtering on [SK2SubscriptionOfferType.introductory] and
  /// [SK2SubscriptionOfferPaymentMode.freeTrial] would advertise a paid
  /// promotional offer as a free trial.
  Future<int?> _appStoreTrialDays(AppStoreProduct2Details product) async {
    final offers = product.sk2Product.subscription?.promotionalOffers;
    if (offers == null || offers.isEmpty) return null;

    SK2SubscriptionOffer? intro;
    for (final offer in offers) {
      if (offer.type == SK2SubscriptionOfferType.introductory &&
          offer.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial) {
        intro = offer;
        break;
      }
    }
    if (intro == null) return null;

    // Configured is not the same as granted: a returning subscriber sees the
    // offer on the product but is not entitled to it. Called on the wrapper
    // rather than InAppPurchaseStoreKitPlatform, whose constructor is
    // @visibleForTesting; reaching this line at all means StoreKit 2 is active,
    // since AppStoreProduct2Details exists only under SK2.
    final eligible = await SK2Product.isIntroductoryOfferEligible(product.id);
    if (!eligible) return null;

    final unitDays = switch (intro.period.unit) {
      SK2SubscriptionPeriodUnit.day => 1,
      SK2SubscriptionPeriodUnit.week => 7,
      SK2SubscriptionPeriodUnit.month => 30,
      SK2SubscriptionPeriodUnit.year => 365,
    };
    final total = intro.period.value * unitDays * intro.periodCount;
    return total > 0 ? total : null;
  }

  /// The pricing phases of the offer Play selected for [product].
  ///
  /// Shared by [getDisplayPrice] and [_playTrialDays] so both always read the
  /// same offer — reading different ones would let the card advertise a trial
  /// belonging to a price it is not showing.
  List<PricingPhaseWrapper>? _pricingPhasesOf(ProductDetails product) {
    if (product is! GooglePlayProductDetails) return null;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (offers == null || offers.isEmpty) return null;
    final index = (product.subscriptionIndex != null &&
            product.subscriptionIndex! >= 0 &&
            product.subscriptionIndex! < offers.length)
        ? product.subscriptionIndex!
        : 0;
    return offers[index].pricingPhases;
  }

  /// Days in an ISO-8601 billing period as Play reports it (`P3D`, `P1W`, …).
  ///
  /// Months and years are approximated; a trial is never expressed in them in
  /// practice, and the value is only used for display.
  static int? _daysInBillingPeriod(String? period) {
    if (period == null || period.isEmpty) return null;
    final match = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$')
        .firstMatch(period);
    if (match == null) return null;

    int part(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
    final total =
        part(1) * 365 + part(2) * 30 + part(3) * 7 + part(4);
    return total > 0 ? total : null;
  }

  /// Tear the singleton back down to its pre-[initialize] state.
  ///
  /// TESTS ONLY. There is intentionally no public `dispose()`: the purchase
  /// stream listener is app-lifetime and must NEVER be cancelled by a widget —
  /// a paywall route closing used to kill it, after which no purchase, restore
  /// or deferred payment was ever processed again for the rest of the session.
  @visibleForTesting
  void resetForTesting() {
    _subscription?.cancel();
    _subscription = null;
    _purchaseListenerStarts = 0;
    _initialized = false;
    _initializing = null;
    _isAvailable = false;
    _products = [];
    _isRestoring = false;
    _restoredCount = 0;
    _onRestoreComplete = null;
  }
}
