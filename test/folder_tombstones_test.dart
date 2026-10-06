import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/drift_note_folder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/project_source.dart';

/// A folder deleted on this device is remembered until the server has it,
/// so other devices remove it too instead of bringing it back.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a deletion waits in the outbox until sent', () async {
    await FolderTombstones.add('u1', 'Work', DateTime.utc(2026, 10, 6, 9));
    await FolderTombstones.add('u2', 'Gym', DateTime.utc(2026, 10, 6, 10));

    final pending = await FolderTombstones.pending();
    expect(pending.map((t) => t['uuid']), ['u1', 'u2']);
    expect(pending.first['deleted_at'], '2026-10-06T09:00:00.000Z');

    await FolderTombstones.clear(['u1']);
    expect((await FolderTombstones.pending()).map((t) => t['uuid']), ['u2']);
  });

  test('deleting the same folder twice keeps one entry', () async {
    await FolderTombstones.add('u1', 'Work', DateTime.utc(2026, 10, 6, 9));
    await FolderTombstones.add('u1', 'Work', DateTime.utc(2026, 10, 6, 11));
    expect(await FolderTombstones.pending(), hasLength(1));
  });

  test('sync sends deletions and applies the ones made elsewhere', () {
    final sync = readProjectFile('lib/sync/folder_sync_service.dart');
    expect(sync, contains("'is_deleted': true"));
    expect(sync, contains('getAllFolders(includeDeleted: true)'));
    expect(sync, contains('DriftNoteFolderService.removeLocally'));
  });
}
