import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/premium_service.dart';

import 'support/project_source.dart';

/// Free OCR and export quotas reset with the server's UTC month, and the
/// check runs on every read rather than only at start-up.
void main() {
  test('the quota month is the UTC month', () {
    expect(PremiumService.quotaPeriodOf(DateTime.utc(2026, 10, 31, 23, 59)), '2026-10');
    expect(PremiumService.quotaPeriodOf(DateTime.utc(2026, 11, 1)), '2026-11');
    // 1 Nov 03:00 in Dhaka (UTC+6) is still October in UTC.
    expect(PremiumService.quotaPeriodOf(DateTime.utc(2026, 10, 31, 21)), '2026-10');
    expect(PremiumService.quotaPeriodOf(DateTime.utc(2027, 1, 1)), '2027-01');
  });

  test('every read checks for a new month', () {
    final source = readProjectFile('lib/services/premium_service.dart');
    for (final getter in ['int getOcrScansThisMonth() {', 'int getExportsThisMonth() {']) {
      final body = source.substring(source.indexOf(getter), source.indexOf(getter) + 120);
      expect(body, contains('_rollQuotaPeriodIfNeeded()'), reason: getter);
    }
  });
}
