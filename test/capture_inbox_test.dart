import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/navigation/new_note.dart';
import 'package:pinpoint/services/capture/capture_inbox.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  SharedMediaFile shared(String path, SharedMediaType type) =>
      SharedMediaFile(path: path, type: type);

  test('shared text and links go in the body, in order', () {
    final capture = CaptureInbox.fromShared([
      shared('Read this later', SharedMediaType.text),
      shared('https://example.com/a', SharedMediaType.url),
    ])!;

    expect(capture.text, 'Read this later\nhttps://example.com/a');
    expect(capture.files, isEmpty);
    expect(capture.noteType, NewNote.text);
    expect(capture.source, 'share');
  });

  test('images and any other file become attachments', () {
    final capture = CaptureInbox.fromShared([
      shared('/cache/photo.jpg', SharedMediaType.image),
      shared('/cache/report.pdf', SharedMediaType.file),
    ])!;

    expect(capture.text, isNull);
    expect(capture.files.map((f) => f.name), ['photo.jpg', 'report.pdf']);
    expect(capture.files.first.path, '/cache/photo.jpg');
  });

  test('nothing usable makes no note', () {
    expect(CaptureInbox.fromShared(const []), isNull);
    expect(CaptureInbox.fromShared([shared('  ', SharedMediaType.text)]), isNull);
  });

  test('each shortcut opens its note type', () {
    expect(CaptureInbox.fromShortcut('new_note').noteType, NewNote.text);
    expect(CaptureInbox.fromShortcut('new_checklist').noteType, NewNote.checklist);
    expect(CaptureInbox.fromShortcut('new_voice').noteType, NewNote.voice);
  });

  test('a capture is handed over once', () {
    CaptureInbox.pending.value = CaptureInbox.fromShortcut('new_note');

    expect(CaptureInbox.take(), isNotNull);
    expect(CaptureInbox.take(), isNull);
  });
}
