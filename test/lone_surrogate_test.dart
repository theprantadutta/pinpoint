import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/util/utf16.dart';
import 'package:pinpoint/widgets/markdown_editor.dart';

/// Crashlytics, 4.3.2 (Nov 2026): "string is not well-formed UTF-16" from
/// fleather's RenderParagraphProxy.performLayout, 11 times for one user. Half
/// an emoji in a note makes every layout of it throw, so the note can never be
/// opened again.
void main() {
  const smile = '\u{1F600}'; // Two code units: D83D DE00.
  const high = '\uD83D';
  const low = '\uDE00';

  group('withoutLoneSurrogates', () {
    test('keeps well-formed text, emoji included', () {
      const s = 'Tram 28 $smile at sunset';
      expect(indexOfLoneSurrogate(s), -1);
      expect(identical(withoutLoneSurrogates(s), s), isTrue);
    });

    test('drops a half emoji wherever it is', () {
      expect(withoutLoneSurrogates('a${high}b'), 'ab');
      expect(withoutLoneSurrogates('a${low}b'), 'ab');
      expect(withoutLoneSurrogates('end$high'), 'end');
      expect(withoutLoneSurrogates('$low$smile$high'), smile);
    });
  });

  test('a stored note holding half an emoji opens without it', () {
    final stored = jsonEncode([
      {'insert': 'Groceries $high\n'},
    ]);

    final controller = MarkdownEditor.createControllerFromMarkdown(stored);

    final text = controller.document.toPlainText();
    expect(indexOfLoneSurrogate(text), -1);
    expect(text, 'Groceries \n');
  });

  test('deleting half an emoji while editing removes the other half', () {
    final controller = FleatherController(
        document: ParchmentDocument.fromDelta(Delta()..insert('a${smile}b\n')));
    MarkdownEditor.guardAgainstLoneSurrogates(controller);

    // What a keyboard that deletes one code unit does.
    controller.replaceText(2, 1, '');

    expect(controller.document.toPlainText(), 'ab\n');
  });

  test('inserting half an emoji is ignored', () {
    final controller = FleatherController();
    MarkdownEditor.guardAgainstLoneSurrogates(controller);

    controller.replaceText(0, 0, 'hi$high');

    expect(controller.document.toPlainText(), 'hi\n');
  });
}
