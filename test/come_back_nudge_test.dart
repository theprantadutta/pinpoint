import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/come_back_nudge.dart';

void main() {
  test('it fires at 10:00 two days later, across a month end', () {
    expect(ComeBackNudge.fireTime(DateTime(2026, 11, 5, 21, 30)),
        DateTime(2026, 11, 7, 10));
    expect(ComeBackNudge.fireTime(DateTime(2026, 12, 31, 8)),
        DateTime(2027, 1, 2, 10));
  });

  test('coming back the same evening does not count, the next day does', () {
    final asked = DateTime(2026, 11, 5, 9);

    expect(ComeBackNudge.hasReturned(asked, DateTime(2026, 11, 5, 18)), isFalse);
    expect(ComeBackNudge.hasReturned(asked, DateTime(2026, 11, 6, 9)), isTrue);
  });
}
