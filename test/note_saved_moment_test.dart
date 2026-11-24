import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/note_saved_moment.dart';

import 'support/project_source.dart';

/// A24, Nov 2026: the router's change notification fired while the closing
/// editor was still the top route, so the shell never re-checked and the
/// notification sheet never appeared after a saved note. The editor now
/// signals from dispose, once its route is gone.
void main() {
  test('editorWasClosed ticks after the current microtask', () async {
    final before = NoteSavedMoment.editorClosed.value;
    NoteSavedMoment.editorWasClosed();
    // Deferred: never notifies while the tree is being finalised.
    expect(NoteSavedMoment.editorClosed.value, before);
    await Future<void>.delayed(Duration.zero);
    expect(NoteSavedMoment.editorClosed.value, before + 1);
  });

  test('the full-screen editor signals on dispose and the shell listens', () {
    final editor = readProjectFile('lib/screens/create_note_screen_v2.dart');
    expect(
        editor,
        contains('void dispose() {\n'
            '    if (!widget.embedded) NoteSavedMoment.editorWasClosed();'));
    final shell = readProjectFile(
        'lib/navigation/bottom-navigation/bottom_navigation_layout.dart');
    expect(shell,
        contains('NoteSavedMoment.editorClosed.addListener(_maybeFollowUp)'));
    expect(shell,
        contains('NoteSavedMoment.editorClosed.removeListener(_maybeFollowUp)'));
  });
}
