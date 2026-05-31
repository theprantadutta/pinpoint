import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

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

  // Get existing key or create a new one
  // Priority: Local storage > Cloud backup > Generate new
  static Future<enc.Key> _getOrCreateKey({dynamic apiService}) async {
    // 1. Try to get key from local storage first
    String? keyString = await _storage.read(key: _keyStorageKey);

    if (keyString != null) {
      debugPrint('🔑 [Encryption] Using existing local encryption key');
      return enc.Key.fromBase64(keyString);
    }

    // 2. Try to fetch key from cloud if apiService is provided and user is authenticated
    if (apiService != null) {
      try {
        debugPrint(
            '🔑 [Encryption] No local key found, fetching from cloud...');
        final cloudKey = await apiService.getEncryptionKey();
        if (cloudKey != null) {
          debugPrint('✅ [Encryption] Retrieved encryption key from cloud');
          // Save to local storage for future use
          await _storage.write(key: _keyStorageKey, value: cloudKey);
          return enc.Key.fromBase64(cloudKey);
        }
      } catch (e) {
        debugPrint('⚠️ [Encryption] Failed to fetch key from cloud: $e');
        // Continue to generate new key
      }
    }

    // 3. Generate a new random key
    debugPrint('🔑 [Encryption] Generating new encryption key');
    final key = enc.Key.fromSecureRandom(32);
    final keyBase64 = key.base64;
    await _storage.write(key: _keyStorageKey, value: keyBase64);

    // Upload new key to cloud if apiService is provided
    if (apiService != null) {
      try {
        debugPrint('☁️ [Encryption] Uploading new key to cloud...');
        await apiService.storeEncryptionKey(keyBase64);
        debugPrint('✅ [Encryption] Key uploaded to cloud successfully');
      } catch (e) {
        debugPrint('⚠️ [Encryption] Failed to upload key to cloud: $e');
        // Not critical - key is still stored locally
      }
    }

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

  /// Force fetch encryption key from cloud and replace local key
  /// Use this after login to ensure we have the correct key from cloud
  /// Includes fast retry logic for reliability
  /// Only syncs once per session unless [force] is true
  static Future<bool> syncKeyFromCloud(dynamic apiService, {int maxRetries = 2, bool force = false}) async {
    // Skip if already synced this session (unless forced)
    if (_keySyncedThisSession && !force) {
      debugPrint('⏭️ [Encryption] Key already synced this session, skipping');
      return true;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔄 [Encryption] Fetching encryption key from cloud (attempt $attempt/$maxRetries)...');
        final cloudKey = await apiService.getEncryptionKey();

        if (cloudKey != null) {
          debugPrint(
              '✅ [Encryption] Retrieved key from cloud, replacing local key');

          // Replace local key with cloud key
          await _storage.write(key: _keyStorageKey, value: cloudKey);

          // Reinitialize ciphers with new key
          _applyKey(enc.Key.fromBase64(cloudKey));

          _keySyncedThisSession = true;
          debugPrint('✅ [Encryption] Successfully synced key from cloud');
          return true;
        } else {
          debugPrint('ℹ️ [Encryption] No key found in cloud');

          // Upload current local key to cloud if we have one
          String? localKey = await _storage.read(key: _keyStorageKey);
          if (localKey != null) {
            debugPrint('☁️ [Encryption] Uploading local key to cloud...');
            await apiService.storeEncryptionKey(localKey);
            _keySyncedThisSession = true;
            debugPrint('✅ [Encryption] Local key uploaded to cloud');
            return true;
          }

          return false;
        }
      } catch (e) {
        debugPrint('❌ [Encryption] Attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          // Fast retry - only 500ms delay
          debugPrint('⏳ [Encryption] Retrying in 500ms...');
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          debugPrint('❌ [Encryption] All $maxRetries attempts failed to sync key from cloud');
          return false;
        }
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
