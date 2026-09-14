import 'dart:async';

import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';
import 'package:pinpoint/services/purchases/iap_client.dart';

/// Hand-rolled stand-in for the OpenIAP plugin.
///
/// `FlutterInappPurchase.instance` is a lazily-created singleton behind a
/// private static field, so — unlike the old `InAppPurchasePlatform.instance` —
/// it cannot be swapped from a test. `SubscriptionService.debugIapClient` is
/// the seam instead; assign one of these before touching the singleton.
///
/// No `debugDefaultTargetPlatformOverride` dance is needed any more: nothing in
/// the service resolves a platform plugin at field-initializer time.
class FakeIapClient implements IapClient {
  FakeIapClient({
    this.available = true,
    List<String> knownProductIds = const <String>[],
  }) : knownProductIds = List<String>.from(knownProductIds);

  final StreamController<Purchase> _purchases =
      StreamController<Purchase>.broadcast();
  final StreamController<PurchaseError> _errors =
      StreamController<PurchaseError>.broadcast();

  /// What [initConnection] answers.
  bool available;

  /// When set, [initConnection] throws this instead of returning.
  Object? initConnectionThrows;

  /// Product IDs `fetchProducts` will resolve; everything else is simply
  /// absent from the response, which is how OpenIAP reports an unknown SKU.
  List<String> knownProductIds;

  /// What [getAvailablePurchases] returns — the store's view of what the user
  /// owns. Restores and resume reconciles both read this.
  List<Purchase> owned = <Purchase>[];

  /// When set, [requestPurchase] throws this instead of returning.
  Object? requestPurchaseThrows;

  /// When set, [restorePurchases] throws this instead of returning.
  Object? restorePurchasesThrows;

  /// Introductory-offer eligibility [isEligibleForIntroOfferIOS] reports.
  bool introOfferEligible = true;

  final List<String> finishedPurchaseIds = <String>[];
  final List<bool> finishedAsConsumable = <bool>[];
  final List<RequestPurchaseProps> requestedPurchases = <RequestPurchaseProps>[];
  final List<ProductQueryType> fetchedTypes = <ProductQueryType>[];
  int restoreCalls = 0;
  int availablePurchaseCalls = 0;
  int fetchProductCalls = 0;
  int initConnectionCalls = 0;

  /// Whether the purchase stream has a subscriber. This is the assertion that
  /// matters: the app must hold exactly one, for the whole process.
  bool get hasListener => _purchases.hasListener;

  /// Push a store event onto the purchase stream.
  void emit(Purchase purchase) => _purchases.add(purchase);

  /// Push a failure onto the error stream.
  void emitError(PurchaseError error) => _errors.add(error);

  Future<void> close() async {
    await _purchases.close();
    await _errors.close();
  }

  @override
  Stream<Purchase> get purchaseUpdated => _purchases.stream;

  @override
  Stream<PurchaseError> get purchaseError => _errors.stream;

  @override
  Future<bool> initConnection() async {
    initConnectionCalls++;
    final thrown = initConnectionThrows;
    if (thrown != null) throw thrown;
    return available;
  }

  @override
  Future<void> endConnection() async {}

  @override
  Future<List<T>> fetchProducts<T extends ProductCommon>({
    required List<String> skus,
    required ProductQueryType type,
  }) async {
    fetchProductCalls++;
    fetchedTypes.add(type);
    final found = skus.where(knownProductIds.contains);
    return <T>[
      for (final id in found)
        (type == ProductQueryType.Subs
            ? fakeSubscriptionProduct(id)
            : fakeOneTimeProduct(id)) as T,
    ];
  }

  @override
  Future<void> requestPurchase(RequestPurchaseProps props) async {
    requestedPurchases.add(props);
    final thrown = requestPurchaseThrows;
    if (thrown != null) throw thrown;
  }

  @override
  Future<void> finishTransaction({
    required Purchase purchase,
    required bool isConsumable,
  }) async {
    finishedPurchaseIds.add(purchase.id);
    finishedAsConsumable.add(isConsumable);
  }

  @override
  Future<List<Purchase>> getAvailablePurchases() async {
    availablePurchaseCalls++;
    return owned;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    final thrown = restorePurchasesThrows;
    if (thrown != null) throw thrown;
  }

  @override
  Future<bool> isEligibleForIntroOfferIOS(String groupId) async =>
      introOfferEligible;
}

/// A Play subscription with one base-plan offer at a real price.
ProductSubscriptionAndroid fakeSubscriptionProduct(
  String id, {
  String displayPrice = r'$4.99',
  List<SubscriptionOffer>? offers,
}) =>
    ProductSubscriptionAndroid(
      currency: 'USD',
      description: 'Premium',
      displayPrice: displayPrice,
      id: id,
      nameAndroid: 'Pinpoint Premium',
      title: 'Pinpoint Premium',
      price: 4.99,
      subscriptionOffers: offers ??
          [
            fakeOffer(
              id: 'base',
              basePlanId: 'base',
              phases: [fakePricingPhase(formattedPrice: displayPrice)],
            ),
          ],
    );

/// A one-time (lifetime) product.
ProductAndroid fakeOneTimeProduct(String id, {String displayPrice = r'$29.99'}) =>
    ProductAndroid(
      currency: 'USD',
      description: 'Lifetime',
      displayPrice: displayPrice,
      id: id,
      nameAndroid: 'Pinpoint Lifetime',
      title: 'Pinpoint Lifetime',
      price: 29.99,
    );

SubscriptionOffer fakeOffer({
  required String id,
  String? basePlanId,
  String? offerToken = 'offer-token',
  List<PricingPhaseAndroid> phases = const [],
  DiscountOfferType type = DiscountOfferType.Introductory,
  PaymentMode? paymentMode,
  SubscriptionPeriod? period,
  int? periodCount,
  String displayPrice = r'$4.99',
  double price = 4.99,
}) =>
    SubscriptionOffer(
      id: id,
      basePlanIdAndroid: basePlanId,
      offerTokenAndroid: offerToken,
      displayPrice: displayPrice,
      price: price,
      type: type,
      paymentMode: paymentMode,
      period: period,
      periodCount: periodCount,
      pricingPhasesAndroid:
          phases.isEmpty ? null : PricingPhasesAndroid(pricingPhaseList: phases),
    );

/// `priceAmountMicros` is a String in the OpenIAP types, not a number — a
/// detail worth pinning in the fixtures so the parsing stays exercised.
PricingPhaseAndroid fakePricingPhase({
  String billingPeriod = 'P1M',
  String formattedPrice = r'$4.99',
  String priceAmountMicros = '4990000',
  int recurrenceMode = 2,
  int billingCycleCount = 0,
}) =>
    PricingPhaseAndroid(
      billingCycleCount: billingCycleCount,
      billingPeriod: billingPeriod,
      formattedPrice: formattedPrice,
      priceAmountMicros: priceAmountMicros,
      priceCurrencyCode: 'USD',
      recurrenceMode: recurrenceMode,
    );

/// A free-trial pricing phase: zero-priced and finite.
PricingPhaseAndroid fakeTrialPhase({String billingPeriod = 'P3D'}) =>
    fakePricingPhase(
      billingPeriod: billingPeriod,
      formattedPrice: 'Free',
      priceAmountMicros: '0',
      recurrenceMode: 2,
      billingCycleCount: 1,
    );

/// Builds a [PurchaseAndroid] as Play would deliver it.
///
/// [purchaseToken] defaults to a recognisable poison string so tests can assert
/// it never reaches an analytics payload.
PurchaseAndroid fakePurchase({
  required String productId,
  PurchaseState state = PurchaseState.Purchased,
  String? purchaseId,
  String? purchaseToken = 'SECRET-PURCHASE-TOKEN-DO-NOT-LEAK',
  bool isAcknowledged = false,
}) =>
    PurchaseAndroid(
      id: purchaseId ?? 'gpa-$productId',
      productId: productId,
      purchaseState: state,
      purchaseToken: purchaseToken,
      isAcknowledgedAndroid: isAcknowledged,
      isAutoRenewing: false,
      quantity: 1,
      store: IapStore.Google,
      transactionDate: 1750000000000,
      transactionId: purchaseId ?? 'gpa-$productId',
    );

/// Builds a [PurchaseIOS] as StoreKit 2 would deliver it; `purchaseToken` is
/// the signed transaction (JWS) the backend verifies.
PurchaseIOS fakeIosPurchase({
  required String productId,
  PurchaseState state = PurchaseState.Purchased,
  String transactionId = 'txn-1',
  String? purchaseToken = 'SIGNED.JWS.TRANSACTION',
}) =>
    PurchaseIOS(
      id: transactionId,
      productId: productId,
      purchaseState: state,
      purchaseToken: purchaseToken,
      isAutoRenewing: false,
      quantity: 1,
      store: IapStore.Apple,
      transactionDate: 1750000000000,
      transactionId: transactionId,
    );

/// A store failure, e.g. the user dismissing the billing sheet.
PurchaseError fakePurchaseError({
  ErrorCode? code = ErrorCode.UserCancelled,
  String? productId,
  String message = 'store prose that must never be reported',
}) =>
    PurchaseError(code: code, productId: productId, message: message);
