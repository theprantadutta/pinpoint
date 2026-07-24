import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:pinpoint/services/api_service.dart';

/// Manages subscription status without requiring user authentication
/// Uses device ID for identification and local storage for offline access
class SubscriptionManager extends ChangeNotifier {
  // Singleton pattern
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  final ApiService _apiService = ApiService();

  bool _isPremium = false;
  bool _isInGracePeriod = false;
  String _subscriptionTier = 'free';
  String? _subscriptionType;
  DateTime? _subscriptionExpiresAt;
  DateTime? _gracePeriodEndsAt;
  String? _deviceId;
  DateTime? _lastFetchTime;
  String? _productId;
  bool _autoRenewing = true;
  DateTime? _cancelledAt;
  String? _cancellationReason;

  bool get isPremium => _isPremium || _isInGracePeriod;
  bool get isInGracePeriod => _isInGracePeriod;
  String get subscriptionTier => _subscriptionTier;
  String? get subscriptionType => _subscriptionType;
  DateTime? get expirationDate => _subscriptionExpiresAt;
  DateTime? get gracePeriodEndsAt => _gracePeriodEndsAt;
  String? get deviceId => _deviceId;
  String? get productId => _productId;
  bool get autoRenewing => _autoRenewing;
  DateTime? get cancelledAt => _cancelledAt;
  String? get cancellationReason => _cancellationReason;

  /// True when the user has cancelled but still has paid access until expirationDate.
  bool get isCancelledButActive =>
      _cancelledAt != null && !_autoRenewing && isPremium && _subscriptionType != 'lifetime';

  /// Returns true if subscription data was fetched recently (within cache duration)
  bool get hasFreshData {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidDuration;
  }

  static const String _premiumKey = 'is_premium';
  static const String _gracePeriodKey = 'is_in_grace_period';
  static const String _tierKey = 'subscription_tier';
  static const String _typeKey = 'subscription_type';
  static const String _expiryKey = 'subscription_expires_at';
  static const String _gracePeriodExpiryKey = 'grace_period_ends_at';
  static const String _deviceIdKey = 'device_id';
  static const String _lastFetchKey = 'subscription_last_fetch';
  static const String _productIdKey = 'subscription_product_id';
  static const String _autoRenewingKey = 'subscription_auto_renewing';
  static const String _cancelledAtKey = 'subscription_cancelled_at';
  static const String _cancellationReasonKey = 'subscription_cancellation_reason';
  static const String _pendingVerificationKey = 'subscription_pending_verification';
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Initialize subscription manager
  Future<void> initialize() async {
    await _loadDeviceId();
    await _loadLocalSubscriptionStatus();
    await checkSubscriptionStatus();
  }

  /// Get or generate device ID
  Future<void> _loadDeviceId() async {
    final preferences = await SharedPreferences.getInstance();

    // Try to load existing device ID
    _deviceId = preferences.getString(_deviceIdKey);

    // Generate new one if doesn't exist
    if (_deviceId == null) {
      _deviceId = await _generateDeviceId();
      await preferences.setString(_deviceIdKey, _deviceId!);
    }
  }

  /// Generate unique device identifier
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? _generateFallbackId();
      } else {
        return _generateFallbackId();
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return _generateFallbackId();
    }
  }

  /// Generate fallback ID if device ID unavailable
  String _generateFallbackId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (Platform.localHostname.hashCode.toString());
  }

  /// Load subscription status from local storage
  Future<void> _loadLocalSubscriptionStatus() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      _isPremium = preferences.getBool(_premiumKey) ?? false;
      _isInGracePeriod = preferences.getBool(_gracePeriodKey) ?? false;
      _subscriptionTier = preferences.getString(_tierKey) ?? 'free';
      _subscriptionType = preferences.getString(_typeKey);
      _productId = preferences.getString(_productIdKey);
      _autoRenewing = preferences.getBool(_autoRenewingKey) ?? true;
      _cancellationReason = preferences.getString(_cancellationReasonKey);
      final cancelledAtString = preferences.getString(_cancelledAtKey);
      if (cancelledAtString != null) {
        _cancelledAt = DateTime.parse(cancelledAtString);
      }

      final expiryString = preferences.getString(_expiryKey);
      if (expiryString != null) {
        _subscriptionExpiresAt = DateTime.parse(expiryString);

        // Check if expired (but still check grace period)
        if (_subscriptionExpiresAt!.isBefore(DateTime.now())) {
          _isPremium = false;
          // Don't reset tier yet if in grace period
          if (!_isInGracePeriod) {
            _subscriptionTier = 'free';
          }
        }
      }

      final gracePeriodString = preferences.getString(_gracePeriodExpiryKey);
      if (gracePeriodString != null) {
        _gracePeriodEndsAt = DateTime.parse(gracePeriodString);

        // Check if grace period expired
        if (_gracePeriodEndsAt!.isBefore(DateTime.now())) {
          _isInGracePeriod = false;
          _gracePeriodEndsAt = null;
          _subscriptionTier = 'free';
        }
      }

      // Load last fetch timestamp
      final lastFetchString = preferences.getString(_lastFetchKey);
      if (lastFetchString != null) {
        _lastFetchTime = DateTime.parse(lastFetchString);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading subscription status: $e');
    }
  }

  /// Save subscription status to local storage
  Future<void> _saveLocalSubscriptionStatus() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      await preferences.setBool(_premiumKey, _isPremium);
      await preferences.setBool(_gracePeriodKey, _isInGracePeriod);
      await preferences.setString(_tierKey, _subscriptionTier);

      if (_subscriptionType != null) {
        await preferences.setString(_typeKey, _subscriptionType!);
      }

      if (_productId != null) {
        await preferences.setString(_productIdKey, _productId!);
      }

      if (_subscriptionExpiresAt != null) {
        await preferences.setString(
            _expiryKey, _subscriptionExpiresAt!.toIso8601String());
      }

      if (_gracePeriodEndsAt != null) {
        await preferences.setString(
            _gracePeriodExpiryKey, _gracePeriodEndsAt!.toIso8601String());
      } else {
        await preferences.remove(_gracePeriodExpiryKey);
      }

      await preferences.setBool(_autoRenewingKey, _autoRenewing);
      if (_cancelledAt != null) {
        await preferences.setString(_cancelledAtKey, _cancelledAt!.toIso8601String());
      } else {
        await preferences.remove(_cancelledAtKey);
      }
      if (_cancellationReason != null) {
        await preferences.setString(_cancellationReasonKey, _cancellationReason!);
      } else {
        await preferences.remove(_cancellationReasonKey);
      }

      // Save last fetch timestamp
      if (_lastFetchTime != null) {
        await preferences.setString(
            _lastFetchKey, _lastFetchTime!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Error saving subscription status: $e');
    }
  }

  /// Check subscription status with backend
  ///
  /// Set [forceRefresh] to true to bypass cache (e.g., after purchase verification)
  Future<void> checkSubscriptionStatus({bool forceRefresh = false}) async {
    if (_deviceId == null) return;

    // Skip API call if cache is still fresh
    if (!forceRefresh && hasFreshData) {
      debugPrint('Using cached subscription status (cache still valid)');
      return;
    }

    // A store purchase the backend hasn't confirmed yet takes priority: retry
    // it first, and while it stays unconfirmed skip the device-status fetch —
    // that endpoint doesn't know about the purchase and would downgrade the
    // provisional entitlement the user already paid for.
    if (await _retryPendingVerificationIfAny()) {
      return;
    }

    try {
      final status =
          await _apiService.getSubscriptionStatusByDevice(_deviceId!);

      _isPremium = status['is_premium'] ?? false;
      _isInGracePeriod = status['is_in_grace_period'] ?? false;
      _subscriptionTier = status['tier'] ?? 'free';
      _subscriptionType = status['subscription_type'];
      _productId = status['product_id'];
      _autoRenewing = status['auto_renewing'] ?? true;
      _cancellationReason = status['cancellation_reason'];

      if (status['expires_at'] != null) {
        _subscriptionExpiresAt = DateTime.parse(status['expires_at']);
      } else {
        _subscriptionExpiresAt = null;
      }

      if (status['grace_period_ends_at'] != null) {
        _gracePeriodEndsAt = DateTime.parse(status['grace_period_ends_at']);
      } else {
        _gracePeriodEndsAt = null;
      }

      if (status['cancelled_at'] != null) {
        _cancelledAt = DateTime.parse(status['cancelled_at']);
      } else {
        _cancelledAt = null;
      }

      // Update cache timestamp
      _lastFetchTime = DateTime.now();

      await _saveLocalSubscriptionStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Subscription status check error: $e');
      // Continue with local cache if backend fails
    }
  }

  /// Verify purchase with backend
  ///
  /// Optionally pass [userId] to sync the subscription with the user's account.
  /// When provided, both device and user records will be updated on the backend.
  Future<bool> verifyPurchase({
    required String purchaseToken,
    required String productId,
    String? userId,
    String platform = 'android',
  }) async {
    debugPrint('🔄 verifyPurchase called: productId=$productId, userId=$userId');

    if (_deviceId == null) {
      debugPrint('❌ Device ID not available - cannot verify purchase');
      return false;
    }

    debugPrint('📱 Using device ID: $_deviceId');

    try {
      debugPrint('🌐 Calling API verifyPurchaseWithDevice...');
      final response = await _apiService.verifyPurchaseWithDevice(
        deviceId: _deviceId!,
        purchaseToken: purchaseToken,
        productId: productId,
        userId: userId, // Pass user ID to sync with user record
        platform: platform,
      );

      debugPrint('📥 API Response: $response');

      if (response['success'] == true) {
        // Update premium status
        _isPremium = response['is_premium'] ?? true;
        _subscriptionTier = response['tier'] ?? 'premium';

        if (response['expires_at'] != null) {
          _subscriptionExpiresAt = DateTime.parse(response['expires_at']);
        }

        // Clear grace period on successful purchase
        _isInGracePeriod = false;
        _gracePeriodEndsAt = null;

        await _clearPendingVerification();
        await _saveLocalSubscriptionStatus();
        notifyListeners();

        debugPrint('✅ Purchase verified: premium=$_isPremium, tier=$_subscriptionTier, userId=$userId');
        return true;
      }

      // The store already charged the user; the backend just couldn't confirm
      // the purchase (service unavailable, misconfiguration, ...). Never leave
      // a paid user locked out: grant premium provisionally and keep retrying
      // verification in the background until the backend confirms.
      debugPrint('⚠️ API returned success=false: ${response['message']} '
          '— granting provisional entitlement');
      await _grantProvisionalEntitlement(
        purchaseToken: purchaseToken,
        productId: productId,
        userId: userId,
        platform: platform,
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('⚠️ Purchase verification error: $e — granting provisional entitlement');
      debugPrint('Stack trace: $stackTrace');
      await _grantProvisionalEntitlement(
        purchaseToken: purchaseToken,
        productId: productId,
        userId: userId,
        platform: platform,
      );
      return true;
    }
  }

  /// Unlock premium locally for a store-confirmed purchase the backend hasn't
  /// verified yet, and persist the purchase so verification can be retried.
  ///
  /// The store (StoreKit / Play Billing) has already validated and charged the
  /// purchase at this point; the backend is only re-verifying server-side. The
  /// provisional expiry is approximate — the first successful backend
  /// verification replaces it with the real one.
  Future<void> _grantProvisionalEntitlement({
    required String purchaseToken,
    required String productId,
    String? userId,
    required String platform,
  }) async {
    _isPremium = true;
    _subscriptionTier = 'premium';
    _isInGracePeriod = false;
    _gracePeriodEndsAt = null;
    _productId = productId;

    // Product IDs: pinpoint_premium_monthly / _yearly / _lifetime.
    if (productId.contains('lifetime')) {
      _subscriptionType = 'lifetime';
      _subscriptionExpiresAt = null;
    } else if (productId.contains('yearly')) {
      _subscriptionType = 'yearly';
      _subscriptionExpiresAt = DateTime.now().add(const Duration(days: 366));
    } else {
      _subscriptionType = 'monthly';
      _subscriptionExpiresAt = DateTime.now().add(const Duration(days: 32));
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingVerificationKey,
      jsonEncode({
        'purchaseToken': purchaseToken,
        'productId': productId,
        'userId': userId,
        'platform': platform,
      }),
    );

    await _saveLocalSubscriptionStatus();
    notifyListeners();
  }

  Future<void> _clearPendingVerification() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingVerificationKey);
  }

  /// Retry a stored, not-yet-backend-confirmed purchase.
  ///
  /// Returns true while the purchase is STILL unconfirmed (callers must then
  /// keep the provisional entitlement and skip the device-status fetch), false
  /// when there is nothing pending or the retry just succeeded.
  Future<bool> _retryPendingVerificationIfAny() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_pendingVerificationKey);
    if (raw == null) return false;

    try {
      final pending = jsonDecode(raw) as Map<String, dynamic>;
      final response = await _apiService.verifyPurchaseWithDevice(
        deviceId: _deviceId!,
        purchaseToken: pending['purchaseToken'],
        productId: pending['productId'],
        userId: pending['userId'],
        platform: pending['platform'] ?? 'android',
      );

      if (response['success'] == true) {
        _isPremium = response['is_premium'] ?? true;
        _subscriptionTier = response['tier'] ?? 'premium';
        if (response['expires_at'] != null) {
          _subscriptionExpiresAt = DateTime.parse(response['expires_at']);
        }
        _isInGracePeriod = false;
        _gracePeriodEndsAt = null;
        _lastFetchTime = DateTime.now();

        await preferences.remove(_pendingVerificationKey);
        await _saveLocalSubscriptionStatus();
        notifyListeners();
        debugPrint('✅ Pending purchase verification resolved');
        return false;
      }
      debugPrint('⏳ Pending verification still unconfirmed: ${response['message']}');
    } catch (e) {
      debugPrint('⏳ Pending verification retry failed: $e');
    }
    return true;
  }

  /// Grant premium access (for testing or promotions)
  Future<void> grantPremium({
    String tier = 'premium',
    DateTime? expiresAt,
  }) async {
    _isPremium = true;
    _subscriptionTier = tier;
    _subscriptionExpiresAt = expiresAt;

    await _saveLocalSubscriptionStatus();
    notifyListeners();
  }

  /// Revoke premium access
  Future<void> revokePremium() async {
    _isPremium = false;
    _subscriptionTier = 'free';
    _subscriptionExpiresAt = null;

    await _saveLocalSubscriptionStatus();
    notifyListeners();
  }
}
