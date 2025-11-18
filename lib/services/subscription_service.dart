import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/logger_service.dart';

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

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  /// Static initialize method for use in main.dart
  static Future<void> initialize() async {
    await _instance._initialize();
  }

  /// Initialize subscription service
  Future<void> _initialize() async {
    // Check if in-app purchases are available
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      log.w('In-app purchases not available');
      return;
    }

    // Load products
    await loadProducts();

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        log.e('Purchase stream error: $error');
      },
    );

    // Restore previous purchases
    await restorePurchases();
  }

  /// Load subscription products from Google Play
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
      log.i('Loaded ${_products.length} products');
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

  /// Purchase a subscription
  Future<bool> purchase(String productId) async {
    if (!_isAvailable) {
      log.e('In-app purchases not available');
      return false;
    }

    final product = getProduct(productId);
    if (product == null) {
      log.e('Product not found: $productId');
      return false;
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      bool success;
      if (productId == premiumLifetime) {
        // One-time purchase
        success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Subscription
        success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }

      return success;
    } catch (e) {
      log.e('Purchase error: $e');
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    try {
      await _iap.restorePurchases();
      log.i('Purchases restored');
    } catch (e) {
      log.e('Restore error: $e');
    }
  }

  /// Handle purchase updates
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      log.i('Purchase update: ${purchase.productID} - ${purchase.status}');

      if (purchase.status == PurchaseStatus.pending) {
        // Payment pending
        log.i('Purchase pending: ${purchase.productID}');
      } else if (purchase.status == PurchaseStatus.purchased) {
        // Purchase successful
        await _handleSuccessfulPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        // Purchase failed
        log.e('Purchase error: ${purchase.error}');
        await _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.restored) {
        // Purchase restored
        await _handleSuccessfulPurchase(purchase);
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    try {
      // Verify purchase with backend
      String? purchaseToken;

      if (Platform.isAndroid) {
        final androidPurchase = purchase as GooglePlayPurchaseDetails;
        purchaseToken = androidPurchase.billingClientPurchase.purchaseToken;
      }

      if (purchaseToken != null) {
        final subscriptionManager = SubscriptionManager();
        final verified = await subscriptionManager.verifyPurchase(
          purchaseToken: purchaseToken,
          productId: purchase.productID,
        );

        if (verified) {
          log.i('Purchase verified: ${purchase.productID}');
        } else {
          log.e('Purchase verification failed');
        }
      }

      // Complete the purchase
      await _iap.completePurchase(purchase);
    } catch (e) {
      log.e('Error handling purchase: $e');
    }
  }

  /// Check if product has trial (monthly and yearly have 7-day trial)
  bool hasTrialPeriod(String productId) {
    return productId == premiumMonthly || productId == premiumYearly;
  }

  /// Get trial period text for UI
  String getTrialPeriodText(String productId) {
    if (hasTrialPeriod(productId)) {
      return '7-day free trial';
    }
    return '';
  }

  /// Get price text with trial info
  String getPriceTextWithTrial(ProductDetails product) {
    final basePrice = product.price;

    if (hasTrialPeriod(product.id)) {
      if (product.id == premiumMonthly) {
        return 'Free for 7 days, then $basePrice/month';
      } else if (product.id == premiumYearly) {
        return 'Free for 7 days, then $basePrice/year';
      }
    }

    return basePrice;
  }

  /// Dispose subscription
  void dispose() {
    _subscription?.cancel();
  }
}
