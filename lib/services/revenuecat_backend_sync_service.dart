import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/revenue_cat_service.dart';

/// Service to sync RevenueCat purchases with backend
class RevenueCatBackendSyncService {
  static final ApiService _apiService = ApiService();

  /// Sync current RevenueCat status with backend
  /// This provides redundancy in addition to RevenueCat webhooks
  static Future<bool> syncWithBackend() async {
    try {
      debugPrint('🔄 [RevenueCat Sync] Starting backend sync...');

      // Get Firebase user for identification
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('⚠️ [RevenueCat Sync] No Firebase user, skipping sync');
        return false;
      }

      // Get RevenueCat customer info
      final customerInfo = await RevenueCatService.getCustomerInfo();
      if (customerInfo == null) {
        debugPrint('⚠️ [RevenueCat Sync] No customer info available');
        return false;
      }

      // Check if user has premium entitlement
      final hasPremium =
          customerInfo.entitlements.active.containsKey('PinPoint Pro');

      // Get product ID and expiration
      String? productId;
      DateTime? expiresAt;

      if (hasPremium) {
        final entitlement = customerInfo.entitlements.active['PinPoint Pro'];
        productId = entitlement?.productIdentifier ?? 'unknown';

        // Parse expiration date
        final expirationDateStr = entitlement?.expirationDate;
        if (expirationDateStr != null) {
          try {
            expiresAt = DateTime.parse(expirationDateStr);
          } catch (e) {
            debugPrint('⚠️ [RevenueCat Sync] Error parsing expiration date: $e');
          }
        }
      } else {
        productId = 'free';
      }

      debugPrint('📊 [RevenueCat Sync] Status:');
      debugPrint('   - Premium: $hasPremium');
      debugPrint('   - Product: $productId');
      debugPrint('   - Expires: $expiresAt');

      // Sync with backend
      final response = await _apiService.syncRevenueCatPurchase(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email,
        productId: productId,
        isPremium: hasPremium,
        expiresAt: expiresAt,
      );

      debugPrint('✅ [RevenueCat Sync] Backend sync successful');
      debugPrint('   - Tier: ${response['tier']}');
      debugPrint('   - Message: ${response['message']}');

      return response['success'] == true;
    } catch (e, stackTrace) {
      debugPrint('❌ [RevenueCat Sync] Backend sync failed: $e');
      debugPrint('❌ [RevenueCat Sync] Stack trace: $stackTrace');
      // Don't throw - sync is optional, continue without backend sync
      return false;
    }
  }

  /// Sync after a purchase
  static Future<void> syncAfterPurchase() async {
    debugPrint('💳 [RevenueCat Sync] Syncing after purchase...');
    await syncWithBackend();
  }

  /// Sync after restore
  static Future<void> syncAfterRestore() async {
    debugPrint('🔄 [RevenueCat Sync] Syncing after restore...');
    await syncWithBackend();
  }

  /// Sync on app startup
  static Future<void> syncOnStartup() async {
    debugPrint('🚀 [RevenueCat Sync] Syncing on startup...');
    await syncWithBackend();
  }
}
