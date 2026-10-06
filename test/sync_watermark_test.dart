import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/sync/api_sync_service.dart';

import 'support/project_source.dart';

/// The last-sync point decides what the next download asks for, so it must
/// only move once everything before it is on this device, and it is kept in
/// the server's clock. It used to advance after upload-only syncs and after
/// downloads where notes failed to decrypt, and was taken from this device's
/// clock, compared against edit times sent in local time with no zone.
void main() {
  final sync = readProjectFile('lib/sync/api_sync_service.dart');

  test('only a complete download moves the sync point', () {
    final assigned = RegExp(r'_lastSyncTime = ([^;]+);')
        .allMatches(sync)
        .map((m) => m.group(1)!)
        .toSet();
    // Loaded from storage, reset to 0, or set by a complete download.
    expect(assigned, {
      'prefs.getInt(_lastSyncTimeKey) ?? 0',
      '0',
      'nextSyncPoint(maxServerMs, requestedAt)',
    });
    expect(sync, contains('if (failedCount == 0) {\n        _lastSyncTime = nextSyncPoint('));
  });

  test('the sync point is in server time, less a margin', () {
    expect(nextSyncPoint(1_800_000_000_000, 42), 1_800_000_000_000 - syncPointMarginMs);
    expect(nextSyncPoint(null, 42), 42, reason: 'a server without server_updated_ms');
  });

  test('a note edit time is read from inside the note, in either format', () {
    // Current clients: UTC with a Z.
    final utc = editedAt({'updatedAt': '2026-10-06T05:49:47.000Z'}, '2026-10-06T05:49:47');
    expect(utc.isUtc, isTrue);
    expect(utc, DateTime.utc(2026, 10, 6, 5, 49, 47));
    // Older clients: local time, no zone — taken as local, as written.
    final local = editedAt({'updatedAt': '2026-10-06T11:49:47.000'}, '2026-10-06T11:49:47');
    expect(local, DateTime(2026, 10, 6, 11, 49, 47));
    // Nothing inside: the server's copy.
    expect(editedAt({}, '2026-10-06T11:49:47'), DateTime(2026, 10, 6, 11, 49, 47));
  });

  test('note times are sent in UTC', () {
    expect(RegExp(r"'(createdAt|updatedAt|recordedAt|reminderTime)': note\.\w+\??\.toIso8601String\(\)")
        .hasMatch(sync), isFalse);
    expect(sync, contains("'updatedAt': note.updatedAt.toUtc().toIso8601String(),"));
  });
}
