import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../constants/premium_limits.dart';
import '../../database/database.dart';
import '../../service_locators/init_service_locators.dart';

/// Files attached to text and checklist notes: images and any other file.
///
/// Offline first, like the rest of the app. Adding a file copies it into the
/// app's own storage and it is usable at once; [AttachmentSync] uploads it
/// (encrypted) when there is a connection and downloads what other devices
/// added. Every change marks the note for sync so the attachment list, which
/// travels inside the note's encrypted payload, reaches the other devices.
class NoteAttachmentService {
  NoteAttachmentService._();

  /// Server limit per file (AttachmentsController.MaxUploadBytes).
  static const int maxBytes = 50 * 1024 * 1024;

  static const String _pendingDeletesKey = 'attachment_pending_deletes';

  static AppDatabase get _db => getIt<AppDatabase>();

  static Future<Directory> directory() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/attachments');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static bool isImage(String mimeType) => mimeType.startsWith('image/');

  /// The MIME type for [fileName], falling back to a generic binary type.
  static String mimeTypeFor(String fileName, [List<int>? headerBytes]) =>
      lookupMimeType(fileName, headerBytes: headerBytes) ?? 'application/octet-stream';

  /// How many files a note may hold on this plan; null means no limit.
  static int? limitFor({required bool isPremium}) =>
      isPremium ? null : PremiumLimits.maxAttachmentsPerNoteForFree;

  static Stream<List<NoteAttachmentEntity>> watch(String noteUuid) =>
      (_db.select(_db.noteAttachmentsV2)
            ..where((t) => t.noteUuid.equals(noteUuid))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder), (t) => OrderingTerm(expression: t.id)]))
          .watch();

  static Future<List<NoteAttachmentEntity>> forNote(String noteUuid) =>
      (_db.select(_db.noteAttachmentsV2)
            ..where((t) => t.noteUuid.equals(noteUuid))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder), (t) => OrderingTerm(expression: t.id)]))
          .get();

  static Future<int> count(String noteUuid) async => (await forNote(noteUuid)).length;

  /// The note's first image that is on this device, for its home card.
  static Stream<String?> watchCoverImage(String noteUuid) => watch(noteUuid).map((items) {
        for (final a in items) {
          if (isImage(a.mimeType) && a.localPath != null && File(a.localPath!).existsSync()) {
            return a.localPath;
          }
        }
        return null;
      });

  /// Copy [sourcePath] into the app's storage and attach it to the note.
  static Future<NoteAttachmentEntity> add({
    required String noteUuid,
    required String noteType,
    required String sourcePath,
    required String fileName,
  }) async {
    final source = File(sourcePath);
    final size = await source.length();
    final header = await source.openRead(0, 32).fold<List<int>>([], (a, b) => a..addAll(b));
    final mime = mimeTypeFor(fileName, header);
    final uuid = const Uuid().v4();
    final ext = _extension(fileName);
    final target = File('${(await directory()).path}/$uuid$ext');
    await source.copy(target.path);

    final order = await count(noteUuid);
    final id = await _db.into(_db.noteAttachmentsV2).insert(NoteAttachmentsV2Companion.insert(
          uuid: uuid,
          noteUuid: noteUuid,
          noteType: noteType,
          fileName: fileName,
          mimeType: mime,
          sizeBytes: size,
          localPath: Value(target.path),
          sortOrder: Value(order),
          createdAt: DateTime.now(),
        ));
    await markNoteChanged(noteType, noteUuid);
    return (_db.select(_db.noteAttachmentsV2)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Remove an attachment here, and from the server at the next sync.
  static Future<void> remove(NoteAttachmentEntity attachment) async {
    await (_db.delete(_db.noteAttachmentsV2)..where((t) => t.id.equals(attachment.id))).go();
    await _deleteLocalFile(attachment.localPath);
    if (attachment.remoteId != null) await queueRemoteDelete(attachment.remoteId!);
    await markNoteChanged(attachment.noteType, attachment.noteUuid);
  }

  /// Every attachment of a note that is gone for good (emptied from trash).
  static Future<void> removeAllForNote(String noteUuid) async {
    for (final a in await forNote(noteUuid)) {
      await (_db.delete(_db.noteAttachmentsV2)..where((t) => t.id.equals(a.id))).go();
      await _deleteLocalFile(a.localPath);
      if (a.remoteId != null) await queueRemoteDelete(a.remoteId!);
    }
  }

  /// Mark the note for upload, so its attachment list reaches other devices.
  static Future<void> markNoteChanged(String noteType, String noteUuid) async {
    final now = DateTime.now();
    switch (noteType) {
      case 'text':
        await (_db.update(_db.textNotesV2)..where((t) => t.uuid.equals(noteUuid)))
            .write(TextNotesV2Companion(isSynced: const Value(false), updatedAt: Value(now)));
      case 'todo':
        await (_db.update(_db.todoListNotesV2)..where((t) => t.uuid.equals(noteUuid)))
            .write(TodoListNotesV2Companion(isSynced: const Value(false), updatedAt: Value(now)));
    }
  }

  static Future<void> queueRemoteDelete(String remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingDeletesKey) ?? [];
    if (!list.contains(remoteId)) await prefs.setStringList(_pendingDeletesKey, [...list, remoteId]);
  }

  static Future<List<String>> pendingRemoteDeletes() async =>
      (await SharedPreferences.getInstance()).getStringList(_pendingDeletesKey) ?? [];

  static Future<void> setPendingRemoteDeletes(List<String> ids) async =>
      (await SharedPreferences.getInstance()).setStringList(_pendingDeletesKey, ids);

  static Future<void> _deleteLocalFile(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('⚠️ [Attachments] Could not delete $path: $e');
    }
  }

  /// `.jpg` from `photo.JPG`; empty when there is none. Pure, for testing.
  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    final ext = fileName.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(ext) ? ext : '';
  }

  static String extensionOf(String fileName) => _extension(fileName);
}
