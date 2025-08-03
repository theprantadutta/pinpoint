
import 'package:encrypt/encrypt.dart';

class EncryptionService {
  // For simplicity, using a fixed key. In a real app, this should be securely generated and stored.
  static final Key _key = Key.fromLength(32);
  static final IV _iv = IV.fromLength(16);
  static final Encrypter _encrypter = Encrypter(AES(_key));

  static String encrypt(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  static String decrypt(String encryptedText) {
    final decrypted = _encrypter.decrypt(Encrypted.fromBase64(encryptedText), iv: _iv);
    return decrypted;
  }
}
