import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../service_locators/init_service_locators.dart';
import 'api_service.dart';

/// Voice recordings waiting to reach the server, and where each one landed.
///
/// A voice note keeps its LOCAL file path in the database, so it plays on
/// this phone with or without a connection. The server's copy is tracked
/// here by note uuid, and that server path is what sync sends to the user's
/// other devices — never a path that only exists on this phone.
///
/// Every new or replaced recording is queued; the queue is worked through at
/// the start of every sync, so an upload that failed (offline, server down)
/// is simply tried again next time. Once a recording is up, its note is
/// marked for sync so the other devices learn the server path.
class AudioUploadQueue {
  AudioUploadQueue._();

  static const String _queueKey = 'audio_upload_queue';
  static const String _remoteKey = 'audio_remote_paths';
  static const String _scannedKey = 'audio_upload_queue_scanned';

  static Future<void>? _running;

  /// The server refuses uploads over 25 MiB (AudioController). The encrypted
  /// envelope and multipart framing add a little, so leave headroom. At the
  /// recorder's 128 kbit/s this is roughly 25 minutes of audio.
  static const int cloudLimitMegabytes = 25;
  static const int maxUploadBytes = cloudLimitMegabytes * 1024 * 1024 - 64 * 1024;

  /// Whether a recording of [bytes] can be backed up. Pure, for testing.
  static bool fitsCloud(int bytes) => bytes <= maxUploadBytes;

  /// Whether the recording at [localPath] is too large to back up, so the
  /// editor can say so. False for a missing file.
  static Future<bool> tooLargeForCloud(String localPath) async {
    try {
      final file = File(localPath);
      return await file.exists() && !fitsCloud(await file.length());
    } catch (_) {
      return false;
    }
  }

  /// Server paths look like `<user-id>/<file-id>.<ext>`; anything else is a
  /// file on some device. Pure, for testing.
  static bool isServerPath(String path) =>
      RegExp(r'^[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}\.[A-Za-z0-9]{1,8}$').hasMatch(path);

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<Map<String, String>> remotePaths() async {
    final raw = (await _prefs).getString(_remoteKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> setRemotePath(String noteUuid, String serverPath) async {
    final map = await remotePaths()..[noteUuid] = serverPath;
    await (await _prefs).setString(_remoteKey, jsonEncode(map));
  }

  static Future<List<Map<String, String>>> pending() async {
    final raw = (await _prefs).getString(_queueKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<Map<String, String>> items) async =>
      (await _prefs).setString(_queueKey, jsonEncode(items));

  /// Queue [localPath] as the recording for [noteUuid], replacing anything
  /// queued for it. The note's old server copy no longer matches, so it is
  /// forgotten until the new one is up.
  static Future<void> enqueue(String noteUuid, String localPath) async {
    final items = (await pending()).where((e) => e['uuid'] != noteUuid).toList()
      ..add({'uuid': noteUuid, 'path': localPath});
    await _save(items);
    final remote = await remotePaths();
    if (remote.remove(noteUuid) != null) {
      await (await _prefs).setString(_remoteKey, jsonEncode(remote));
    }
  }

  /// Upload whatever is queued. Safe to call often: concurrent calls share
  /// one run, and failures stay queued for the next one.
  static Future<void> process() => _running ??= _process().whenComplete(() => _running = null);

  static Future<void> _process() async {
    await _queueRecordingsThatNeverUploaded();
    final items = await pending();
    if (items.isEmpty) return;

    final api = ApiService();
    final database = getIt<AppDatabase>();
    final remaining = <Map<String, String>>[];

    for (final item in items) {
      final uuid = item['uuid']!;
      final path = item['path']!;
      if (!await File(path).exists()) {
        debugPrint('⚠️ [AudioUpload] $uuid: local file is gone, dropping');
        continue;
      }
      // Would only be refused after uploading 25 MB. The editor tells the
      // user it stays on this device.
      if (await tooLargeForCloud(path)) {
        debugPrint('⚠️ [AudioUpload] $uuid: over the cloud limit, kept on device');
        continue;
      }
      try {
        final serverPath = await api.uploadAudioFile(path);
        // Re-recorded while this was uploading: that newer file is queued and
        // will publish its own path; this one is already out of date.
        final latest = (await pending()).where((e) => e['uuid'] == uuid);
        if (latest.isNotEmpty && latest.first['path'] != path) continue;
        await setRemotePath(uuid, serverPath);
        // Bump the note so its new server path reaches the other devices.
        await (database.update(database.voiceNotesV2)..where((t) => t.uuid.equals(uuid))).write(
          VoiceNotesV2Companion(isSynced: const Value(false), updatedAt: Value(DateTime.now())),
        );
        debugPrint('✅ [AudioUpload] $uuid uploaded');
      } catch (e) {
        if (_isPermanent(e)) {
          // Too large for the server or refused as not audio: retrying
          // cannot help. The recording stays playable on this phone.
          debugPrint('❌ [AudioUpload] $uuid refused by the server, dropping: $e');
          continue;
        }
        debugPrint('⚠️ [AudioUpload] $uuid failed, will retry: $e');
        remaining.add(item);
      }
    }

    // Keep what failed, plus anything queued while this ran (a new or
    // re-recorded note); a re-recording replaces its note's failed entry.
    bool processed(Map<String, String> e) =>
        items.any((i) => i['uuid'] == e['uuid'] && i['path'] == e['path']);
    final added = (await pending()).where((e) => !processed(e)).toList();
    final addedUuids = added.map((e) => e['uuid']).toSet();
    await _save([...remaining.where((e) => !addedUuids.contains(e['uuid'])), ...added]);
  }

  static bool _isPermanent(Object e) {
    final text = e.toString();
    return text.contains('413') || text.contains('NOT_AN_AUDIO_FILE') || text.contains('Request Entity Too Large');
  }

  /// Once per install: recordings made before this queue existed whose upload
  /// failed still hold only a local path. Queue them.
  static Future<void> _queueRecordingsThatNeverUploaded() async {
    final prefs = await _prefs;
    if (prefs.getBool(_scannedKey) == true) return;
    try {
      final database = getIt<AppDatabase>();
      final notes = await (database.select(database.voiceNotesV2)..where((t) => t.isDeleted.equals(false))).get();
      final remote = await remotePaths();
      for (final note in notes) {
        if (remote.containsKey(note.uuid) || isServerPath(note.audioFilePath)) continue;
        if (note.audioFilePath.isEmpty || !await File(note.audioFilePath).exists()) continue;
        await enqueue(note.uuid, note.audioFilePath);
      }
      await prefs.setBool(_scannedKey, true);
    } catch (e) {
      debugPrint('⚠️ [AudioUpload] Scan for old recordings failed: $e');
    }
  }
}
