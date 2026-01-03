import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  bool get isPremium => _isPremium || _isInGracePeriod;
  bool get isInGracePeriod => _isInGracePeriod;
  String get subscriptionTier => _subscriptionTier;
  String? get subscriptionType => _subscriptionType;
  DateTime? get expirationDate => _subscriptionExpiresAt;
  DateTime? get gracePeriodEndsAt => _gracePeriodEndsAt;
  String? get deviceId => _deviceId;
  String? get productId => _productId;

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

    try {
      final status =
          await _apiService.getSubscriptionStatusByDevice(_deviceId!);

      _isPremium = status['is_premium'] ?? false;
      _isInGracePeriod = status['is_in_grace_period'] ?? false;
      _subscriptionTier = status['tier'] ?? 'free';
      _subscriptionType = status['subscription_type'];
      _productId = status['product_id'];

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
  }) async {
    if (_deviceId == null) {
      debugPrint('Device ID not available');
      return false;
    }

    try {
      final response = await _apiService.verifyPurchaseWithDevice(
        deviceId: _deviceId!,
        purchaseToken: purchaseToken,
        productId: productId,
        userId: userId, // Pass user ID to sync with user record
      );

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

        await _saveLocalSubscriptionStatus();
        notifyListeners();

        debugPrint('Purchase verified: premium=$_isPremium, tier=$_subscriptionTier, userId=$userId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Purchase verification error: $e');
      return false;
    }
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
