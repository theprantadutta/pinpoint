import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/subscription_manager.dart';

import 'support/project_source.dart';

/// Purchases must belong to one install, and Pro must follow the account in
/// both directions: on at sign-in, off at sign-out.
void main() {
  group('legacy Android device ids', () {
    test('a firmware build number is recognised as the old shared id', () {
      expect(SubscriptionManager.isLegacyAndroidDeviceId('BP4A.251205.006'), isTrue);
      expect(SubscriptionManager.isLegacyAndroidDeviceId('UP1A.231005.007'), isTrue);
    });

    test('current per-install ids and the numeric fallback are left alone', () {
      expect(SubscriptionManager.isLegacyAndroidDeviceId('android-6f1c1f3e-0000-4000-8000-000000000001'), isFalse);
      expect(SubscriptionManager.isLegacyAndroidDeviceId('1728123456789-12345'), isFalse);
    });
  });

  test('signing in or out re-reads the entitlement', () {
    final auth = readProjectFile('lib/services/backend_auth_service.dart');
    expect(auth, contains('SubscriptionManager().onAccountChanged()'));
  });

  test('device-status timestamps are read as UTC', () {
    final manager = readProjectFile('lib/services/subscription_manager.dart');
    expect(manager, isNot(contains("DateTime.parse(status['expires_at'])")));
  });
}
