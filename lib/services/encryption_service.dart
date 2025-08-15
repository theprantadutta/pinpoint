import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureEncryptionService {
  static const _storage = FlutterSecureStorage();
  static const String _keyStorageKey = 'encryption_key';
  static Encrypter? _encrypter;

  // Initialize the encryption service
  static Future<void> initialize() async {
    final key = await _getOrCreateKey();
    _encrypter = Encrypter(AES(key));
  }

  // Get existing key or create a new one
  static Future<Key> _getOrCreateKey() async {
    String? keyString = await _storage.read(key: _keyStorageKey);

    if (keyString == null) {
      // Generate a new random key
      final key = Key.fromSecureRandom(32);
      await _storage.write(key: _keyStorageKey, value: key.base64);
      return key;
    }

    return Key.fromBase64(keyString);
  }

  // Encrypt with random IV (more secure)
  static String encrypt(String plainText) {
    if (_encrypter == null) {
      throw Exception(
          'EncryptionService not initialized. Call initialize() first.');
    }

    // Generate a random IV for each encryption
    final iv = IV.fromSecureRandom(16);
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

      final iv = IV.fromBase64(combined['iv']);
      final encryptedData = Encrypted.fromBase64(combined['data']);

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
