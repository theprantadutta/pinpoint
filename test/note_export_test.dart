import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parchment/parchment.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pinpoint/components/create_note_screen/note_export_actions.dart';
import 'package:share_plus/share_plus.dart';

/// Exports are built from the editor's document, not its stored JSON: real
/// Markdown, and a PDF that flows over pages with its formatting intact.
void main() {
  ParchmentDocument sample() => ParchmentDocument.fromDelta(Delta()
    ..insert('Intro')
    ..insert('\n', {'heading': 1})
    ..insert('Hook with a ')
    ..insert('question', {'b': true})
    ..insert('\n', {'block': 'ul'})
    ..insert('Thesis in ')
    ..insert('one', {'i': true})
    ..insert(' line')
    ..insert('\n', {'block': 'ul'})
    ..insert('Buy milk')
    ..insert('\n', {'block': 'cl'})
    ..insert('Bread')
    ..insert('\n', {'block': 'cl', 'checked': true})
    ..insert('Plain paragraph.\n'));

  test('Markdown export is Markdown, not the editor JSON', () {
    final md = NoteExportActions.markdownFor('Essay', sample(), exportedLine: 'Exported from Pinpoint');

    expect(md, isNot(contains('"insert"')));
    expect(md, startsWith('# Essay'));
    expect(md, contains('# Intro'));
    expect(md, contains('- Hook with a **question**'));
    expect(md, contains('- [ ] Buy milk'));
    expect(md, contains('- [X] Bread'));
    expect(md, contains('Plain paragraph.'));
  });

  test('a long note flows over several PDF pages', () async {
    final delta = Delta();
    for (var i = 1; i <= 220; i++) {
      delta.insert('Line $i of a long note that keeps going.\n');
    }
    final pdf = pw.Document()
      ..addPage(NoteExportActions.notePages(
        title: 'Long note',
        document: ParchmentDocument.fromDelta(delta),
        footer: 'Exported from Pinpoint',
      ));
    final bytes = await pdf.save();
    final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;
    expect(pages, greaterThan(3));
  });

  test('a formatted note renders', () async {
    final pdf = pw.Document()
      ..addPage(NoteExportActions.notePages(
        title: 'Essay outline',
        document: sample(),
        footer: 'Exported from Pinpoint · Oct 6, 2026',
      ));
    final bytes = await pdf.save();
    expect(bytes, isNotEmpty);
    final out = Platform.environment['PINPOINT_PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('dismissing the share sheet does not use an export', () {
    expect(NoteExportActions.shareCounts(ShareResultStatus.dismissed), isFalse);
    expect(NoteExportActions.shareCounts(ShareResultStatus.success), isTrue);
    expect(NoteExportActions.shareCounts(ShareResultStatus.unavailable), isTrue);
  });
}
