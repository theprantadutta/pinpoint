import 'package:flutter/foundation.dart';
import 'package:pinpoint/services/api_service.dart';

class BackendAuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isAuthenticated = false;
  bool _isPremium = false;
  String? _userEmail;
  String? _userId;
  String _subscriptionTier = 'free';
  DateTime? _subscriptionExpiresAt;

  bool get isAuthenticated => _isAuthenticated;
  bool get isPremium => _isPremium;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  String get subscriptionTier => _subscriptionTier;
  DateTime? get subscriptionExpiresAt => _subscriptionExpiresAt;

  /// Initialize authentication state
  Future<void> initialize() async {
    try {
      // Check if we have a token
      final hasToken = await _apiService.hasToken();

      if (hasToken) {
        // Try to fetch current user
        await refreshUserInfo();
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  /// Register new user
  Future<void> register(String email, String password) async {
    try {
      final response = await _apiService.register(email, password);

      _userId = response['user_id'];
      _userEmail = email;
      _isAuthenticated = true;

      // Fetch full user info
      await refreshUserInfo();

      notifyListeners();
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// Login user
  Future<void> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);

      _userId = response['user_id'];
      _userEmail = email;
      _isAuthenticated = true;

      // Fetch full user info
      await refreshUserInfo();

      notifyListeners();
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _isAuthenticated = false;
      _isPremium = false;
      _userEmail = null;
      _userId = null;
      _subscriptionTier = 'free';
      _subscriptionExpiresAt = null;

      notifyListeners();
    }
  }

  /// Refresh user information and subscription status
  Future<void> refreshUserInfo() async {
    try {
      final userInfo = await _apiService.getCurrentUser();

      _userId = userInfo['id'];
      _userEmail = userInfo['email'];
      _isPremium = userInfo['is_premium'] ?? false;
      _subscriptionTier = userInfo['subscription_tier'] ?? 'free';
      _isAuthenticated = true;

      // Parse expiration date if present
      if (userInfo['subscription_expires_at'] != null) {
        _subscriptionExpiresAt =
            DateTime.parse(userInfo['subscription_expires_at']);
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to fetch user info: $e');
    }
  }

  /// Check and update subscription status
  Future<void> checkSubscriptionStatus() async {
    try {
      final status = await _apiService.getSubscriptionStatus();

      _isPremium = status['is_premium'] ?? false;
      _subscriptionTier = status['tier'] ?? 'free';

      if (status['expires_at'] != null) {
        _subscriptionExpiresAt = DateTime.parse(status['expires_at']);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Subscription status check error: $e');
    }
  }

  /// Verify purchase with backend
  Future<bool> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    try {
      final response = await _apiService.verifyPurchase(
        purchaseToken: purchaseToken,
        productId: productId,
      );

      if (response['success'] == true) {
        // Update premium status
        await refreshUserInfo();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Purchase verification error: $e');
      return false;
    }
  }
}
