import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'backend_auth_service.dart';
import 'encryption_key_errors.dart';
import 'zero_knowledge_service.dart';

class SecureEncryptionService {
  static const _storage = FlutterSecureStorage();
  static const String _keyStorageKey = 'encryption_key';

  /// Envelope version written by [encrypt]. v2 = authenticated AES-GCM.
  static const int _currentEnvelopeVersion = 2;

  /// GCM nonce length (96-bit, the NIST-recommended size for AES-GCM).
  static const int _gcmIvLength = 12;

  // The same data key (DK) drives both ciphers:
  //  - _gcm: authenticated AES-GCM, used for ALL new writes (envelope v2).
  //  - _cbc: legacy unauthenticated AES-CBC, used ONLY to decrypt pre-existing
  //    v1 notes so nothing a user already saved becomes unreadable.
  static enc.Encrypter? _gcm;
  static enc.Encrypter? _cbc;
  static bool _keySyncedThisSession = false;

  /// The account whose key was synced, so another account signing in during
  /// the same app session fetches its own instead of skipping.
  static String? _keySyncedForAccount;

  /// Drop the data key from memory and allow the next account to fetch its
  /// own. Called on sign-out, which also deletes the stored key.
  ///
  /// Without this the ciphers outlived sign-out: the next account signing in
  /// without an app restart skipped its key sync ("already synced this
  /// session") and tried to read its notes with the previous account's key.
  static void forgetKey() {
    _gcm = null;
    _cbc = null;
    _keySyncedThisSession = false;
    _keySyncedForAccount = null;
  }

  // Initialize the encryption service
  // apiService is optional - if provided, will sync key with cloud
  static Future<void> initialize({dynamic apiService}) async {
    final key = await _getOrCreateKey(apiService: apiService);
    _applyKey(key);
  }

  /// Builds both the GCM (new writes) and CBC (legacy reads) ciphers from the
  /// same data key.
  static void _applyKey(enc.Key key) {
    _gcm = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    _cbc = enc.Encrypter(enc.AES(key)); // defaults to AES-CBC (legacy v1)
  }

  /// Test-only: load a fixed key without touching platform secure storage.
  @visibleForTesting
  static void debugInitializeWithKey(enc.Key key) => _applyKey(key);

  /// Whether a data key already exists in local secure storage. Used to avoid
  /// generating a divergent key for a zero-knowledge account on a fresh device
  /// (such accounts must obtain the key by unwrapping, never by generation).
  static Future<bool> hasLocalKey() async {
    final keyString = await _storage.read(key: _keyStorageKey);
    return keyString != null && keyString.isNotEmpty;
  }

  /// Export the raw data-key bytes (for zero-knowledge wrapping). Reads the key
  /// from secure storage; returns null if no key exists yet.
  static Future<Uint8List?> exportDataKeyBytes() async {
    final keyString = await _storage.read(key: _keyStorageKey);
    if (keyString == null || keyString.isEmpty) return null;
    return enc.Key.fromBase64(keyString).bytes;
  }

  /// Load a data key directly from raw bytes (e.g. after a zero-knowledge
  /// unlock), persist it locally, and activate the ciphers. Unlike
  /// [initialize], this NEVER generates a new key — so a zero-knowledge account
  /// can only ever use the key recovered by unwrapping, not a divergent one.
  static Future<void> applyDataKeyBytes(Uint8List keyBytes) async {
    final key = enc.Key(keyBytes);
    await _storage.write(key: _keyStorageKey, value: key.base64);
    _applyKey(key);
    _confirm();
  }

  // Local key first; otherwise this account's key from the server, or a new
  // one only once the server has confirmed it has none. Without [apiService]
  // (signed out) a local key is made and never uploaded from here.
  static Future<enc.Key> _getOrCreateKey({dynamic apiService}) async {
    final keyString = await _storage.read(key: _keyStorageKey);
    if (keyString != null) {
      debugPrint('🔑 [Encryption] Using existing local encryption key');
      return enc.Key.fromBase64(keyString);
    }

    if (apiService != null) {
      if (await syncKeyFromCloud(apiService, force: true)) {
        return enc.Key.fromBase64((await _storage.read(key: _keyStorageKey))!);
      }
      throw const KeyRecoveryPendingException();
    }

    debugPrint('🔑 [Encryption] Generating a local encryption key');
    final key = enc.Key.fromSecureRandom(32);
    await _storage.write(key: _keyStorageKey, value: key.base64);
    return key;
  }

  /// Manually sync local encryption key to cloud
  static Future<bool> syncKeyToCloud(dynamic apiService) async {
    try {
      String? keyString = await _storage.read(key: _keyStorageKey);
      if (keyString == null) {
        debugPrint('⚠️ [Encryption] No local key to sync');
        return false;
      }

      debugPrint('☁️ [Encryption] Syncing key to cloud...');
      await apiService.storeEncryptionKey(keyString);
      debugPrint('✅ [Encryption] Key synced to cloud successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [Encryption] Failed to sync key to cloud: $e');
      return false;
    }
  }

  /// Whether this signed-in account's key is the one in use: read from the
  /// server, registered by this device, or (zero-knowledge) unwrapped.
  static bool get keyConfirmedForCurrentAccount =>
      _keySyncedThisSession && _keySyncedForAccount == BackendAuthService().userId && isInitialized;

  static void _confirm() {
    _keySyncedThisSession = true;
    _keySyncedForAccount = BackendAuthService().userId;
  }

  /// Make sure this account's key is the one in use, or report that it is
  /// not available yet. Sync calls this first: notes encrypted with any
  /// other key could never be read on another device.
  static Future<bool> ensureAccountKey(dynamic apiService) async {
    if (keyConfirmedForCurrentAccount) return true;
    try {
      return await syncKeyFromCloud(apiService);
    } catch (e) {
      debugPrint('⚠️ [Encryption] Account key not available yet: $e');
      return false;
    }
  }

  /// Bring this account's key in from the server, or register one if the
  /// server confirms it has none. Returns false when that cannot be settled
  /// now (offline, server error): nothing is generated or uploaded then.
  ///
  /// A zero-knowledge account is never asked for, or given, a raw key; its
  /// key comes from unwrapping ([applyDataKeyBytes]).
  ///
  /// Once per session per account unless [force].
  static Future<bool> syncKeyFromCloud(dynamic apiService, {int maxRetries = 2, bool force = false}) async {
    if (keyConfirmedForCurrentAccount && !force) {
      debugPrint('⏭️ [Encryption] Key already synced this session, skipping');
      return true;
    }

    if (await ZeroKnowledgeService.isZeroKnowledge()) {
      if (isInitialized) _confirm();
      return isInitialized;
    }

    // One extra round for the race where another device registers first.
    for (int attempt = 1; attempt <= maxRetries + 1; attempt++) {
      try {
        debugPrint('🔄 [Encryption] Fetching encryption key from cloud (attempt $attempt)...');
        final cloudKey = await apiService.getEncryptionKey();

        if (cloudKey != null) {
          await _storage.write(key: _keyStorageKey, value: cloudKey);
          _applyKey(enc.Key.fromBase64(cloudKey));
          _confirm();
          debugPrint('✅ [Encryption] Using the account key from cloud');
          return true;
        }

        // Confirmed: this account has no key yet. Register the local one (or
        // a new one). The server is create-only, so this can never replace a
        // key another device stored.
        var local = await _storage.read(key: _keyStorageKey);
        if (local == null) {
          local = enc.Key.fromSecureRandom(32).base64;
          await _storage.write(key: _keyStorageKey, value: local);
        }
        await apiService.storeEncryptionKey(local);
        _applyKey(enc.Key.fromBase64(local));
        _confirm();
        debugPrint('✅ [Encryption] Registered this account\'s first key');
        return true;
      } on EncryptionKeyExistsException {
        debugPrint('ℹ️ [Encryption] Another device registered first; reading its key');
        continue;
      } on ZeroKnowledgeAccountException {
        debugPrint('ℹ️ [Encryption] Zero-knowledge account: no raw key to sync');
        return false;
      } catch (e) {
        debugPrint('❌ [Encryption] Attempt $attempt failed: $e');
        if (attempt > maxRetries) return false;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  // Encrypt with a fresh random nonce, using authenticated AES-GCM (envelope v2).
  static String encrypt(String plainText) {
    if (_gcm == null) {
      throw Exception(
          'EncryptionService not initialized. Call initialize() first.');
    }

    // Fresh random 96-bit nonce for every message.
    final iv = enc.IV.fromSecureRandom(_gcmIvLength);
    final encrypted = _gcm!.encrypt(plainText, iv: iv);

    // Self-describing envelope so decrypt() can route by version. The GCM
    // auth tag is included in `data` (the encrypt package appends it).
    final combined = {
      'v': _currentEnvelopeVersion,
      'iv': iv.base64,
      'data': encrypted.base64,
    };

    return base64Encode(utf8.encode(json.encode(combined)));
  }

  // Decrypt by extracting the version, IV and data. Supports both the new
  // authenticated v2 (AES-GCM) and the legacy v1 (AES-CBC) envelopes so notes
  // saved before this change stay readable. v1 has no 'v' field.
  static String decrypt(String encryptedText) {
    if (_gcm == null || _cbc == null) {
      throw Exception(
          'EncryptionService not initialized. Call initialize() first.');
    }

    try {
      // Decode the combined data
      final decodedBytes = base64Decode(encryptedText);
      final decodedString = utf8.decode(decodedBytes);
      final combined = json.decode(decodedString) as Map<String, dynamic>;

      final version = (combined['v'] as int?) ?? 1;
      final iv = enc.IV.fromBase64(combined['iv'] as String);
      final encryptedData = enc.Encrypted.fromBase64(combined['data'] as String);

      if (version >= 2) {
        // Authenticated: throws if the ciphertext or tag was tampered with.
        return _gcm!.decrypt(encryptedData, iv: iv);
      }
      return _cbc!.decrypt(encryptedData, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt data: $e');
    }
  }

  /// Whether [stored] is a legacy v1 (unauthenticated AES-CBC) envelope, i.e.
  /// one that should be re-encrypted as authenticated v2 (AES-GCM). A v1
  /// envelope has no `v` field (treated as version 1). Returns false for
  /// anything that isn't a parseable envelope, so v2/GCM and unknown data are
  /// left untouched. Used by the lazy v1->v2 migration on sync.
  static bool isLegacyEnvelope(String stored) {
    try {
      final decoded =
          json.decode(utf8.decode(base64Decode(stored))) as Map<String, dynamic>;
      final version = (decoded['v'] as int?) ?? 1;
      return version < 2;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // Binary blob encryption (Phase 3 / F5) — used for audio files.
  //
  // Produces a self-describing blob so it can be told apart from a legacy,
  // unencrypted file already stored on the server:
  //   [magic "PPAENC" (6)] [version (1)] [iv (12)] [ciphertext + GCM tag]
  // ===========================================================================

  /// Magic prefix identifying a Pinpoint-encrypted binary blob ("PPAENC").
  static const List<int> _blobMagic = [0x50, 0x50, 0x41, 0x45, 0x4E, 0x43];

  /// True if [data] starts with our magic header (i.e. it's encrypted by us).
  /// Lets callers leave pre-existing plaintext audio untouched.
  static bool isEncryptedBlob(Uint8List data) {
    if (data.length < _blobMagic.length) return false;
    for (var i = 0; i < _blobMagic.length; i++) {
      if (data[i] != _blobMagic[i]) return false;
    }
    return true;
  }

  /// Encrypts arbitrary bytes with authenticated AES-GCM into a magic-prefixed
  /// blob. Used for audio before upload so the server only ever sees ciphertext.
  static Uint8List encryptBytes(Uint8List plain) {
    if (_gcm == null) {
      throw Exception(
          'EncryptionService not initialized. Call initialize() first.');
    }

    final iv = enc.IV.fromSecureRandom(_gcmIvLength);
    final encrypted = _gcm!.encryptBytes(plain, iv: iv);

    final out = BytesBuilder(copy: false);
    out.add(_blobMagic);
    out.addByte(_currentEnvelopeVersion);
    out.add(iv.bytes);
    out.add(encrypted.bytes); // ciphertext + 128-bit auth tag
    return out.toBytes();
  }

  /// Decrypts a blob produced by [encryptBytes]. Throws if it isn't our format
  /// or if authentication fails (tampered/corrupt data).
  static Uint8List decryptBytes(Uint8List blob) {
    if (_gcm == null) {
      throw Exception(
          'EncryptionService not initialized. Call initialize() first.');
    }
    if (!isEncryptedBlob(blob)) {
      throw Exception('Not a Pinpoint-encrypted blob (missing magic header).');
    }

    final headerLen = _blobMagic.length + 1; // magic + version byte
    final ivBytes = blob.sublist(headerLen, headerLen + _gcmIvLength);
    final cipherBytes = blob.sublist(headerLen + _gcmIvLength);

    final decrypted = _gcm!.decryptBytes(
      enc.Encrypted(Uint8List.fromList(cipherBytes)),
      iv: enc.IV(Uint8List.fromList(ivBytes)),
    );
    return Uint8List.fromList(decrypted);
  }

  // Optional: Clear stored key (useful for logout/reset)
  static Future<void> clearKey() async {
    await _storage.delete(key: _keyStorageKey);
    _gcm = null;
    _cbc = null;
  }

  // Optional: Check if service is initialized
  static bool get isInitialized => _gcm != null;
}
