import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class SecureEncryptionService {
  static const _storage = FlutterSecureStorage();
  static const String _keyStorageKey = 'encryption_key';
  static enc.Encrypter? _encrypter;

  // Initialize the encryption service
  // apiService is optional - if provided, will sync key with cloud
  static Future<void> initialize({dynamic apiService}) async {
    final key = await _getOrCreateKey(apiService: apiService);
    _encrypter = enc.Encrypter(enc.AES(key));
  }

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
  static Future<bool> syncKeyFromCloud(dynamic apiService) async {
    try {
      debugPrint('🔄 [Encryption] Force fetching encryption key from cloud...');
      final cloudKey = await apiService.getEncryptionKey();

      if (cloudKey != null) {
        debugPrint(
            '✅ [Encryption] Retrieved key from cloud, replacing local key');

        // Replace local key with cloud key
        await _storage.write(key: _keyStorageKey, value: cloudKey);

        // Reinitialize encrypter with new key
        final key = enc.Key.fromBase64(cloudKey);
        _encrypter = enc.Encrypter(enc.AES(key));

        debugPrint('✅ [Encryption] Successfully synced key from cloud');
        return true;
      } else {
        debugPrint('ℹ️ [Encryption] No key found in cloud');

        // Upload current local key to cloud if we have one
        String? localKey = await _storage.read(key: _keyStorageKey);
        if (localKey != null) {
          debugPrint('☁️ [Encryption] Uploading local key to cloud...');
          await apiService.storeEncryptionKey(localKey);
          debugPrint('✅ [Encryption] Local key uploaded to cloud');
          return true;
        }

        return false;
      }
    } catch (e) {
      debugPrint('❌ [Encryption] Failed to sync key from cloud: $e');
      return false;
    }
  }

  // Encrypt with random IV (more secure)
  static String encrypt(String plainText) {
    if (_encrypter == null) {
      throw Exception(
          'EncryptionService not initialized. Call initialize() first.');
    }

    // Generate a random IV for each encryption
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);

    // Combine IV and encrypted data
    final combined = {
      'iv': iv.base64,
      'data': encrypted.base64,
    };

    return base64Encode(utf8.encode(json.encode(combined)));
  }

  // Decrypt by extracting IV and data
  static String decrypt(String encryptedText) {
    if (_encrypter == null) {
      throw Exception(
          'EncryptionService not initialized. Call initialize() first.');
    }

    try {
      // Decode the combined data
      final decodedBytes = base64Decode(encryptedText);
      final decodedString = utf8.decode(decodedBytes);
      final combined = json.decode(decodedString) as Map<String, dynamic>;

      final iv = enc.IV.fromBase64(combined['iv']);
      final encryptedData = enc.Encrypted.fromBase64(combined['data']);

      return _encrypter!.decrypt(encryptedData, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt data: $e');
    }
  }

  // Optional: Clear stored key (useful for logout/reset)
  static Future<void> clearKey() async {
    await _storage.delete(key: _keyStorageKey);
    _encrypter = null;
  }

  // Optional: Check if service is initialized
  static bool get isInitialized => _encrypter != null;
}
