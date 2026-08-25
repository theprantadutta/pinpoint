import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/widgets/markdown_editor.dart';

/// Regression tests for the Fleather/Parchment document invariant.
///
/// Parchment requires a document delta to end with a line break, but it only
/// checks that with an `assert` inside `ParchmentDocument._loadDocument`.
/// Asserts are stripped from release builds, so an un-terminated delta builds a
/// malformed node tree in production and the next insert near the end of it
/// crashes in `ContainerNode.insert` with "Null check operator used on a null
/// value" — reported from `updateEditingValueWithDeltas`, i.e. as soon as the
/// user types.
///
/// These tests run in debug, where the assert DOES fire, so the same defect is
/// observable here as content loss instead of a crash.
void main() {
  group('createControllerFromMarkdown', () {
    test('keeps plain-text content and terminates the document', () {
      final controller = MarkdownEditor.createControllerFromMarkdown('hello');

      expect(controller.document.toPlainText(), 'hello\n');
      expect(
        MarkdownEditor.getPlainText(controller).trim(),
        'hello',
        reason: 'Old notes stored as plain text must survive being opened.',
      );
    });

    test('round-trips a stored JSON delta', () {
      final source = MarkdownEditor.createControllerFromMarkdown('round trip');
      final stored = MarkdownEditor.controllerToMarkdown(source);

      final reloaded = MarkdownEditor.createControllerFromMarkdown(stored);

      expect(reloaded.document.toPlainText(), 'round trip\n');
    });

    test('content that is valid JSON but not a delta is kept as text', () {
      // These previously fell through to an empty controller, which wiped the
      // note on the next save.
      for (final content in const ['42', 'true', '{"a":1}', '"quoted"']) {
        final controller =
            MarkdownEditor.createControllerFromMarkdown(content);
        expect(
          controller.document.toPlainText().trim(),
          content,
          reason: 'Content "$content" must not be discarded.',
        );
      }
    });

    test('a delta array without a trailing newline is repaired, not dropped',
        () {
      // This is the exact shape that produced the release crash.
      final malformed = jsonEncode([
        {'insert': 'no trailing break'}
      ]);

      final controller =
          MarkdownEditor.createControllerFromMarkdown(malformed);

      expect(controller.document.toPlainText(), 'no trailing break\n');
    });

    test('every produced document ends with a line break', () {
      for (final content in const [
        'plain',
        'multi\nline',
        '42',
        '[]',
        '[{"insert":"x"}]',
        '[{"insert":"x\\n"}]',
        'not json {',
      ]) {
        final controller =
            MarkdownEditor.createControllerFromMarkdown(content);
        expect(
          controller.document.toPlainText().endsWith('\n'),
          isTrue,
          reason: 'Document built from "$content" must end with a line break, '
              'or typing at the end of it crashes in release.',
        );
      }
    });

    test('the repaired document accepts an insert at its end', () {
      // The crash itself: ContainerNode.insert walking off the end of a
      // malformed tree. Inserting at length - 1 is what the keyboard does.
      final controller = MarkdownEditor.createControllerFromMarkdown('abc');
      final document = controller.document;

      expect(
        () => document.insert(document.length - 1, 'def'),
        returnsNormally,
      );
      expect(document.toPlainText(), 'abcdef\n');
    });

    test('empty content still yields a usable document', () {
      final controller = MarkdownEditor.createControllerFromMarkdown('');

      expect(controller.document.toPlainText(), '\n');
      expect(
        () => controller.document.insert(0, 'x'),
        returnsNormally,
      );
    });
  });
}
