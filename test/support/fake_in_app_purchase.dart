import 'dart:async';

// `InAppPurchasePlatform` is not re-exported by `package:in_app_purchase`
// (only the value types are), so the platform interface has to be imported
// directly. It is a transitive dependency of in_app_purchase, which the app
// depends on directly, and this file lives under test/ only.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

/// Hand-rolled stand-in for the store plugin.
///
/// `InAppPurchase` delegates every call to `InAppPurchasePlatform.instance`,
/// which has a public setter, so assigning one of these is the whole seam —
/// no injection point is needed inside [SubscriptionService].
///
/// It MUST `extend` (not `implement`) [InAppPurchasePlatform]: the base
/// constructor supplies the token `PlatformInterface.verify` checks for.
///
/// Ordering matters in `setUp`:
///   1. `debugDefaultTargetPlatformOverride = TargetPlatform.windows;`
///      (otherwise `InAppPurchase.instance` registers the real Android
///      platform over this fake and opens a live billing connection)
///   2. `InAppPurchasePlatform.instance = fake;`
///   3. only then touch `SubscriptionService`.
class FakeInAppPurchasePlatform extends InAppPurchasePlatform {
  FakeInAppPurchasePlatform({
    this.available = true,
    List<String> knownProductIds = const <String>[],
  }) : knownProductIds = List<String>.from(knownProductIds);

  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  /// What [isAvailable] answers.
  bool available;

  /// Product IDs [queryProductDetails] will resolve; everything else comes
  /// back in `notFoundIDs`.
  List<String> knownProductIds;

  /// What [buyNonConsumable] returns when it does not throw.
  bool buyNonConsumableResult = true;

  /// When set, [buyNonConsumable] throws this instead of returning.
  Object? buyNonConsumableThrows;

  /// When set, [restorePurchases] throws this instead of returning.
  ///
  /// Useful beyond error testing: a rejected restore makes
  /// `SubscriptionService` finish its restore window synchronously, instead of
  /// leaving `isRestoring` true for the three real seconds its
  /// `Future.delayed` fallback takes.
  Object? restorePurchasesThrows;

  final List<String> completedPurchaseIds = <String>[];
  int buyCalls = 0;
  int restoreCalls = 0;
  int queryProductCalls = 0;

  /// Number of live listeners on the purchase stream. This is the assertion
  /// that matters: the app must hold exactly one, for the whole process.
  bool get hasListener => _controller.hasListener;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  /// Push a store event onto the purchase stream.
  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  Future<void> close() => _controller.close();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queryProductCalls++;
    final found = identifiers.where(knownProductIds.contains).toList();
    return ProductDetailsResponse(
      productDetails: [for (final id in found) fakeProduct(id)],
      notFoundIDs: identifiers.where((id) => !found.contains(id)).toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    final thrown = buyNonConsumableThrows;
    if (thrown != null) throw thrown;
    return buyNonConsumableResult;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchaseIds.add(purchase.purchaseID ?? purchase.productID);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    final thrown = restorePurchasesThrows;
    if (thrown != null) throw thrown;
  }
}

ProductDetails fakeProduct(String id) => ProductDetails(
      id: id,
      title: 'Pinpoint Premium',
      description: 'Premium',
      price: '\$4.99',
      rawPrice: 4.99,
      currencyCode: 'USD',
    );

/// Builds a [PurchaseDetails] as the store would deliver it.
///
/// [serverVerificationData] defaults to a recognisable poison string so tests
/// can assert it never reaches an analytics payload.
PurchaseDetails fakePurchase({
  required String productId,
  required PurchaseStatus status,
  String? purchaseId,
  String serverVerificationData = 'SECRET-PURCHASE-TOKEN-DO-NOT-LEAK',
  IAPError? error,
  bool pendingCompletePurchase = false,
}) {
  final details = PurchaseDetails(
    purchaseID: purchaseId ?? 'gpa-$productId',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: serverVerificationData,
      serverVerificationData: serverVerificationData,
      source: 'fake_store',
    ),
    transactionDate: '1750000000000',
    status: status,
  );
  details.error = error;
  details.pendingCompletePurchase = pendingCompletePurchase;
  return details;
}
