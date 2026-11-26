import 'package:flutter_test/flutter_test.dart';

import 'support/project_source.dart';

/// Crashlytics, 4.4.0 (Nov 2026): a recording Android could not open
/// (AndroidAudioError, MEDIA_ERROR_UNKNOWN) arrived as an error on each of
/// the editor's audio player streams; listeners without onError made every
/// one an uncaught error, recorded as a fatal crash (12 in a day, 1 user).
void main() {
  final editor = readProjectFile('lib/screens/create_note_screen_v2.dart');

  test('every audio player stream listener handles errors', () {
    final listens =
        RegExp(r'_audioPlayer\.on\w+\.listen\(').allMatches(editor).toList();
    expect(listens, isNotEmpty);
    for (final m in listens) {
      // The listener's closing `}, onError: ...);` follows within its body.
      final rest = editor.substring(m.start, m.start + 400);
      expect(rest, contains('onError: _onPlayerError'),
          reason: 'Unguarded listener at offset ${m.start}');
    }
  });

  test('playing does not add another completion listener each time', () {
    expect(
        RegExp(r'_audioPlayer\.onPlayerComplete\.listen').allMatches(editor),
        hasLength(1));
  });
}
