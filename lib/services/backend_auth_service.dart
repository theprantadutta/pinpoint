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

  /// Authenticate with Firebase token (Google Sign-In)
  Future<void> authenticateWithGoogle(String firebaseToken) async {
    try {
      debugPrint('🔐 [BackendAuthService] Authenticating with Firebase token...');
      final response = await _apiService.authenticateWithFirebase(firebaseToken);
      debugPrint('✅ [BackendAuthService] Authentication response received');
      debugPrint('   - Response keys: ${response.keys}');

      _userId = response['user_id'];
      _isAuthenticated = true;
      debugPrint('✅ [BackendAuthService] User authenticated, ID: $_userId');

      // Fetch full user info
      debugPrint('🔐 [BackendAuthService] Fetching full user info...');
      await refreshUserInfo();
      debugPrint('✅ [BackendAuthService] User info loaded: $_userEmail');

      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ [BackendAuthService] Google authentication failed: $e');
      debugPrint('❌ [BackendAuthService] Stack trace: $stackTrace');
      throw Exception('Google authentication failed: $e');
    }
  }

  /// Link Google account to existing account (requires password verification)
  Future<void> linkGoogleAccount({
    required String firebaseToken,
    required String password,
  }) async {
    try {
      await _apiService.linkGoogleAccount(
        firebaseToken: firebaseToken,
        password: password,
      );

      // Refresh user info to get updated linked accounts
      await refreshUserInfo();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to link Google account: $e');
    }
  }

  /// Unlink Google account from current account
  Future<void> unlinkGoogleAccount() async {
    try {
      await _apiService.unlinkGoogleAccount();

      // Refresh user info to get updated linked accounts
      await refreshUserInfo();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to unlink Google account: $e');
    }
  }

  /// Get linked authentication providers
  Future<Map<String, dynamic>> getAuthProviders() async {
    try {
      final response = await _apiService.getAuthProviders();
      return response;
    } catch (e) {
      throw Exception('Failed to get auth providers: $e');
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
