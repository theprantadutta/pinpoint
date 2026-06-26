import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/logger_service.dart';
import 'package:pinpoint/services/backend_auth_service.dart';

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

  // Track restore state
  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;
  int _restoredCount = 0;
  Function(int restoredCount, bool hasError)? _onRestoreComplete;

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
        log.i('Processing restored purchase: ${purchase.productID}');
        await _handleSuccessfulPurchase(purchase);

        // Track restored count
        if (_isRestoring) {
          _restoredCount++;
        }
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    try {
      log.i('🔔 _handleSuccessfulPurchase called for: ${purchase.productID}');

      // Verify purchase with backend
      String? purchaseToken;

      if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
        purchaseToken = purchase.billingClientPurchase.purchaseToken;
        log.i('📦 Got purchase token: ${purchaseToken.substring(0, 20)}...');
      } else {
        log.w('⚠️ Not Android or not GooglePlayPurchaseDetails');
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
        final verified = await subscriptionManager.verifyPurchase(
          purchaseToken: purchaseToken,
          productId: purchase.productID,
          userId: userId, // Sync with user record if authenticated
        );

        if (verified) {
          log.i('✅ Purchase verified: ${purchase.productID}, userId: $userId');

          // Force refresh subscription status to update UI immediately
          await subscriptionManager.checkSubscriptionStatus(forceRefresh: true);
          log.i('✅ Subscription status refreshed');
        } else {
          log.e('❌ Purchase verification failed for ${purchase.productID}');
        }
      } else {
        log.e('❌ Purchase token is null!');
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
    if (product is GooglePlayProductDetails) {
      try {
        final offers = product.productDetails.subscriptionOfferDetails;
        if (offers != null && offers.isNotEmpty) {
          final idx = (product.subscriptionIndex != null &&
                  product.subscriptionIndex! >= 0 &&
                  product.subscriptionIndex! < offers.length)
              ? product.subscriptionIndex!
              : 0;
          final phases = offers[idx].pricingPhases;
          final paid =
              phases.where((p) => p.priceAmountMicros > 0).toList();
          if (paid.isNotEmpty) return paid.last.formattedPrice;
        }
      } catch (e) {
        log.w('⚠️ getDisplayPrice fallback for ${product.id}: $e');
      }
    }
    return product.price;
  }

  /// Dispose subscription
  void dispose() {
    _subscription?.cancel();
  }
}
