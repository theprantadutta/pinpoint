import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';

/// What the client does with each of the three answers a verification can give.
///
/// A purchase made while the backend could not reach Google is granted
/// PROVISIONALLY: premium unlocks on the device and the receipt is queued for
/// retry, because a user who has actually paid must never be locked out by a
/// backend outage. That rule was right, but the client could not tell the
/// difference between "I could not ask the store" and "the store says this
/// subscription is over" — both arrived as a bare `success: false`. So the
/// retry read a cancelled subscription as still-unconfirmed, returned early
/// from [SubscriptionManager.checkSubscriptionStatus] before the real status
/// fetch, and the self-granted premium survived every launch until its
/// locally-invented expiry. Up to a year of free premium that no cancellation,
/// refund or chargeback could remove.
///
/// The backend now sends a stable code with the failure, and these pin the
/// three outcomes apart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pendingKey = 'subscription_pending_verification';
  const yearly = 'pinpoint_premium_yearly';

  late FakeApiService api;

  setUpAll(() {
    // ApiService's `static final baseUrl` reads dotenv at construction.
    dotenv.loadFromString(
      envString: '''
API_BASE_URL_DEV=http://localhost:8000
API_BASE_URL_PROD=http://localhost:8000
GOOGLE_WEB_CLIENT_ID=test-client-id
''',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'device_id': 'test-device'});
    api = FakeApiService();
    SubscriptionManager().debugApiService = api;
    await SubscriptionManager().initialize();
  });

  /// Puts the device in the state a purchase-during-outage leaves it in:
  /// premium granted locally, receipt queued for retry.
  Future<void> grantProvisionally() async {
    api.verifyResponse = {
      'success': false,
      'message': 'Payment service unavailable',
      'code': 'PURCHASE_VERIFICATION_UNAVAILABLE',
    };

    final result = await SubscriptionManager().verifyPurchase(
      purchaseToken: 'token-1',
      productId: yearly,
      platform: 'android',
    );

    expect(result.isProvisional, isTrue,
        reason: 'the outage path must still unlock premium');
    expect(SubscriptionManager().isPremium, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(pendingKey), isNotNull,
        reason: 'the receipt must be queued for retry');
  }

  group('verifying a fresh purchase', () {
    test('an unreachable store grants premium provisionally', () async {
      await grantProvisionally();

      expect(SubscriptionManager().subscriptionTier, 'premium');
      // A yearly plan invents roughly a year of entitlement, which is exactly
      // how long the old bug lasted.
      expect(SubscriptionManager().expirationDate, isNotNull);
    });

    test('a store refusal grants nothing at all', () async {
      api.verifyResponse = {
        'success': false,
        'message': 'Subscription has expired',
        'code': 'SUBSCRIPTION_NOT_ACTIVE',
      };

      final result = await SubscriptionManager().verifyPurchase(
        purchaseToken: 'dead-token',
        productId: yearly,
        platform: 'android',
      );

      expect(result.isProvisional, isFalse);
      expect(result.isConfirmed, isFalse);
      expect(result.reason, PurchaseVerificationReasons.storeRejected);
      expect(SubscriptionManager().isPremium, isFalse,
          reason: 'the store said this purchase is not active');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(pendingKey), isNull,
          reason: 'retrying a refusal can only ever produce the same refusal');
    });

    test('a confirmed purchase is premium with no queued receipt', () async {
      api.verifyResponse = {
        'success': true,
        'is_premium': true,
        'tier': 'premium',
        'expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      };

      final result = await SubscriptionManager().verifyPurchase(
        purchaseToken: 'good-token',
        productId: yearly,
        platform: 'android',
      );

      expect(result.isConfirmed, isTrue);
      expect(SubscriptionManager().isPremium, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(pendingKey), isNull);
    });
  });

  group('retrying the queued receipt', () {
    test('a cancelled subscription withdraws the provisional premium',
        () async {
      // THE regression. Buy during an outage, then cancel in the store.
      await grantProvisionally();

      api.verifyResponse = {
        'success': false,
        'message': 'Subscription has expired',
        'code': 'SUBSCRIPTION_NOT_ACTIVE',
      };
      api.statusResponse = {'is_premium': false, 'tier': 'free'};

      await SubscriptionManager().checkSubscriptionStatus(forceRefresh: true);

      expect(SubscriptionManager().isPremium, isFalse,
          reason: 'cancelling in the store must be able to remove premium');
      expect(SubscriptionManager().subscriptionTier, 'free');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(pendingKey), isNull,
          reason: 'a refused receipt must not be retried forever — leaving it '
              'makes checkSubscriptionStatus skip the real status fetch');
    });

    test('the real device status is fetched after a withdrawal', () async {
      // Returning early is what let the stale grant survive. Once the receipt
      // is refused the backend, not the device, decides what happens next.
      await grantProvisionally();

      api.verifyResponse = {
        'success': false,
        'code': 'SUBSCRIPTION_NOT_ACTIVE',
        'message': 'Subscription has expired',
      };
      api.statusResponse = {'is_premium': false, 'tier': 'free'};
      api.statusCalls = 0;

      await SubscriptionManager().checkSubscriptionStatus(forceRefresh: true);

      expect(api.statusCalls, 1);
    });

    test('a still-unreachable backend keeps the provisional premium', () async {
      // The rule that must NOT regress: an outage may never lock out someone
      // who has actually paid.
      await grantProvisionally();

      api.verifyResponse = {
        'success': false,
        'message': 'Payment service unavailable',
        'code': 'PURCHASE_VERIFICATION_UNAVAILABLE',
      };
      api.statusCalls = 0;

      await SubscriptionManager().checkSubscriptionStatus(forceRefresh: true);

      expect(SubscriptionManager().isPremium, isTrue);
      expect(api.statusCalls, 0,
          reason: 'the device-status endpoint does not know about the purchase '
              'and would downgrade an entitlement the user paid for');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(pendingKey), isNotNull);
    });

    test('a response with no code is treated as transient', () async {
      // Forward compatibility: an older backend, or a proxy that drops the
      // field, must not revoke a paying user's entitlement.
      await grantProvisionally();

      api.verifyResponse = {'success': false, 'message': 'Verification failed'};

      await SubscriptionManager().checkSubscriptionStatus(forceRefresh: true);

      expect(SubscriptionManager().isPremium, isTrue);
    });

    test('an unrecognised code is treated as transient', () async {
      await grantProvisionally();

      api.verifyResponse = {
        'success': false,
        'code': 'SOME_FUTURE_CODE',
        'message': 'Verification failed',
      };

      await SubscriptionManager().checkSubscriptionStatus(forceRefresh: true);

      expect(SubscriptionManager().isPremium, isTrue,
          reason: 'a client that has not learned a code must hold the '
              'entitlement, not revoke it');
    });

    test('a retry that finally confirms clears the receipt and keeps premium',
        () async {
      await grantProvisionally();

      api.verifyResponse = {
        'success': true,
        'is_premium': true,
        'tier': 'premium',
        'expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      };
      // A confirmed retry hands control back to the status endpoint, which by
      // then knows about the purchase the backend has just recorded.
      api.statusResponse = {
        'is_premium': true,
        'tier': 'premium',
        'expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      };

      await SubscriptionManager().checkSubscriptionStatus(forceRefresh: true);

      expect(SubscriptionManager().isPremium, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(pendingKey), isNull);
    });
  });
}

/// Stands in for the [ApiService] singleton, whose private constructor rules
/// out subclassing. Only the two calls the verification flow makes are
/// implemented; anything else is a test bug and throws.
class FakeApiService implements ApiService {
  Map<String, dynamic> verifyResponse = {'success': true};
  Map<String, dynamic> statusResponse = {'is_premium': false, 'tier': 'free'};
  int verifyCalls = 0;
  int statusCalls = 0;

  /// The last payload sent, so a test can assert the receipt round-trips.
  Map<String, dynamic>? lastVerifyPayload;

  @override
  Future<Map<String, dynamic>> verifyPurchaseWithDevice({
    required String deviceId,
    required String purchaseToken,
    required String productId,
    String? userId,
    String platform = 'android',
  }) async {
    verifyCalls++;
    lastVerifyPayload = {
      'device_id': deviceId,
      'purchase_token': purchaseToken,
      'product_id': productId,
      'platform': platform,
    };
    // Decoded and re-encoded so a test mutating the map mid-flight cannot
    // change an answer already given.
    return jsonDecode(jsonEncode(verifyResponse)) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getSubscriptionStatusByDevice(
      String deviceId) async {
    statusCalls++;
    return jsonDecode(jsonEncode(statusResponse)) as Map<String, dynamic>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
