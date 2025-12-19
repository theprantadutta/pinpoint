import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pinpoint/services/api_service.dart';

/// Keys for caching auth state locally
const String _kCachedUserId = 'cached_user_id';
const String _kCachedUserEmail = 'cached_user_email';
const String _kCachedIsPremium = 'cached_is_premium';
const String _kCachedSubscriptionTier = 'cached_subscription_tier';
const String _kCachedSubscriptionExpiry = 'cached_subscription_expiry';
const String _kCachedAuthTimestamp = 'cached_auth_timestamp';

class BackendAuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isAuthenticated = false;
  bool _isPremium = false;
  String? _userEmail;
  String? _userId;
  String _subscriptionTier = 'free';
  DateTime? _subscriptionExpiresAt;

  // Initialization state tracking
  bool _isInitializing = false;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // Session cache for auth providers
  Map<String, dynamic>? _cachedAuthProviders;

  bool get isAuthenticated => _isAuthenticated;
  bool get isPremium => _isPremium;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  String get subscriptionTier => _subscriptionTier;
  DateTime? get subscriptionExpiresAt => _subscriptionExpiresAt;
  bool get isInitialized => _isInitialized;

  /// Initialize authentication state
  /// Safe to call multiple times - will only initialize once
  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_isInitialized) {
      debugPrint('🔐 [BackendAuthService] Already initialized, skipping');
      return;
    }

    // If initialization is in progress, wait for it
    if (_isInitializing && _initializationFuture != null) {
      debugPrint('🔐 [BackendAuthService] Initialization in progress, waiting...');
      await _initializationFuture;
      return;
    }

    // Start initialization
    _isInitializing = true;
    _initializationFuture = _doInitialize();
    await _initializationFuture;
  }

  /// Internal initialization logic
  Future<void> _doInitialize() async {
    try {
      debugPrint('🔐 [BackendAuthService] Starting initialization...');

      // First, try to load cached auth state for instant UI (no network)
      await _loadCachedAuthState();

      // Check if we have a token
      final hasToken = await _apiService.hasToken();

      if (hasToken) {
        // If we have cached data and it's less than 5 minutes old, skip API call
        final prefs = await SharedPreferences.getInstance();
        final cachedTimestamp = prefs.getInt(_kCachedAuthTimestamp) ?? 0;
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
        final cacheMaxAge = 5 * 60 * 1000; // 5 minutes

        if (_userId != null && cacheAge < cacheMaxAge) {
          debugPrint('✅ [BackendAuthService] Using cached auth state (${cacheAge ~/ 1000}s old)');
          _isAuthenticated = true;
          _isInitialized = true;
          _isInitializing = false;
          notifyListeners();

          // Refresh in background (don't await)
          _refreshInBackground();
          return;
        }

        // Cache is stale or missing, fetch from API
        debugPrint('🔐 [BackendAuthService] Fetching fresh user info from API...');
        await refreshUserInfo();
      } else {
        debugPrint('🔐 [BackendAuthService] No token found, user not authenticated');
        _isAuthenticated = false;
      }

      _isInitialized = true;
      _isInitializing = false;
      debugPrint('✅ [BackendAuthService] Initialization complete');
    } catch (e) {
      debugPrint('⚠️ [BackendAuthService] Auth initialization error: $e');
      _isAuthenticated = false;
      _isInitialized = true;
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Load cached auth state from SharedPreferences
  Future<void> _loadCachedAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _userId = prefs.getString(_kCachedUserId);
      _userEmail = prefs.getString(_kCachedUserEmail);
      _isPremium = prefs.getBool(_kCachedIsPremium) ?? false;
      _subscriptionTier = prefs.getString(_kCachedSubscriptionTier) ?? 'free';

      final expiryString = prefs.getString(_kCachedSubscriptionExpiry);
      if (expiryString != null) {
        _subscriptionExpiresAt = DateTime.tryParse(expiryString);
      }

      if (_userId != null) {
        _isAuthenticated = true;
        debugPrint('🔐 [BackendAuthService] Loaded cached auth: $_userEmail');
      }
    } catch (e) {
      debugPrint('⚠️ [BackendAuthService] Failed to load cached auth: $e');
    }
  }

  /// Save auth state to SharedPreferences for instant startup
  Future<void> _cacheAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_userId != null) {
        await prefs.setString(_kCachedUserId, _userId!);
      }
      if (_userEmail != null) {
        await prefs.setString(_kCachedUserEmail, _userEmail!);
      }
      await prefs.setBool(_kCachedIsPremium, _isPremium);
      await prefs.setString(_kCachedSubscriptionTier, _subscriptionTier);
      if (_subscriptionExpiresAt != null) {
        await prefs.setString(_kCachedSubscriptionExpiry, _subscriptionExpiresAt!.toIso8601String());
      }
      await prefs.setInt(_kCachedAuthTimestamp, DateTime.now().millisecondsSinceEpoch);

      debugPrint('✅ [BackendAuthService] Auth state cached');
    } catch (e) {
      debugPrint('⚠️ [BackendAuthService] Failed to cache auth state: $e');
    }
  }

  /// Clear cached auth state (call on logout)
  Future<void> _clearCachedAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedUserId);
      await prefs.remove(_kCachedUserEmail);
      await prefs.remove(_kCachedIsPremium);
      await prefs.remove(_kCachedSubscriptionTier);
      await prefs.remove(_kCachedSubscriptionExpiry);
      await prefs.remove(_kCachedAuthTimestamp);
    } catch (e) {
      debugPrint('⚠️ [BackendAuthService] Failed to clear cached auth: $e');
    }
  }

  /// Refresh user info in background (fire and forget)
  void _refreshInBackground() {
    Future.microtask(() async {
      try {
        await refreshUserInfo();
        debugPrint('✅ [BackendAuthService] Background refresh complete');
      } catch (e) {
        debugPrint('⚠️ [BackendAuthService] Background refresh failed: $e');
      }
    });
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
      _isInitialized = false; // Allow re-initialization after logout

      // Clear cached auth state
      await _clearCachedAuthState();

      notifyListeners();
    }
  }

  /// Authenticate with Firebase token (Google Sign-In)
  Future<void> authenticateWithGoogle(String firebaseToken) async {
    try {
      debugPrint(
          '🔐 [BackendAuthService] Authenticating with Firebase token...');
      final response =
          await _apiService.authenticateWithFirebase(firebaseToken);
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

      // Clear auth providers cache so it refreshes next time
      clearAuthProvidersCache();

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

      // Clear auth providers cache so it refreshes next time
      clearAuthProvidersCache();

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to unlink Google account: $e');
    }
  }

  /// Get linked authentication providers
  /// Uses session cache to avoid repeated API calls
  Future<Map<String, dynamic>> getAuthProviders({bool forceRefresh = false}) async {
    // Return cached data if available (unless forced)
    if (!forceRefresh && _cachedAuthProviders != null) {
      debugPrint('⏭️ [BackendAuthService] Using cached auth providers');
      return _cachedAuthProviders!;
    }

    try {
      final response = await _apiService.getAuthProviders();
      _cachedAuthProviders = response;
      return response;
    } catch (e) {
      throw Exception('Failed to get auth providers: $e');
    }
  }

  /// Clear cached auth providers (call after linking/unlinking accounts)
  void clearAuthProvidersCache() {
    _cachedAuthProviders = null;
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

      // Cache the auth state for faster startup
      await _cacheAuthState();

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

      // Update cache
      await _cacheAuthState();

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
