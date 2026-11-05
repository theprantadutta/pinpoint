import 'dart:convert';

String getNoteTitleOrPreview(String? title, String? content) {
  if (title != null && title.trim().isNotEmpty) {
    return title;
  }
  if (content != null && content.trim().isNotEmpty) {
    final preview = content.trim().replaceAll('\n', ' ');
    return preview.length > 50 ? '${preview.substring(0, 50)}...' : preview;
  }
  return 'Empty note';
}

/// The first line of text from a stored note body, which may be rich text
/// JSON cut off anywhere, or plain text from an older note.
String storedContentPreview(String stored) {
  if (!stored.startsWith('[{"insert"')) return stored.split('\n').first.trim();
  final match =
      RegExp(r'"insert":"((?:[^"\\]|\\.)*)').firstMatch(stored)?.group(1);
  if (match == null) return '';
  // A cut can land just after the backslash of an escape.
  final whole = RegExp(r'(?<!\\)(\\\\)*\\$').hasMatch(match)
      ? match.substring(0, match.length - 1)
      : match;
  try {
    final text = jsonDecode('"$whole"') as String;
    return text.split('\n').first.trim();
  } on FormatException {
    return '';
  }
}
