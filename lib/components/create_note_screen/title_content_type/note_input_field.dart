import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../dtos/note_attachment_dto.dart';

class NoteInputField extends StatelessWidget {
  final String title;
  final TextEditingController textEditingController;
  final int maxLines;
  final List<NoteAttachmentDto> noteAttachments;
  final Function(List<NoteAttachmentDto>) onNoteAttachChanged;

  const NoteInputField({
    super.key,
    required this.title,
    required this.textEditingController,
    this.maxLines = 1,
    required this.noteAttachments,
    required this.onNoteAttachChanged,
  });

  Future<void> uploadFiles() async {
    final ImagePicker picker = ImagePicker();
    // Pick multiple images and videos.
    final List<XFile> medias = await picker.pickMultipleMedia();
    for (var media in medias) {
      noteAttachments.add(NoteAttachmentDto(
        name: media.name,
        path: media.path,
        mimeType: media.mimeType,
      ));
    }
    onNoteAttachChanged(noteAttachments);
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: 8,
          left: 10,
          right: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: textEditingController,
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                maxLines: maxLines,
                // textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: title,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: isDarkTheme
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkTheme
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkTheme
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  fillColor: isDarkTheme
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.01),
                  filled: true,
                ),
              ),
            ),
            SizedBox(width: 3),
            GestureDetector(
              onTap: uploadFiles,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(noteAttachments.isEmpty
                        ? 'Attach'
                        : '${noteAttachments.length} Attached'),
                    SizedBox(width: 3),
                    Icon(Icons.attach_file_outlined),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
