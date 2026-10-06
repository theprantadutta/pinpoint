import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/pending_usage.dart';

import 'support/project_source.dart';

/// OCR scans and exports made offline are queued for the account that made
/// them and replayed, rather than erased by the next stats fetch.
void main() {
  const a = PendingUsage(owner: 'acct-a', period: '2026-10', ocr: 2, exports: 1);

  test('a fetch adds what the server has not heard of', () {
    expect(PendingUsage.merge(5, 2), 7);
    expect(PendingUsage.merge(5, 0), 5);
    expect(PendingUsage.merge(5, -1), 5);
  });

  test('usage is replayed only to its account, within its month', () {
    expect(a.appliesTo('acct-a', '2026-10'), isTrue);
    expect(a.appliesTo('acct-b', '2026-10'), isFalse);
    expect(a.appliesTo(null, '2026-10'), isFalse, reason: 'guests have no server counter');
    expect(a.appliesTo('acct-a', '2026-11'), isFalse, reason: 'last month counts toward nothing');
  });

  test('a new account or month starts its own queue', () {
    expect(a.forScope('acct-a', '2026-10'), same(a));
    final b = a.forScope('acct-b', '2026-10');
    expect([b.owner, b.ocr, b.exports], ['acct-b', 0, 0]);
    expect(a.forScope('acct-a', '2026-11').isEmpty, isTrue);
  });

  test('survives a round trip, and ignores garbage', () {
    final back = PendingUsage.decode(a.encode())!;
    expect([back.owner, back.period, back.ocr, back.exports], ['acct-a', '2026-10', 2, 1]);
    expect(PendingUsage.decode(null), isNull);
    expect(PendingUsage.decode('not json'), isNull);
  });

  test('wired: fetch replays first, merges, and sign-out keeps the queue', () {
    final premium = readProjectFile('lib/services/premium_service.dart');
    expect(premium, contains('await flushPendingUsage();\n      final apiService = ApiService();'));
    expect(premium, contains('PendingUsage.merge(ocrScans['));
    expect(premium, contains('PendingUsage.merge(exports['));
    expect(readProjectFile('lib/services/logout_service.dart'), contains('PendingUsage.prefsKey'));
    expect(readProjectFile('lib/sync/sync_manager.dart'), contains('flushPendingUsage()'),
        reason: 'a sync reports offline usage even while stats are fresh');
    expect(readProjectFile('lib/sync/api_sync_service.dart'),
        contains("applyUsageFromSync(response['usage'])"),
        reason: 'the plan card takes the counts returned with each note sync');
  });
}
