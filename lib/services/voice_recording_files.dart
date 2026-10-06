import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../service_locators/init_service_locators.dart';
import 'audio_upload_queue.dart';

/// Where voice recordings live on this device.
///
/// In `<documents>/audio`, next to recordings downloaded from other devices.
/// Never in the cache directory: Android may clear it whenever storage runs
/// low, which would silently empty a voice note — for good, if it had not
/// been uploaded yet.
class VoiceRecordingFiles {
  VoiceRecordingFiles._();

  static const String _movedKey = 'voice_recordings_moved_from_cache';

  static Future<Directory> audioDirectory() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// A fresh path for a new recording.
  static Future<String> newRecordingPath() async =>
      '${(await audioDirectory()).path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

  /// Whether [path] sits under [cacheDir]. Pure, for testing.
  @visibleForTesting
  static bool isInCache(String path, String cacheDir) =>
      cacheDir.isNotEmpty && path.startsWith(cacheDir.endsWith('/') ? cacheDir : '$cacheDir/');

  /// Once per install: move recordings made before this fix out of the cache
  /// directory, repointing their notes and any queued upload. The path is
  /// local-only (sync sends the server's), so the note is not re-synced.
  static Future<void> moveOutOfCacheOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_movedKey) == true) return;
    try {
      final cache = (await getTemporaryDirectory()).path;
      final database = getIt<AppDatabase>();
      final notes = await database.select(database.voiceNotesV2).get();
      final dir = await audioDirectory();

      for (final note in notes) {
        final from = note.audioFilePath;
        if (!isInCache(from, cache) || !await File(from).exists()) continue;
        final to = '${dir.path}/${from.split('/').last}';
        try {
          await File(from).rename(to);
        } on FileSystemException {
          await File(from).copy(to);
          await File(from).delete();
        }
        await (database.update(database.voiceNotesV2)..where((t) => t.id.equals(note.id)))
            .write(VoiceNotesV2Companion(audioFilePath: Value(to)));
        await AudioUploadQueue.relocate(from, to);
        debugPrint('📦 [VoiceRecordingFiles] Moved ${note.uuid} out of cache');
      }
      await prefs.setBool(_movedKey, true);
    } catch (e) {
      // Tried again next time; nothing is lost by waiting.
      debugPrint('⚠️ [VoiceRecordingFiles] Move out of cache failed: $e');
    }
  }
}
