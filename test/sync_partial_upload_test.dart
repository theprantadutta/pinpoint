import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/sync/api_sync_service.dart';
import 'package:pinpoint/sync/sync_service.dart';

import 'support/project_source.dart';

/// A free account at its 50-note cap: the server stores edits, deletions and
/// as many new notes as fit, and holds the rest back. Only what it stored may
/// be marked synced on the device — anything else would never upload again.
void main() {
  group('acceptedUuids', () {
    test('marks only the notes the server echoed back', () {
      final response = {
        'updated_notes': [
          {'client_note_uuid': 'kept'},
          {'client_note_uuid': 'edited'},
        ],
        'rejected_uuids': ['extra'],
        'limit_exceeded': true,
      };

      expect(acceptedUuids(response, ['kept', 'edited', 'extra']), {'kept', 'edited'});
    });

    test('a response without updated_notes confirms nothing', () {
      expect(acceptedUuids({'message': 'Sync failed'}, ['a', 'b']), isEmpty);
    });

    test('an all-or-nothing refusal confirms nothing', () {
      final response = {'synced_count': 0, 'updated_notes': [], 'limit_exceeded': true};
      expect(acceptedUuids(response, ['a']), isEmpty);
    });

    test('ignores uuids the device did not send', () {
      final response = {
        'updated_notes': [
          {'client_note_uuid': 'a'},
          {'client_note_uuid': 'stranger'},
        ],
      };
      expect(acceptedUuids(response, ['a']), {'a'});
    });
  });

  test('a sync with held-back notes still succeeds and says so', () {
    final result = SyncResult(success: true, message: 'ok', notesOverLimit: 2);
    expect(result.success, isTrue);
    expect(result.limitReached, isTrue);
    expect(SyncResult(success: true, message: 'ok').limitReached, isFalse);
  });

  test('the client no longer blocks the whole sync at the free cap', () {
    final source = readProjectFile('lib/sync/sync_manager.dart');
    expect(source, isNot(contains('_checkSyncLimits')));
    expect(readProjectFile('lib/services/api_service.dart'), contains("'allow_partial': true"));
  });
}
