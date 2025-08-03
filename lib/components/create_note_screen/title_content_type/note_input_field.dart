import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinpoint/services/ocr_service.dart';

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

  Future<void> uploadFiles(BuildContext context) async {
    final ImagePicker picker = ImagePicker();

    // Request storage permission (only needed on Android)
    if (await _requestStoragePermission()) {
      // Pick multiple images and videos.
      final List<XFile> medias = await picker.pickMultipleMedia();
      final Directory appDir =
          await getApplicationDocumentsDirectory(); // Safe storage location

      for (var media in medias) {
        final File originalFile = File(media.path);
        final String newPath = '${appDir.path}/${media.name}';

        // Copy file to a safe location
        await originalFile.copy(newPath);

        noteAttachments.add(NoteAttachmentDto(
          name: media.name,
          path: newPath, // Use the new safe path
          mimeType: media.mimeType,
        ));

        // Offer OCR for images
        if (media.mimeType?.startsWith('image/') == true) {
          final bool? doOCR = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Perform OCR?'),
              content: const Text('Do you want to extract text from this image?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            ),
          );

          if (doOCR == true) {
            final String recognizedText = await OCRService.recognizeText(newPath);
            if (recognizedText.isNotEmpty) {
              textEditingController.text += '\n\n$recognizedText';
              textEditingController.selection = TextSelection.fromPosition(
                TextPosition(offset: textEditingController.text.length),
              );
            }
          }
        }
      }

      onNoteAttachChanged(noteAttachments);
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true; // Already granted
    }

    // Check Android version
    if (await Permission.photos.isDenied || await Permission.videos.isDenied) {
      await Permission.photos.request();
      await Permission.videos.request();
    }

    

    if (await Permission.photos.isGranted ||
        await Permission.videos.isGranted) {
      return true;
    }
    return false;

    
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
              onTap: () => uploadFiles(context),
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
