import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinpoint/dtos/note_attachment_dto.dart';
import 'package:pinpoint/screens/drawing_screen.dart';
import 'package:pinpoint/services/ocr_service.dart';
import 'package:pinpoint/services/premium_service.dart';
import 'package:pinpoint/widgets/premium_gate_dialog.dart';
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/constants/premium_limits.dart';

class NoteInputField extends StatelessWidget {
  final String title;
  final TextEditingController textEditingController;
  final int maxLines;
  final List<NoteAttachmentDto> noteAttachments;
  final Function(List<NoteAttachmentDto>) onNoteAttachChanged;
  final Function(String) onOcrCompleted;

  const NoteInputField({
    super.key,
    required this.title,
    required this.textEditingController,
    this.maxLines = 1,
    required this.noteAttachments,
    required this.onNoteAttachChanged,
    required this.onOcrCompleted,
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
        // Check file attachment limits for free users
        final premiumService = PremiumService();
        if (!premiumService.isPremium) {
          final currentAttachments = noteAttachments.length;
          final maxAttachments = PremiumLimits.maxAttachmentsPerNoteForFree;

          if (currentAttachments >= maxAttachments) {
            if (context.mounted) {
              PinpointHaptics.error();
              await PremiumGateDialog.showFileAttachmentLimit(
                context,
                currentAttachments,
                maxAttachments,
              );
            }
            break; // Stop adding more attachments
          }
        }

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
          if (!context.mounted) return;

          // Check OCR limits
          final premiumService = PremiumService();
          if (!premiumService.canPerformOcrScan()) {
            PinpointHaptics.error();
            final remaining = premiumService.getRemainingOcrScans();
            await PremiumGateDialog.showOcrLimit(context, remaining);
            continue; // Skip OCR for this image
          }

          // Build dialog content with usage indicator
          final isPremium = premiumService.isPremium;
          final used = premiumService.getOcrScansThisMonth();
          final total = PremiumLimits.maxOcrScansPerMonthForFree;
          final usageText = isPremium
              ? 'Unlimited OCR scans available'
              : 'OCR scans: $used/$total this month';

          final bool? doOCR = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Perform OCR?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Do you want to extract text from this image?'),
                  const SizedBox(height: 12),
                  Text(
                    usageText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
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
            final String recognizedText =
                await OCRService.recognizeText(newPath);
            if (recognizedText.isNotEmpty) {
              onOcrCompleted(recognizedText);
              // Increment OCR usage counter
              await premiumService.incrementOcrScans();
              PinpointHaptics.success();
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
                        ? Colors.white.withAlpha(178)
                        : Colors.black.withAlpha(102),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkTheme
                          ? Colors.white.withAlpha(25)
                          : Colors.black.withAlpha(25),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkTheme
                          ? Colors.white.withAlpha(51)
                          : Colors.black.withAlpha(51),
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
                      ? Colors.white.withAlpha(12)
                      : Colors.black.withAlpha(2),
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
                  color: kPrimaryColor.withAlpha(25),
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
            SizedBox(width: 3),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DrawingScreen(),
                  ),
                );
                if (result != null && result is Uint8List) {
                  final tempDir = await getTemporaryDirectory();
                  final file = await File(
                          '${tempDir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png')
                      .writeAsBytes(result);
                  onNoteAttachChanged([
                    ...noteAttachments,
                    NoteAttachmentDto(
                      path: file.path,
                      name: 'drawing.png',
                      mimeType: 'image/png',
                    )
                  ]);
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.draw_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
