import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/util/server_time.dart';

void main() {
  final instant = DateTime.utc(2026, 10, 5, 12);

  test('a zone-less server timestamp is UTC, not local', () {
    expect(parseServerUtc('2026-10-05T12:00:00').toUtc(), instant);
    expect(parseServerUtc('2026-10-05T12:00:00.123456').toUtc(),
        DateTime.utc(2026, 10, 5, 12, 0, 0, 123, 456));
  });

  test('explicit zones are honoured', () {
    expect(parseServerUtc('2026-10-05T12:00:00Z').toUtc(), instant);
    expect(parseServerUtc('2026-10-05T18:00:00+06:00').toUtc(), instant);
    expect(parseServerUtc('2026-10-05T07:00:00-0500').toUtc(), instant);
  });

  test('results are in local time for display and scheduling', () {
    expect(parseServerUtc('2026-10-05T12:00:00Z').isUtc, isFalse);
  });
}
