import 'package:flutter_inapp_purchase/flutter_inapp_purchase.dart';

/// The slice of `flutter_inapp_purchase` that Pinpoint actually uses.
///
/// `FlutterInappPurchase.instance` is a lazily-created singleton behind a
/// private static field with no setter, so — unlike the old
/// `InAppPurchasePlatform.instance` — there is no way to swap a fake in from a
/// test. Without a seam the entire purchase lifecycle would become
/// untestable, and the tests being protected here encode real money bugs:
/// exactly one app-lifetime listener, no conversion event before backend
/// verification, no purchase token in an analytics parameter.
///
/// So this interface exists purely as that seam. [LiveIapClient] forwards
/// every member straight to the plugin and holds no logic of its own; anything
/// worth asserting lives in `purchase_mapping.dart` or `SubscriptionService`.
abstract interface class IapClient {
  /// Emits one [Purchase] per store event: new purchases, restores, and
  /// deferred payments resolving.
  Stream<Purchase> get purchaseUpdated;

  /// Emits failures, including the user dismissing the billing sheet
  /// ([ErrorCode.UserCancelled]).
  Stream<PurchaseError> get purchaseError;

  /// Opens the billing connection. Throws [PurchaseError] when the store is
  /// unreachable.
  Future<bool> initConnection();

  Future<void> endConnection();

  Future<List<T>> fetchProducts<T extends ProductCommon>({
    required List<String> skus,
    required ProductQueryType type,
  });

  /// Launches the billing sheet. The outcome arrives on [purchaseUpdated] or
  /// [purchaseError], never as the return value.
  Future<void> requestPurchase(RequestPurchaseProps props);

  /// Acknowledges (or, for a consumable, consumes) a delivered purchase.
  ///
  /// Android refunds anything left unacknowledged for three days, so this must
  /// happen once the purchase has been delivered.
  Future<void> finishTransaction({
    required Purchase purchase,
    required bool isConsumable,
  });

  /// Current entitlements plus anything unfinished. Replaces the old plugin's
  /// purchase history, which Play Billing 8 removed.
  Future<List<Purchase>> getAvailablePurchases();

  /// iOS `AppStore.sync`. A no-op on Android, where entitlements are already
  /// readable via [getAvailablePurchases].
  Future<void> restorePurchases();

  /// Whether StoreKit will grant this user an introductory offer in
  /// [groupId]'s subscription group. Always false off iOS.
  Future<bool> isEligibleForIntroOfferIOS(String groupId);
}

/// The real client. Nothing but delegation — see [IapClient].
class LiveIapClient implements IapClient {
  LiveIapClient([FlutterInappPurchase? iap])
      : _iap = iap ?? FlutterInappPurchase.instance;

  final FlutterInappPurchase _iap;

  @override
  Stream<Purchase> get purchaseUpdated => _iap.purchaseUpdatedListener;

  @override
  Stream<PurchaseError> get purchaseError => _iap.purchaseErrorListener;

  @override
  Future<bool> initConnection() => _iap.initConnection();

  @override
  Future<void> endConnection() => _iap.endConnection();

  @override
  Future<List<T>> fetchProducts<T extends ProductCommon>({
    required List<String> skus,
    required ProductQueryType type,
  }) =>
      _iap.fetchProducts<T>(skus: skus, type: type);

  @override
  Future<void> requestPurchase(RequestPurchaseProps props) =>
      _iap.requestPurchase(props);

  @override
  Future<void> finishTransaction({
    required Purchase purchase,
    required bool isConsumable,
  }) =>
      _iap.finishTransaction(purchase: purchase, isConsumable: isConsumable);

  @override
  Future<List<Purchase>> getAvailablePurchases() =>
      _iap.getAvailablePurchases();

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  @override
  Future<bool> isEligibleForIntroOfferIOS(String groupId) =>
      _iap.isEligibleForIntroOfferIOS(groupId);
}
