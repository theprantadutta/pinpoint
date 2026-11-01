import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../database/database.dart';
import '../../service_locators/init_service_locators.dart';
import '../api_service.dart';
import 'note_attachment_service.dart';

/// Moves note attachments between this device and the server.
///
/// Files are encrypted with the account data key before upload (see
/// [ApiService.uploadAttachment]); the server and FileRunner hold ciphertext.
/// Nothing here is required for the app to work: offline, attachments stay on
/// the device, and every step is retried at the next sync.
///
/// The note payload lists attachments under `attachments`, each with its
/// FileRunner id. An attachment that has not been uploaded yet is left out of
/// the payload; the note is re-sent once it is up. A payload without the key
/// (written by an older version) leaves this device's attachments alone.
class AttachmentSync {
  AttachmentSync._();

  static const String payloadKey = 'attachments';

  static Future<void>? _running;

  static AppDatabase get _db => getIt<AppDatabase>();

  /// Upload new attachments and carry out deletes made offline. Before notes
  /// sync, so the notes sent next carry the new ids.
  static Future<void> pushPending() => _running ??= _push().whenComplete(() => _running = null);

  static Future<void> _push() async {
    final api = ApiService();

    final deletes = await NoteAttachmentService.pendingRemoteDeletes();
    final stillPending = <String>[];
    for (final id in deletes) {
      try {
        await api.deleteAttachment(id);
      } catch (e) {
        debugPrint('⚠️ [Attachments] Delete deferred: $e');
        stillPending.add(id);
      }
    }
    if (deletes.isNotEmpty) await NoteAttachmentService.setPendingRemoteDeletes(stillPending);

    final pending = await (_db.select(_db.noteAttachmentsV2)
          ..where((t) => t.remoteId.isNull() & t.localPath.isNotNull()))
        .get();
    for (final a in pending) {
      final file = File(a.localPath!);
      if (!await file.exists() || await file.length() > NoteAttachmentService.maxBytes) continue;
      try {
        final id = await api.uploadAttachment(file.path);
        // Removed while uploading: the server copy is not wanted.
        final rows = await (_db.update(_db.noteAttachmentsV2)..where((t) => t.id.equals(a.id)))
            .write(NoteAttachmentsV2Companion(remoteId: Value(id)));
        if (rows == 0) {
          await NoteAttachmentService.queueRemoteDelete(id);
          continue;
        }
        await NoteAttachmentService.markNoteChanged(a.noteType, a.noteUuid);
        debugPrint('✅ [Attachments] ${a.uuid} uploaded');
      } catch (e) {
        debugPrint('⚠️ [Attachments] ${a.uuid} upload deferred: $e');
      }
    }
  }

  /// Download attachments other devices added. After notes sync.
  static Future<void> pullMissing() async {
    final rows = await (_db.select(_db.noteAttachmentsV2)..where((t) => t.remoteId.isNotNull())).get();
    final api = ApiService();
    final dir = await NoteAttachmentService.directory();
    for (final a in rows) {
      if (a.localPath != null && await File(a.localPath!).exists()) continue;
      final ext = NoteAttachmentService.extensionOf(a.fileName);
      final path = '${dir.path}/${a.uuid}$ext';
      try {
        await api.downloadAttachment(a.remoteId!, path);
        await (_db.update(_db.noteAttachmentsV2)..where((t) => t.id.equals(a.id)))
            .write(NoteAttachmentsV2Companion(localPath: Value(path)));
      } catch (e) {
        debugPrint('⚠️ [Attachments] ${a.uuid} download deferred: $e');
      }
    }
  }

  /// The note's attachments as they go into its encrypted payload.
  static Future<List<Map<String, dynamic>>> payloadFor(String noteUuid) async => [
        for (final a in await NoteAttachmentService.forNote(noteUuid))
          if (a.remoteId != null) toPayload(a),
      ];

  static Map<String, dynamic> toPayload(NoteAttachmentEntity a) => {
        'id': a.uuid,
        'remoteId': a.remoteId,
        'name': a.fileName,
        'mime': a.mimeType,
        'size': a.sizeBytes,
        'order': a.sortOrder,
      };

  /// Make this device's attachments for the note match a downloaded payload.
  /// [items] null (older payload): nothing changes. Attachments not uploaded
  /// yet are kept; uploaded ones missing from the payload were removed on
  /// another device.
  static Future<void> applyFromPayload(String noteUuid, String noteType, Object? items) async {
    if (items is! List) return;
    final incoming = <String, Map>{
      for (final item in items)
        if (item is Map && item['id'] is String && item['remoteId'] is String) item['id'] as String: item,
    };
    final local = await NoteAttachmentService.forNote(noteUuid);

    for (final a in local) {
      if (a.remoteId != null && !incoming.containsKey(a.uuid)) {
        await (_db.delete(_db.noteAttachmentsV2)..where((t) => t.id.equals(a.id))).go();
        if (a.localPath != null) {
          try {
            final f = File(a.localPath!);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      }
    }

    final known = {for (final a in local) a.uuid: a};
    for (final entry in incoming.entries) {
      final item = entry.value;
      final existing = known[entry.key];
      if (existing != null) {
        await (_db.update(_db.noteAttachmentsV2)..where((t) => t.id.equals(existing.id))).write(
            NoteAttachmentsV2Companion(
                remoteId: Value(item['remoteId'] as String),
                sortOrder: Value((item['order'] as num?)?.toInt() ?? existing.sortOrder)));
        continue;
      }
      await _db.into(_db.noteAttachmentsV2).insert(NoteAttachmentsV2Companion.insert(
            uuid: entry.key,
            noteUuid: noteUuid,
            noteType: noteType,
            fileName: '${item['name'] ?? 'file'}',
            mimeType: '${item['mime'] ?? 'application/octet-stream'}',
            sizeBytes: (item['size'] as num?)?.toInt() ?? 0,
            remoteId: Value(item['remoteId'] as String),
            sortOrder: Value((item['order'] as num?)?.toInt() ?? 0),
            createdAt: DateTime.now(),
          ));
    }
  }
}
