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
