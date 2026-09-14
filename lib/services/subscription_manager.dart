import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/api_service.dart';

/// How a purchase verification actually ended.
///
/// The distinction matters for revenue reporting: only [confirmed] means the
/// backend validated the purchase against the store. [provisional] means the
/// store charged the user but the backend could not confirm it, so premium was
/// unlocked locally and the purchase was stored for retry — an entitlement, not
/// a confirmed sale.
enum PurchaseVerificationOutcome {
  /// The backend validated the purchase. This — and only this — is a sale.
  confirmed,

  /// Premium was granted locally pending a later backend confirmation.
  provisional,

  /// Verification could not be attempted at all; nothing was granted.
  failed,
}

/// Short, bounded codes explaining a non-[PurchaseVerificationOutcome.confirmed]
/// result. Safe for analytics: never carries a server message or a token.
abstract final class PurchaseVerificationReasons {
  /// No device id, so the API call could not even be made.
  static const String noDeviceId = 'no_device_id';

  /// The backend answered, but did not confirm the purchase.
  static const String backendRejected = 'backend_rejected';

  /// The backend could not be reached (network, timeout, parse failure).
  static const String backendUnreachable = 'backend_unreachable';

  /// The STORE says the purchase is not active — cancelled, expired, refunded
  /// or revoked. Authoritative, and the opposite of the two above: it grants
  /// nothing and withdraws anything granted provisionally.
  static const String storeRejected = 'store_rejected';
}

/// Stable codes the backend sends alongside a failed verification.
///
/// A bare `success: false` cannot distinguish "the store says this
/// subscription is over" from "I could not reach the store", and the client
/// has to do opposite things in those two cases. Conflating them is what made
/// a provisional entitlement impossible to revoke: a purchase made during a
/// backend outage stayed premium for the full locally-invented expiry, and
/// cancelling in the store could not touch it.
///
/// Kept in step with `ErrorCodes` on the backend; an unrecognised code is
/// treated as transient, which is the safe default for a paying user.
abstract final class PurchaseVerificationCodes {
  /// Authoritative: the store confirmed the purchase is not active.
  static const String subscriptionNotActive = 'SUBSCRIPTION_NOT_ACTIVE';

  /// Transient: the store could not be reached or did not answer.
  static const String verificationUnavailable =
      'PURCHASE_VERIFICATION_UNAVAILABLE';
}

/// The outcome of [SubscriptionManager.verifyPurchase].
///
/// Replaces the old bare `bool`, which returned true for both a confirmed sale
/// and a provisional grant and so made `purchase_verified` over-count.
class PurchaseVerificationResult {
  const PurchaseVerificationResult(this.outcome, {this.reason});

  const PurchaseVerificationResult.confirmed()
      : outcome = PurchaseVerificationOutcome.confirmed,
        reason = null;

  const PurchaseVerificationResult.provisional(String this.reason)
      : outcome = PurchaseVerificationOutcome.provisional;

  const PurchaseVerificationResult.failed(String this.reason)
      : outcome = PurchaseVerificationOutcome.failed;

  final PurchaseVerificationOutcome outcome;

  /// One of [PurchaseVerificationReasons]; null when [isConfirmed].
  final String? reason;

  bool get isConfirmed => outcome == PurchaseVerificationOutcome.confirmed;
  bool get isProvisional => outcome == PurchaseVerificationOutcome.provisional;

  /// Whether the user should be treated as premium right now. True for both a
  /// confirmed and a provisional outcome — a paying user is never locked out
  /// just because the backend is having a bad day.
  bool get grantsEntitlement => outcome != PurchaseVerificationOutcome.failed;
}

/// Manages subscription status without requiring user authentication
/// Uses device ID for identification and local storage for offline access
class SubscriptionManager extends ChangeNotifier {
  // Singleton pattern
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  ApiService _apiService = ApiService();

  /// Swap in a fake backend. TESTS ONLY.
  ///
  /// `ApiService` is a singleton behind a private constructor, so this is the
  /// only way to drive the three verification outcomes — confirmed, transient,
  /// and the store's own refusal — without a live server.
  @visibleForTesting
  set debugApiService(ApiService api) => _apiService = api;

  /// Null-safe because this singleton can run before (or without) the service
  /// locator being populated — e.g. in tests.
  AnalyticsFacade? get _analytics =>
      getIt.isRegistered<AnalyticsFacade>() ? getIt<AnalyticsFacade>() : null;

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
  Future<PurchaseVerificationResult> verifyPurchase({
    required String purchaseToken,
    required String productId,
    String? userId,
    String platform = 'android',
  }) async {
    debugPrint('🔄 verifyPurchase called: productId=$productId, userId=$userId');

    if (_deviceId == null) {
      debugPrint('❌ Device ID not available - cannot verify purchase');
      return const PurchaseVerificationResult.failed(
          PurchaseVerificationReasons.noDeviceId);
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
        return const PurchaseVerificationResult.confirmed();
      }

      // The store itself says this purchase is not active — cancelled,
      // expired, refunded or revoked. That is an answer, not a failure to get
      // one, so grant nothing and keep no receipt to retry. Anything already
      // granted is corrected by the status fetch that follows.
      if (_storeRejected(response)) {
        debugPrint('❌ Store reports the purchase is not active — no entitlement');
        await _clearPendingVerification();
        return const PurchaseVerificationResult.failed(
            PurchaseVerificationReasons.storeRejected);
      }

      // Otherwise the store already charged the user and the backend just
      // couldn't confirm it (service unavailable, misconfiguration, ...).
      // Never leave a paid user locked out: grant premium provisionally and
      // keep retrying verification in the background until it confirms.
      debugPrint('⚠️ API returned success=false: ${response['message']} '
          '— granting provisional entitlement');
      await _grantProvisionalEntitlement(
        purchaseToken: purchaseToken,
        productId: productId,
        userId: userId,
        platform: platform,
      );
      return const PurchaseVerificationResult.provisional(
          PurchaseVerificationReasons.backendRejected);
    } catch (e, stackTrace) {
      debugPrint('⚠️ Purchase verification error: $e — granting provisional entitlement');
      debugPrint('Stack trace: $stackTrace');
      await _grantProvisionalEntitlement(
        purchaseToken: purchaseToken,
        productId: productId,
        userId: userId,
        platform: platform,
      );
      return const PurchaseVerificationResult.provisional(
          PurchaseVerificationReasons.backendUnreachable);
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

        // The sale is only now confirmed. Without this the funnel would swing
        // from over-counting (the old bool) to under-counting: every purchase
        // that went out provisionally would never produce a conversion event.
        // `source: retry` marks it as a deferred confirmation rather than one
        // observed live on the purchase stream.
        _analytics?.trackPurchaseVerified(
          productId: pending['productId'] as String,
          platform: (pending['platform'] as String?) ?? 'android',
          source: 'retry',
        );
        return false;
      }
      // The store has now answered, and the answer is no. Drop the receipt and
      // the entitlement it was holding open, then return false so the caller
      // goes on to fetch the real device status — the backend, not this
      // device's optimistic guess, decides what happens next.
      //
      // THE bug this closes: every non-success looked identical here, so a
      // cancelled subscription read as "still unconfirmed", the caller
      // returned early, and the self-granted premium survived every launch
      // until its invented expiry — up to a year of free premium that no
      // cancellation, refund or chargeback could remove.
      if (_storeRejected(response)) {
        debugPrint('❌ Store reports the pending purchase is not active '
            '— withdrawing the provisional entitlement');
        await _withdrawProvisionalEntitlement();
        return false;
      }

      debugPrint('⏳ Pending verification still unconfirmed: ${response['message']}');
    } catch (e) {
      // No answer at all. Hold the entitlement and try again next time.
      debugPrint('⏳ Pending verification retry failed: $e');
    }
    return true;
  }

  /// Whether [response] is the store's own verdict that the purchase is dead,
  /// as opposed to the backend being unable to ask.
  ///
  /// An unknown or missing code is NOT treated as a rejection: a client that
  /// has not learned a new code must keep a paying user's entitlement rather
  /// than revoke it on a response it does not understand.
  static bool _storeRejected(Map<String, dynamic> response) =>
      response['code'] == PurchaseVerificationCodes.subscriptionNotActive;

  /// Undo a provisional grant the store has since disowned.
  ///
  /// Clears the queued receipt as well — retrying it can only ever produce the
  /// same refusal, and leaving it would make [checkSubscriptionStatus] skip
  /// the real status fetch forever.
  Future<void> _withdrawProvisionalEntitlement() async {
    _isPremium = false;
    _subscriptionTier = 'free';
    _subscriptionType = null;
    _subscriptionExpiresAt = null;
    _isInGracePeriod = false;
    _gracePeriodEndsAt = null;

    await _clearPendingVerification();
    await _saveLocalSubscriptionStatus();
    notifyListeners();
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
