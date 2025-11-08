import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:pinpoint/services/api_service.dart';

/// Manages subscription status without requiring user authentication
/// Uses device ID for identification and local storage for offline access
class SubscriptionManager extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isPremium = false;
  String _subscriptionTier = 'free';
  DateTime? _subscriptionExpiresAt;
  String? _deviceId;

  bool get isPremium => _isPremium;
  String get subscriptionTier => _subscriptionTier;
  DateTime? get subscriptionExpiresAt => _subscriptionExpiresAt;
  String? get deviceId => _deviceId;

  static const String _premiumKey = 'is_premium';
  static const String _tierKey = 'subscription_tier';
  static const String _expiryKey = 'subscription_expires_at';
  static const String _deviceIdKey = 'device_id';

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
      _subscriptionTier = preferences.getString(_tierKey) ?? 'free';

      final expiryString = preferences.getString(_expiryKey);
      if (expiryString != null) {
        _subscriptionExpiresAt = DateTime.parse(expiryString);

        // Check if expired
        if (_subscriptionExpiresAt!.isBefore(DateTime.now())) {
          _isPremium = false;
          _subscriptionTier = 'free';
        }
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
      await preferences.setString(_tierKey, _subscriptionTier);

      if (_subscriptionExpiresAt != null) {
        await preferences.setString(
            _expiryKey, _subscriptionExpiresAt!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Error saving subscription status: $e');
    }
  }

  /// Check subscription status with backend
  Future<void> checkSubscriptionStatus() async {
    if (_deviceId == null) return;

    try {
      final status =
          await _apiService.getSubscriptionStatusByDevice(_deviceId!);

      _isPremium = status['is_premium'] ?? false;
      _subscriptionTier = status['tier'] ?? 'free';

      if (status['expires_at'] != null) {
        _subscriptionExpiresAt = DateTime.parse(status['expires_at']);
      }

      await _saveLocalSubscriptionStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Subscription status check error: $e');
      // Continue with local cache if backend fails
    }
  }

  /// Verify purchase with backend
  Future<bool> verifyPurchase({
    required String purchaseToken,
    required String productId,
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
      );

      if (response['success'] == true) {
        // Update premium status
        _isPremium = response['is_premium'] ?? true;
        _subscriptionTier = response['tier'] ?? 'premium';

        if (response['expires_at'] != null) {
          _subscriptionExpiresAt = DateTime.parse(response['expires_at']);
        }

        await _saveLocalSubscriptionStatus();
        notifyListeners();

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
