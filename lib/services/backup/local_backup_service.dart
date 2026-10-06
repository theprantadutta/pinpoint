import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../database/database.dart';
import '../../sync/api_sync_service.dart';
import '../api_service.dart';
import '../audio_upload_queue.dart';
import '../encryption_service.dart';
import '../voice_recording_files.dart';
import 'backup_archive.dart';

/// What a restore did.
class RestoreSummary {
  const RestoreSummary({
    required this.notesAdded,
    required this.notesSkipped,
    required this.foldersAdded,
    required this.recordingsRestored,
  });

  /// Notes added or updated from the backup.
  final int notesAdded;

  /// Notes left alone because this device's copy is the same age or newer.
  final int notesSkipped;
  final int foldersAdded;
  final int recordingsRestored;
}

/// Builds a backup file from this device, and merges one back in.
///
/// Notes go in exactly as cloud sync writes them (the plaintext maps it
/// encrypts), encrypted with the same account key, and come back through the
/// same code: a backup holds what the cloud would, plus the voice recordings,
/// which are otherwise only on the phone.
class LocalBackupService {
  LocalBackupService({required AppDatabase database, ApiSyncService? sync})
      : _db = database,
        _sync = sync ?? ApiSyncService(apiService: ApiService(), database: database);

  final AppDatabase _db;
  final ApiSyncService _sync;

  /// The account key, as cloud sync uses it.
  static final BackupCipher accountCipher = BackupCipher(
    encrypt: SecureEncryptionService.encrypt,
    decrypt: SecureEncryptionService.decrypt,
    encryptBytes: SecureEncryptionService.encryptBytes,
    decryptBytes: SecureEncryptionService.decryptBytes,
  );

  /// Write a backup of everything on this device to a temporary file.
  Future<({File file, BackupManifest manifest})> create({
    required String accountId,
    String appVersion = '',
    String device = '',
    BackupCipher? cipher,
  }) async {
    final folders = [
      for (final f in await _db.select(_db.noteFolders).get())
        {
          'uuid': f.uuid,
          'title': f.noteFolderTitle,
          'color': f.color,
          'sortOrder': f.sortOrder,
          'createdAt': f.createdAt.toUtc().toIso8601String(),
          'updatedAt': f.updatedAt.toUtc().toIso8601String(),
        },
    ];
    final notes = await _sync.exportAllNotesForBackup();
    final recordings = [
      for (final v in await _db.select(_db.voiceNotesV2).get())
        if (v.audioFilePath.isNotEmpty && !AudioUploadQueue.isServerPath(v.audioFilePath))
          BackupRecording(noteUuid: v.uuid, file: File(v.audioFilePath)),
    ];

    final out = File('${(await getTemporaryDirectory()).path}/'
        'pinpoint-backup-${DateTime.now().millisecondsSinceEpoch}.${BackupArchive.fileExtension}');
    final manifest = await BackupArchive.write(
      out: out,
      cipher: cipher ?? accountCipher,
      accountId: accountId,
      folders: folders,
      notes: notes,
      recordings: recordings,
      appVersion: appVersion,
      device: device,
    );
    return (file: out, manifest: manifest);
  }

  /// Merge [file] into this device: notes and folders it lacks are added,
  /// notes the backup holds a newer copy of are updated, and nothing here is
  /// deleted. Whatever it takes in is marked to sync up.
  ///
  /// Throws [BackupFormatException] before touching anything when the file
  /// is not a backup, is from a newer app, or belongs to another account.
  Future<RestoreSummary> restore(File file, {BackupCipher? cipher}) async {
    final key = cipher ?? accountCipher;
    final reader = BackupArchive.open(file);
    try {
      final contents = reader.read(key);
      final folderMap = <String, String>{};
      final foldersAdded = await _mergeFolders(contents.folders, folderMap);

      var added = 0, skipped = 0, recordings = 0;
      for (final original in contents.notes) {
        final note = Map<String, dynamic>.from(original);
        final uuid = note['uuid'] as String?;
        if (uuid == null) continue;
        final folderUuids = note['folderUuids'];
        if (folderUuids is List) {
          note['folderUuids'] = [for (final u in folderUuids) folderMap['$u'] ?? '$u'];
        }

        final isVoice = note['noteType'] == 'audio';
        final recording = isVoice ? reader.recording(uuid, key) : null;
        final serverPath = '${note['audioFilePath'] ?? ''}';
        // The recording comes from the backup, so there is nothing to fetch.
        if (recording != null) note['audioFilePath'] = '';

        final taken = await _sync.importNoteFromBackup(note);
        taken ? added++ : skipped++;

        if (recording != null && (taken || await _recordingMissing(uuid))) {
          await _placeRecording(uuid, recording, serverPath);
          recordings++;
        }
      }
      return RestoreSummary(
        notesAdded: added,
        notesSkipped: skipped,
        foldersAdded: foldersAdded,
        recordingsRestored: recordings,
      );
    } finally {
      await reader.close();
    }
  }

  /// Add the backup's folders this device lacks. A folder whose name is taken
  /// here by a different folder is mapped onto that one ([map], backup uuid to
  /// local uuid), since names are unique.
  Future<int> _mergeFolders(List<Map<String, dynamic>> folders, Map<String, String> map) async {
    final local = await _db.select(_db.noteFolders).get();
    final byUuid = {for (final f in local) f.uuid};
    final byTitle = {for (final f in local) f.noteFolderTitle.toLowerCase(): f.uuid};
    var added = 0;
    for (final f in folders) {
      final uuid = f['uuid'] as String?;
      final title = (f['title'] as String?)?.trim();
      if (uuid == null || title == null || title.isEmpty) continue;
      if (byUuid.contains(uuid)) continue;
      final taken = byTitle[title.toLowerCase()];
      if (taken != null) {
        map[uuid] = taken;
        continue;
      }
      final now = DateTime.now();
      await _db.into(_db.noteFolders).insert(
            NoteFoldersCompanion(
              uuid: Value(uuid),
              noteFolderTitle: Value(title),
              color: Value(f['color'] as String?),
              sortOrder: Value((f['sortOrder'] as num?)?.toInt()),
              createdAt: Value(DateTime.tryParse('${f['createdAt']}') ?? now),
              updatedAt: Value(DateTime.tryParse('${f['updatedAt']}') ?? now),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      byUuid.add(uuid);
      byTitle[title.toLowerCase()] = uuid;
      added++;
    }
    return added;
  }

  Future<bool> _recordingMissing(String uuid) async {
    final note = await (_db.select(_db.voiceNotesV2)..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();
    if (note == null) return false;
    final path = note.audioFilePath;
    return path.isEmpty || AudioUploadQueue.isServerPath(path) || !await File(path).exists();
  }

  /// Put a recording from the backup on disk and point its note at it. The
  /// server already has it when the note carried a server path; otherwise it
  /// is queued to upload, like a new recording.
  Future<void> _placeRecording(
      String uuid, ({Uint8List bytes, String extension}) recording, String serverPath) async {
    final dir = await VoiceRecordingFiles.audioDirectory();
    final path = '${dir.path}/$uuid.${recording.extension}';
    await File(path).writeAsBytes(recording.bytes, flush: true);
    await (_db.update(_db.voiceNotesV2)..where((t) => t.uuid.equals(uuid)))
        .write(VoiceNotesV2Companion(audioFilePath: Value(path)));
    if (AudioUploadQueue.isServerPath(serverPath)) {
      await AudioUploadQueue.setRemotePath(uuid, serverPath);
    } else {
      await AudioUploadQueue.enqueue(uuid, path);
    }
    debugPrint('🎙️ [Backup] Restored recording for $uuid');
  }
}
