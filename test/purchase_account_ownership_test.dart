import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/services/api_service.dart';
import 'package:pinpoint/services/subscription_manager.dart';
import 'package:pinpoint/services/subscription_service.dart';

import 'support/analytics_recorder.dart';
import 'support/fake_iap_client.dart';

/// A purchase belongs to the Pinpoint account that bought it.
///
/// The backend refuses a restore on any other account
/// (`PURCHASE_OWNED_BY_ANOTHER_ACCOUNT`) and refuses a signed-out caller
/// (`ANONYMOUS_ACCOUNT_PURCHASE_BLOCKED`). These pin what the app does with
/// each: what it grants, what it acknowledges with the store, and what it
/// tells the user.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const monthly = SubscriptionService.premiumMonthly;
  const accountId = '00000000-0000-4000-8000-000000000001';

  late FakeIapClient fake;
  late _FakeApi api;
  late RecordingAnalyticsFacade analytics;
  late List<PurchaseNotice> notices;
  StreamSubscription<PurchaseNotice>? noticeSub;

  setUpAll(() {
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
    api = _FakeApi();
    SubscriptionManager().debugApiService = api;
    await SubscriptionManager().initialize();

    fake = FakeIapClient(knownProductIds: SubscriptionService.productIds);
    analytics = RecordingAnalyticsFacade();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    getIt.registerSingleton<AnalyticsFacade>(analytics);

    SubscriptionService().resetForTesting();
    SubscriptionService().debugIapClient = fake;
    notices = <PurchaseNotice>[];
    noticeSub = SubscriptionService().notices.listen(notices.add);
  });

  tearDown(() async {
    await noticeSub?.cancel();
    SubscriptionService().resetForTesting();
    if (getIt.isRegistered<AnalyticsFacade>()) {
      getIt.unregister<AnalyticsFacade>();
    }
    await fake.close();
  });

  Future<int> restore() async {
    var restored = -1;
    await SubscriptionService().restorePurchases(
      onComplete: (count, _) => restored = count,
    );
    // Notices are delivered asynchronously on a broadcast stream.
    await Future<void>.delayed(Duration.zero);
    return restored;
  }

  test('a signed-out user cannot open the billing sheet', () async {
    await SubscriptionService.initialize();

    final launched = await SubscriptionService().purchase(monthly);
    await Future<void>.delayed(Duration.zero);

    expect(launched, isFalse);
    expect(fake.requestedPurchases, isEmpty);
    expect(notices, [PurchaseNotice.signInRequired]);
    expect(analytics.one('checkout_launch_failed').params['reason'],
        'sign_in_required');
  });

  test('a purchase owned by another account is acknowledged but grants nothing',
      () async {
    SubscriptionService().debugAccountId = accountId;
    await SubscriptionService.initialize();
    fake.owned = [fakePurchase(productId: monthly, purchaseId: 'gpa-1')];
    api.verifyResponse = {
      'success': false,
      'message': 'This purchase belongs to another Pinpoint account',
      'code': 'PURCHASE_OWNED_BY_ANOTHER_ACCOUNT',
    };

    final restored = await restore();

    expect(restored, 0);
    expect(SubscriptionManager().isPremium, isFalse);
    expect(notices, contains(PurchaseNotice.ownedByAnotherAccount));
    expect(fake.finishedPurchaseIds, contains('gpa-1'),
        reason: 'Leaving it unacknowledged would have Play refund the '
            'account that really bought it.');
  });

  test('a purchase that needs sign-in is kept, not finished', () async {
    SubscriptionService().debugAccountId = accountId;
    await SubscriptionService.initialize();
    fake.owned = [fakeIosPurchase(productId: monthly, transactionId: 'txn-9')];
    api.verifyResponse = {
      'success': false,
      'message': 'Sign in to use purchases',
      'code': 'ANONYMOUS_ACCOUNT_PURCHASE_BLOCKED',
    };

    final restored = await restore();

    expect(restored, 0);
    expect(SubscriptionManager().isPremium, isFalse);
    expect(notices, contains(PurchaseNotice.signInRequired));
    expect(fake.finishedPurchaseIds, isNot(contains('txn-9')),
        reason: 'It must still be there to verify once the user signs in.');
  });

  test('a restore counts only what this account was granted', () async {
    SubscriptionService().debugAccountId = accountId;
    await SubscriptionService.initialize();
    fake.owned = [fakePurchase(productId: monthly, purchaseId: 'gpa-2')];
    api.verifyResponse = {
      'success': true,
      'is_premium': true,
      'tier': 'premium',
      'expires_at':
          DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    };

    expect(await restore(), 1);
    expect(notices, isEmpty);
  });
}

class _FakeApi implements ApiService {
  Map<String, dynamic> verifyResponse = {'success': true};

  @override
  Future<bool> hasToken() async => false;

  @override
  Future<Map<String, dynamic>> verifyPurchaseWithDevice({
    required String deviceId,
    required String purchaseToken,
    required String productId,
    String? userId,
    String platform = 'android',
  }) async =>
      jsonDecode(jsonEncode(verifyResponse)) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> getSubscriptionStatusByDevice(
          String deviceId) async =>
      {'is_premium': false, 'tier': 'free'};

  @override
  Future<Map<String, dynamic>> getSubscriptionStatus() async =>
      {'is_premium': false, 'tier': 'free'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
