class NoteAttachmentDto {
  final String name;
  final String path;
  final String? mimeType;

  NoteAttachmentDto({
    required this.name,
    required this.path,
    this.mimeType,
  });
}
