import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:pinpoint/services/revenuecat_backend_sync_service.dart';

/// RevenueCat service for managing subscriptions and entitlements
class RevenueCatService {
  static const String _apiKey = 'test_NUlxfophjYjZWAaWNsKhZBnUzBT';
  static const String _entitlementId = 'PinPoint Pro';

  // Product identifiers
  static const String productMonthly = 'monthly';
  static const String productYearly = 'yearly';
  static const String productLifetime = 'lifetime';

  static bool _isConfigured = false;

  /// Initialize RevenueCat SDK
  static Future<void> initialize() async {
    if (_isConfigured) {
      debugPrint('🔄 [RevenueCat] Already configured');
      return;
    }

    try {
      debugPrint('🚀 [RevenueCat] Initializing...');

      // Configure SDK
      final configuration = PurchasesConfiguration(_apiKey);

      // Configure will automatically use debug mode in debug builds
      await Purchases.configure(configuration);
      _isConfigured = true;

      debugPrint('✅ [RevenueCat] Initialized successfully');

      // Set up listener for customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    } catch (e, stackTrace) {
      debugPrint('❌ [RevenueCat] Initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Listener for customer info updates
  static void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    debugPrint('📢 [RevenueCat] Customer info updated');
    debugPrint(
        '   Active entitlements: ${customerInfo.entitlements.active.keys}');

    // Sync with backend when customer info changes
    // This ensures backend stays in sync even if webhooks fail
    RevenueCatBackendSyncService.syncWithBackend().then((success) {
      if (success) {
        debugPrint('✅ [RevenueCat] Backend synced from listener');
      } else {
        debugPrint('⚠️ [RevenueCat] Backend sync failed from listener');
      }
    });
  }

  /// Check if user has active premium subscription
  static Future<bool> isPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final hasEntitlement =
          customerInfo.entitlements.active.containsKey(_entitlementId);

      debugPrint('🔍 [RevenueCat] Premium check: $hasEntitlement');
      return hasEntitlement;
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] Error checking premium status: $e');
      return false;
    }
  }

  /// Get current customer info
  static Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] Error fetching customer info: $e');
      return null;
    }
  }

  /// Get available offerings
  static Future<Offerings?> getOfferings() async {
    try {
      debugPrint('📦 [RevenueCat] Fetching offerings...');
      final offerings = await Purchases.getOfferings();

      if (offerings.current != null) {
        debugPrint(
            '✅ [RevenueCat] Current offering found: ${offerings.current!.identifier}');
        debugPrint(
            '   Available packages: ${offerings.current!.availablePackages.length}');
      } else {
        debugPrint('⚠️ [RevenueCat] No current offering found');
      }

      return offerings;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error fetching offerings: $e');
      return null;
    }
  }

  /// Purchase a package
  static Future<CustomerInfo?> purchase(Package package) async {
    try {
      debugPrint('💳 [RevenueCat] Initiating purchase: ${package.identifier}');

      final purchaseResult = await Purchases.purchasePackage(package);

      debugPrint('✅ [RevenueCat] Purchase successful');
      debugPrint(
          '   Active entitlements: ${purchaseResult.customerInfo.entitlements.active.keys}');

      return purchaseResult.customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('❌ [RevenueCat] Purchase cancelled by user');
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        debugPrint('❌ [RevenueCat] Purchase not allowed');
      } else if (errorCode == PurchasesErrorCode.paymentPendingError) {
        debugPrint('⏳ [RevenueCat] Payment pending');
      } else {
        debugPrint('❌ [RevenueCat] Purchase error: ${e.message}');
      }

      rethrow;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Unexpected purchase error: $e');
      rethrow;
    }
  }

  /// Restore purchases
  static Future<CustomerInfo> restorePurchases() async {
    try {
      debugPrint('🔄 [RevenueCat] Restoring purchases...');
      final customerInfo = await Purchases.restorePurchases();

      debugPrint('✅ [RevenueCat] Purchases restored');
      debugPrint(
          '   Active entitlements: ${customerInfo.entitlements.active.keys}');

      return customerInfo;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error restoring purchases: $e');
      rethrow;
    }
  }

  /// Get subscription expiration date
  static Future<DateTime?> getExpirationDate() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[_entitlementId];

      if (entitlement != null) {
        // In newer RevenueCat versions, expirationDate is a String?
        final expirationDateStr = entitlement.expirationDate;
        if (expirationDateStr != null) {
          try {
            return DateTime.parse(expirationDateStr);
          } catch (e) {
            debugPrint('Error parsing expiration date: $e');
          }
        }
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] Error getting expiration date: $e');
      return null;
    }
  }

  /// Get subscription type (monthly, yearly, lifetime)
  static Future<String?> getSubscriptionType() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[_entitlementId];

      if (entitlement != null) {
        return entitlement.productIdentifier;
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] Error getting subscription type: $e');
      return null;
    }
  }

  /// Check if subscription is lifetime
  static Future<bool> isLifetime() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[_entitlementId];

      if (entitlement != null) {
        // Lifetime subscriptions typically have no expiration date or very far future date
        return entitlement.expirationDate == null ||
            entitlement.willRenew == false &&
                entitlement.productIdentifier
                    .toLowerCase()
                    .contains('lifetime');
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ [RevenueCat] Error checking lifetime status: $e');
      return false;
    }
  }

  /// Set user ID (optional, for tracking specific users)
  static Future<void> setUserId(String userId) async {
    try {
      debugPrint('👤 [RevenueCat] Setting user ID: $userId');
      await Purchases.logIn(userId);
      debugPrint('✅ [RevenueCat] User ID set successfully');
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error setting user ID: $e');
      rethrow;
    }
  }

  /// Log out user
  static Future<void> logout() async {
    try {
      debugPrint('👋 [RevenueCat] Logging out user');
      await Purchases.logOut();
      debugPrint('✅ [RevenueCat] User logged out successfully');
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error logging out: $e');
      rethrow;
    }
  }

  /// Set custom attributes
  static Future<void> setAttributes(Map<String, String> attributes) async {
    try {
      await Purchases.setAttributes(attributes);
      debugPrint('✅ [RevenueCat] Attributes set: $attributes');
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error setting attributes: $e');
    }
  }

  /// Get app user ID
  static Future<String> getAppUserId() async {
    try {
      return await Purchases.appUserID;
    } catch (e) {
      debugPrint('❌ [RevenueCat] Error getting app user ID: $e');
      return '';
    }
  }
}
