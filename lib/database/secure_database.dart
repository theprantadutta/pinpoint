import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

// At-rest encryption for the local Drift/SQLite database (Phase 1 / F2).
//
// The native library is "SQLite Multiple Ciphers" (selected via the `hooks:`
// block in pubspec.yaml), which supports PRAGMA key / rekey. The on-device file
// is encrypted with a 256-bit key kept in the platform keystore
// (FlutterSecureStorage). That DB key is SEPARATE from the note data-key (DK)
// used for sync — compromising one does not reveal the other.
//
// Existing users have plaintext databases. On first launch after this change we
// migrate them to encrypted with a strict no-data-loss protocol: copy ->
// rekey the copy -> verify -> swap, always keeping the original as a
// `.plaintext.bak` until a clean encrypted launch succeeds.

const String _dbFileName = 'pinpoint.sqlite';

/// Versioned so we can rotate the storage slot later without colliding.
const String _dbKeyStorageKey = 'db_at_rest_key_v1';

const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Opens the app database backed by a SQLCipher/sqlite3mc-encrypted file.
///
/// Returns a [LazyDatabase] so all async work (key read, migration) runs on the
/// main isolate where platform channels (secure storage, path_provider) work.
LazyDatabase openSecureDatabase() {
  return LazyDatabase(() async {
    // sqlite3 cannot use the system temp dir on Android (sandboxed); point it
    // at the app cache, mirroring what drift_flutter used to do for us.
    try {
      sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
    } catch (_) {
      // Non-fatal: only affects spill-to-disk for large temp results.
    }

    final keyHex = await _getOrCreateDbKey();
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, _dbFileName));

    await _migratePlaintextToEncryptedIfNeeded(dbFile, keyHex);

    return NativeDatabase(
      dbFile,
      setup: (db) {
        db.execute("PRAGMA key = '$keyHex';");
        _assertEncryptionActive(db);
        // Proves the key is correct and the file is readable.
        db.select('SELECT count(*) FROM sqlite_master;');
      },
    );
  });
}

/// HARD SAFETY GATE: never allow a silent fallback to plain SQLite.
///
/// If the plain `sqlite3` library were loaded instead of the multiple-ciphers
/// build, `PRAGMA key` is a no-op and we'd be writing PLAINTEXT while believing
/// it is encrypted. The `sqlite3mc_version()` SQL function exists ONLY in the
/// multiple-ciphers library (verified present in the bundled libsqlite3mc.so),
/// so its absence proves the wrong library is loaded — fail loudly then.
///
/// Note: SQLCipher's `PRAGMA cipher_version` is NOT implemented by sqlite3mc,
/// so it must not be used here (it returns empty even when encryption is on).
void _assertEncryptionActive(CommonDatabase db) {
  String? version;
  try {
    final result = db.select('SELECT sqlite3mc_version() AS v;');
    version = result.isNotEmpty ? result.first['v'] as String? : null;
  } catch (_) {
    version = null; // function missing => plain sqlite3 is loaded
  }
  if (version == null || version.isEmpty) {
    throw StateError(
      'Database encryption library (SQLite Multiple Ciphers) is not active. '
      'Refusing to open the database unencrypted.',
    );
  }
}

Future<String> _getOrCreateDbKey() async {
  final existing = await _secureStorage.read(key: _dbKeyStorageKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  await _secureStorage.write(key: _dbKeyStorageKey, value: hex);
  return hex;
}

/// Migrates a legacy plaintext database to an encrypted one, with no data loss.
///
/// Protocol (each step verified before the next):
///   1. If the file is already encrypted with our key -> nothing to do.
///   2. If it isn't plaintext either -> refuse (could be a wrong/lost key);
///      never clobber unknown data.
///   3. Copy the plaintext file, then `PRAGMA rekey` the COPY (never the
///      original) so encryption happens off to the side.
///   4. Verify the encrypted copy opens with the key and has >= the original's
///      schema-object count.
///   5. Only then rename original -> `.plaintext.bak` and copy -> live file.
Future<void> _migratePlaintextToEncryptedIfNeeded(
  File dbFile,
  String keyHex,
) async {
  if (!dbFile.existsSync()) return; // fresh install -> created encrypted directly

  // 1. Already encrypted with our key?
  if (_canOpenEncrypted(dbFile.path, keyHex)) {
    // The DB is proven encrypted-and-openable, so a previous launch's migration
    // succeeded AND the app survived to this launch. The plaintext safety-net
    // backup is no longer needed — remove the lingering cleartext copy now.
    _deleteStalePlaintextBackup(dbFile);
    return;
  }

  // 2. Is it a readable plaintext database?
  final beforeCount = _plaintextSchemaCount(dbFile.path);
  if (beforeCount == null) {
    throw StateError(
      '$_dbFileName is neither plaintext nor decryptable with the stored key. '
      'Refusing to migrate to avoid data loss.',
    );
  }

  // 3. Encrypt a COPY in place via rekey (original stays untouched until step 5).
  final encPath = '${dbFile.path}.enc.tmp';
  final encFile = File(encPath);
  if (encFile.existsSync()) encFile.deleteSync();
  dbFile.copySync(encPath);

  final copy = sqlite3.open(encPath);
  try {
    copy.execute("PRAGMA rekey = '$keyHex';");
    copy.select('SELECT count(*) FROM sqlite_master;'); // readable post-rekey
  } finally {
    copy.close();
  }

  // 4. Independently verify the encrypted copy before trusting it.
  final afterCount = _encryptedSchemaCount(encPath, keyHex);
  if (afterCount == null || afterCount < beforeCount) {
    if (encFile.existsSync()) encFile.deleteSync();
    throw StateError(
      'Encrypted DB verification failed (before=$beforeCount, after=$afterCount). '
      'Original left untouched.',
    );
  }

  // 5. Swap, keeping the plaintext as a backup (verify-before-delete safety net).
  final bak = '${dbFile.path}.plaintext.bak';
  final bakFile = File(bak);
  if (bakFile.existsSync()) bakFile.deleteSync();
  dbFile.renameSync(bak);
  encFile.renameSync(dbFile.path);

  debugPrint(
    '🔐 [DB] Local database migrated to encrypted at-rest. '
    'Plaintext backup retained at $bak until the next successful launch.',
  );
}

/// Removes the plaintext `.plaintext.bak` safety net once the encrypted DB has
/// been confirmed openable on a later launch (so a cleartext copy never lingers
/// indefinitely, which would defeat the at-rest encryption).
void _deleteStalePlaintextBackup(File dbFile) {
  try {
    final bak = File('${dbFile.path}.plaintext.bak');
    if (bak.existsSync()) {
      bak.deleteSync();
      debugPrint('🔐 [DB] Removed plaintext backup after verified encrypted launch.');
    }
  } catch (e) {
    // Non-fatal: a leftover backup is a hygiene issue, not a correctness one.
    debugPrint('⚠️ [DB] Could not remove plaintext backup: $e');
  }
}

bool _canOpenEncrypted(String path, String keyHex) {
  try {
    final db = sqlite3.open(path);
    try {
      db.execute("PRAGMA key = '$keyHex';");
      db.select('SELECT count(*) FROM sqlite_master;');
      return true;
    } finally {
      db.close();
    }
  } catch (_) {
    return false;
  }
}

/// Schema-object count when opened as plaintext (no key). Null if it isn't a
/// readable plaintext database (e.g. it's encrypted with some other key).
int? _plaintextSchemaCount(String path) {
  try {
    final db = sqlite3.open(path);
    try {
      final r = db.select('SELECT count(*) AS c FROM sqlite_master;');
      return r.first['c'] as int;
    } finally {
      db.close();
    }
  } catch (_) {
    return null;
  }
}

int? _encryptedSchemaCount(String path, String keyHex) {
  try {
    final db = sqlite3.open(path);
    try {
      db.execute("PRAGMA key = '$keyHex';");
      final r = db.select('SELECT count(*) AS c FROM sqlite_master;');
      return r.first['c'] as int;
    } finally {
      db.close();
    }
  } catch (_) {
    return null;
  }
}
