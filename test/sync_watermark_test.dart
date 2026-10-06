import 'package:flutter_test/flutter_test.dart';

import 'support/project_source.dart';

/// The last-sync time decides what the next download asks for, so it must
/// only move once everything before it is on this device. It used to advance
/// after upload-only syncs and after downloads where notes failed to decrypt,
/// and those notes were then never fetched again.
void main() {
  final sync = readProjectFile('lib/sync/api_sync_service.dart');

  test('only the download step advances the last-sync time', () {
    final assigned = RegExp(r'_lastSyncTime = ([^;]+);')
        .allMatches(sync)
        .map((m) => m.group(1)!)
        .toSet();
    // Loaded from storage, reset to 0, or the moment a download began.
    expect(assigned, {'prefs.getInt(_lastSyncTimeKey) ?? 0', '0', 'requestedAt'});
  });

  test('a download with failed notes keeps the old time', () {
    expect(sync, contains('if (failedCount == 0) {\n        _lastSyncTime = requestedAt;'));
    expect(sync, contains('final requestedAt = DateTime.now().millisecondsSinceEpoch;'));
  });
}
