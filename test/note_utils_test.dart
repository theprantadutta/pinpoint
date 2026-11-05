import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/util/note_utils.dart';

/// The folder card query cuts stored content at 80 characters, so an untitled
/// note's rich text arrives as JSON that no longer parses.
void main() {
  test('rich text cut off mid-way shows its text', () {
    expect(storedContentPreview(r'[{"insert":"CrashCheck\nrow1\nrow2\nrow3'),
        'CrashCheck');
  });

  test('a complete rich text note shows its first line', () {
    expect(storedContentPreview(r'[{"insert":"Buy \"milk\"\nThen eggs\n"}]'),
        'Buy "milk"');
  });

  test('a cut inside an escape does not throw', () {
    expect(storedContentPreview(r'[{"insert":"Tab\'), 'Tab');
  });

  test('text before an image is found past the embed', () {
    expect(
        storedContentPreview(
            r'[{"insert":{"_type":"image"}},{"insert":"Caption\n"}]'),
        'Caption');
  });

  test('plain titles and old plain text pass through', () {
    expect(storedContentPreview('Groceries'), 'Groceries');
    expect(storedContentPreview('[draft] plan'), '[draft] plan');
  });
}
