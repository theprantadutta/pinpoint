import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

/// Something wrong with a backup file itself, phrased for a person.
class BackupFormatException implements Exception {
  const BackupFormatException(this.code);

  /// One of the [BackupProblem] values, mapped to text by the screen.
  final BackupProblem code;

  @override
  String toString() => 'BackupFormatException($code)';
}

enum BackupProblem {
  /// Not a zip, or a zip without our manifest.
  notABackup,

  /// Written by a newer version of the app.
  tooNew,

  /// Encrypted with another account's key: the manifest's key check does not
  /// decrypt with this one.
  otherAccount,
}

/// What a backup says about itself, readable without the key.
///
/// Nothing here is note content. It is enough to list a backup, refuse one
/// from a newer app, and tell a backup of another account apart before any
/// note is touched.
class BackupManifest {
  const BackupManifest({
    required this.createdAt,
    required this.accountId,
    required this.noteCount,
    required this.recordingCount,
    required this.keyCheck,
    this.formatVersion = BackupArchive.formatVersion,
    this.appVersion = '',
    this.device = '',
  });

  final int formatVersion;
  final DateTime createdAt;
  final String appVersion;
  final String device;

  /// The Pinpoint account whose key encrypted the backup.
  final String accountId;
  final int noteCount;
  final int recordingCount;

  /// [BackupArchive.keyCheckText] encrypted with the account key. Decrypting
  /// it proves the key matches before a single note is read.
  final String keyCheck;

  Map<String, Object?> toJson() => {
        'format_version': formatVersion,
        'created_at': createdAt.toUtc().toIso8601String(),
        'app_version': appVersion,
        'device': device,
        'account_id': accountId,
        'note_count': noteCount,
        'recording_count': recordingCount,
        'key_check': keyCheck,
      };

  factory BackupManifest.fromJson(Object? json) {
    if (json is! Map) throw const BackupFormatException(BackupProblem.notABackup);
    final version = json['format_version'];
    final createdAt = DateTime.tryParse('${json['created_at']}');
    final keyCheck = json['key_check'];
    if (version is! int || createdAt == null || keyCheck is! String) {
      throw const BackupFormatException(BackupProblem.notABackup);
    }
    if (version > BackupArchive.formatVersion) {
      throw const BackupFormatException(BackupProblem.tooNew);
    }
    return BackupManifest(
      formatVersion: version,
      createdAt: createdAt,
      appVersion: '${json['app_version'] ?? ''}',
      device: '${json['device'] ?? ''}',
      accountId: '${json['account_id'] ?? ''}',
      noteCount: (json['note_count'] as num?)?.toInt() ?? 0,
      recordingCount: (json['recording_count'] as num?)?.toInt() ?? 0,
      keyCheck: keyCheck,
    );
  }
}

/// A voice recording to put in a backup, by its note.
class BackupRecording {
  const BackupRecording({required this.noteUuid, required this.file});

  final String noteUuid;
  final File file;

  String get extension {
    final name = file.path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'm4a' : name.substring(dot + 1).toLowerCase();
  }
}

/// The encryption a backup is written and read with: the account's data key,
/// the same one cloud sync uses. Injected so the format is testable without a
/// device keystore.
class BackupCipher {
  const BackupCipher({
    required this.encrypt,
    required this.decrypt,
    required this.encryptBytes,
    required this.decryptBytes,
  });

  final String Function(String) encrypt;
  final String Function(String) decrypt;
  final Uint8List Function(Uint8List) encryptBytes;
  final Uint8List Function(Uint8List) decryptBytes;
}

/// A Pinpoint backup on disk: a zip of
///
/// - `manifest.json`: [BackupManifest], plaintext;
/// - `notes.enc`: every folder and note, as one encrypted JSON document;
/// - `recordings/<note uuid>.<ext>.enc`: each voice recording, encrypted on
///   its own so neither writing nor reading ever holds them all in memory.
///
/// Entries are stored, not deflated: ciphertext does not compress.
class BackupArchive {
  BackupArchive._();

  static const int formatVersion = 1;
  static const String manifestName = 'manifest.json';
  static const String notesName = 'notes.enc';
  static const String recordingsDir = 'recordings/';
  static const String keyCheckText = 'pinpoint-backup';

  /// The extension and MIME type a backup goes by in Drive.
  static const String fileExtension = 'pinpoint-backup';
  static const String mimeType = 'application/zip';

  /// Write a backup of [folders] and [notes] (the maps cloud sync encrypts)
  /// and [recordings] to [out].
  static Future<BackupManifest> write({
    required File out,
    required BackupCipher cipher,
    required String accountId,
    required List<Map<String, dynamic>> folders,
    required List<Map<String, dynamic>> notes,
    required List<BackupRecording> recordings,
    String appVersion = '',
    String device = '',
    DateTime? now,
  }) async {
    final encoder = ZipFileEncoder()..create(out.path);
    try {
      final body = cipher.encrypt(jsonEncode({'folders': folders, 'notes': notes}));
      encoder.addArchiveFile(_stored(notesName, utf8.encode(body)));

      var written = 0;
      for (final recording in recordings) {
        if (!await recording.file.exists()) continue;
        final sealed = cipher.encryptBytes(await recording.file.readAsBytes());
        encoder.addArchiveFile(_stored(
            '$recordingsDir${recording.noteUuid}.${recording.extension}.enc', sealed));
        written++;
      }

      final manifest = BackupManifest(
        createdAt: now ?? DateTime.now(),
        accountId: accountId,
        noteCount: notes.length,
        recordingCount: written,
        keyCheck: cipher.encrypt(keyCheckText),
        appVersion: appVersion,
        device: device,
      );
      encoder.addArchiveFile(
          _stored(manifestName, utf8.encode(jsonEncode(manifest.toJson()))));
      return manifest;
    } finally {
      await encoder.close();
    }
  }

  static ArchiveFile _stored(String name, List<int> bytes) =>
      ArchiveFile.noCompress(name, bytes.length, bytes);

  /// Open a backup for reading. Throws [BackupFormatException] for a file that
  /// is not one, or one this app cannot read.
  static BackupReader open(File file) {
    final input = InputFileStream(file.path);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const BackupFormatException(BackupProblem.notABackup);
      }
      final manifestEntry = archive.findFile(manifestName);
      if (manifestEntry == null) {
        throw const BackupFormatException(BackupProblem.notABackup);
      }
      final Object? json;
      try {
        json = jsonDecode(utf8.decode(manifestEntry.content));
      } on FormatException {
        throw const BackupFormatException(BackupProblem.notABackup);
      }
      return BackupReader._(archive, input, BackupManifest.fromJson(json));
    } catch (_) {
      // The file stays open otherwise, and cannot even be deleted on Windows.
      input.closeSync();
      rethrow;
    }
  }
}

/// The folders and notes of a backup, decrypted.
class BackupContents {
  const BackupContents({required this.folders, required this.notes});

  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> notes;
}

class BackupReader {
  BackupReader._(this._archive, this._input, this.manifest);

  final Archive _archive;
  final InputFileStream _input;
  final BackupManifest manifest;

  /// Whether [cipher] holds the key this backup was made with.
  bool keyMatches(BackupCipher cipher) {
    try {
      return cipher.decrypt(manifest.keyCheck) == BackupArchive.keyCheckText;
    } catch (_) {
      return false;
    }
  }

  /// Decrypt the folders and notes. Throws [BackupFormatException] with
  /// [BackupProblem.otherAccount] when the key does not match.
  BackupContents read(BackupCipher cipher) {
    if (!keyMatches(cipher)) {
      throw const BackupFormatException(BackupProblem.otherAccount);
    }
    final entry = _archive.findFile(BackupArchive.notesName);
    if (entry == null) throw const BackupFormatException(BackupProblem.notABackup);
    final Object? json;
    try {
      json = jsonDecode(cipher.decrypt(utf8.decode(entry.content)));
    } on FormatException {
      throw const BackupFormatException(BackupProblem.notABackup);
    }
    if (json is! Map) throw const BackupFormatException(BackupProblem.notABackup);
    List<Map<String, dynamic>> list(Object? v) => [
          if (v is List)
            for (final e in v)
              if (e is Map) Map<String, dynamic>.from(e),
        ];
    return BackupContents(folders: list(json['folders']), notes: list(json['notes']));
  }

  /// The recording stored for [noteUuid] and its file extension, decrypted, or
  /// null when the backup has none for it.
  ({Uint8List bytes, String extension})? recording(String noteUuid, BackupCipher cipher) {
    final prefix = '${BackupArchive.recordingsDir}$noteUuid.';
    for (final file in _archive.files) {
      if (!file.isFile || !file.name.startsWith(prefix) || !file.name.endsWith('.enc')) {
        continue;
      }
      final extension =
          file.name.substring(prefix.length, file.name.length - '.enc'.length);
      return (bytes: cipher.decryptBytes(file.content), extension: extension);
    }
    return null;
  }

  Future<void> close() async {
    await _archive.clear();
    _input.closeSync();
  }
}
