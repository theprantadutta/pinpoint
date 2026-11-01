import 'dart:io';

import 'package:flutter/material.dart';

import '../../database/database.dart';
import '../../design_system/design_system.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../services/note_attachments/note_attachment_service.dart';

/// A note's attachments in the editor: images as a grid of thumbnails, any
/// other file as a row with its name and size. Each has a remove button.
/// An attachment synced from another device that has not downloaded yet
/// shows a placeholder until it arrives.
class NoteAttachmentsSection extends StatelessWidget {
  const NoteAttachmentsSection({
    super.key,
    required this.noteUuid,
    required this.onOpen,
    required this.onRemove,
  });

  final String noteUuid;
  final ValueChanged<NoteAttachmentEntity> onOpen;
  final ValueChanged<NoteAttachmentEntity> onRemove;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteAttachmentEntity>>(
      stream: NoteAttachmentService.watch(noteUuid),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        final images = items.where((a) => NoteAttachmentService.isImage(a.mimeType)).toList();
        final files = items.where((a) => !NoteAttachmentService.isImage(a.mimeType)).toList();
        return Padding(
          padding: const EdgeInsets.only(top: SketchSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (images.isNotEmpty)
                LayoutBuilder(builder: (context, constraints) {
                  const gap = 8.0;
                  final columns = images.length == 1 ? 1 : (constraints.maxWidth > 520 ? 3 : 2);
                  final size = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final a in images)
                        _ImageTile(
                          attachment: a,
                          width: size,
                          height: columns == 1 ? size * 0.66 : size,
                          onOpen: () => onOpen(a),
                          onRemove: () => onRemove(a),
                        ),
                    ],
                  );
                }),
              if (images.isNotEmpty && files.isNotEmpty) const SizedBox(height: 10),
              for (final a in files)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FileRow(attachment: a, onOpen: () => onOpen(a), onRemove: () => onRemove(a)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// `1.4 MB`, `820 KB`. Pure, for testing.
String formatAttachmentSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.attachment,
    required this.width,
    required this.height,
    required this.onOpen,
    required this.onRemove,
  });

  final NoteAttachmentEntity attachment;
  final double width;
  final double height;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final path = attachment.localPath;
    final available = path != null && File(path).existsSync();
    return Semantics(
      button: true,
      label: attachment.fileName,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: available ? onOpen : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SketchRadius.card),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SketchRadius.card),
                      border: Border.all(color: s.outline, width: SketchStroke.outline),
                    ),
                    child: available
                        ? Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            // Decode at display size: full-resolution decodes
                            // were the app's main out-of-memory crash.
                            cacheWidth: (width * dpr).round(),
                            errorBuilder: (_, __, ___) => _Placeholder(icon: Icons.broken_image_outlined),
                          )
                        : _Placeholder(icon: Icons.cloud_download_outlined, label: l10n.attWaitingDownload),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 6,
              end: 6,
              child: _RemoveButton(onPressed: onRemove),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.attachment, required this.onOpen, required this.onRemove});

  final NoteAttachmentEntity attachment;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);
    final path = attachment.localPath;
    final available = path != null && File(path).existsSync();
    return Material(
      color: s.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SketchRadius.card),
        side: BorderSide(color: s.outline, width: SketchStroke.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: available ? onOpen : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
          child: Row(
            children: [
              Icon(available ? _iconFor(attachment.mimeType) : Icons.cloud_download_outlined,
                  color: s.ink, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attachment.fileName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: s.ink)),
                    Text(
                      available ? formatAttachmentSize(attachment.sizeBytes) : l10n.attWaitingDownload,
                      style: t.caption.copyWith(color: s.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.attRemove,
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, color: s.muted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String mime) {
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mime.startsWith('video/')) return Icons.video_file_outlined;
    if (mime.startsWith('text/')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    return ColoredBox(
      color: s.soft,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: s.muted),
            if (label != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(label!, textAlign: TextAlign.center, style: t.caption.copyWith(color: s.muted)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    return Semantics(
      button: true,
      label: AppL10n.of(context).attRemove,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: s.surface,
            shape: BoxShape.circle,
            border: Border.all(color: s.outline, width: SketchStroke.outline),
          ),
          child: Icon(Icons.close_rounded, size: 16, color: s.ink),
        ),
      ),
    );
  }
}

/// Full-screen view of an image attachment, pinch to zoom.
class AttachmentImageViewer extends StatelessWidget {
  const AttachmentImageViewer({super.key, required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
      ),
    );
  }
}
