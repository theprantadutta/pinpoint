import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/encryption_service.dart';

/// Phase 2 (F3) crypto tests: authenticated AES-GCM with a versioned envelope,
/// and backward-compatible decryption of legacy AES-CBC (v1) notes.
void main() {
  // Fixed 256-bit key so tests are deterministic.
  final key = enc.Key.fromBase64(base64Encode(List<int>.generate(32, (i) => i)));

  setUp(() {
    SecureEncryptionService.debugInitializeWithKey(key);
  });

  Map<String, dynamic> envelopeOf(String blob) =>
      json.decode(utf8.decode(base64Decode(blob))) as Map<String, dynamic>;

  String reseal(Map<String, dynamic> envelope) =>
      base64Encode(utf8.encode(json.encode(envelope)));

  /// Recreates the OLD v1 format: AES-CBC, 16-byte IV, no version field.
  String legacyCbcEncrypt(String plainText) {
    final cbc = enc.Encrypter(enc.AES(key)); // default mode = CBC
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = cbc.encrypt(plainText, iv: iv);
    return reseal({'iv': iv.base64, 'data': encrypted.base64});
  }

  test('GCM round-trips and writes a v2 envelope', () {
    const plain = 'my secret note 🔐 with unicode';
    final blob = SecureEncryptionService.encrypt(plain);

    expect(envelopeOf(blob)['v'], 2);
    expect(SecureEncryptionService.decrypt(blob), plain);
  });

  test('every encryption uses a fresh nonce (no IV reuse)', () {
    final a = envelopeOf(SecureEncryptionService.encrypt('same input'));
    final b = envelopeOf(SecureEncryptionService.encrypt('same input'));
    expect(a['iv'], isNot(equals(b['iv'])));
    expect(a['data'], isNot(equals(b['data'])));
  });

  test('tampered ciphertext is rejected (authenticated)', () {
    final blob = SecureEncryptionService.encrypt('integrity matters');
    final envelope = envelopeOf(blob);

    // Flip one byte of the ciphertext+tag.
    final data = base64Decode(envelope['data'] as String);
    data[0] = data[0] ^ 0x01;
    envelope['data'] = base64Encode(data);

    expect(
      () => SecureEncryptionService.decrypt(reseal(envelope)),
      throwsA(isA<Exception>()),
    );
  });

  test('legacy v1 (AES-CBC) notes still decrypt', () {
    const plain = 'an older note saved before GCM';
    final legacyBlob = legacyCbcEncrypt(plain);

    // No 'v' field on the legacy envelope.
    expect(envelopeOf(legacyBlob).containsKey('v'), isFalse);
    expect(SecureEncryptionService.decrypt(legacyBlob), plain);
  });

  test('re-encrypting a decrypted legacy note upgrades it to v2', () {
    const plain = 'note that should upgrade on write';
    final legacyBlob = legacyCbcEncrypt(plain);

    final decrypted = SecureEncryptionService.decrypt(legacyBlob);
    final reEncrypted = SecureEncryptionService.encrypt(decrypted);

    expect(envelopeOf(reEncrypted)['v'], 2);
    expect(SecureEncryptionService.decrypt(reEncrypted), plain);
  });

  // --- Phase 3 (F5): binary audio-blob encryption ---------------------------

  // Stand-in for raw audio bytes.
  final audio = Uint8List.fromList(
    List<int>.generate(5000, (i) => (i * 31 + 7) % 256),
  );

  test('binary blob round-trips and is marked encrypted', () {
    final blob = SecureEncryptionService.encryptBytes(audio);

    expect(SecureEncryptionService.isEncryptedBlob(blob), isTrue);
    expect(SecureEncryptionService.decryptBytes(blob), equals(audio));
  });

  test('plaintext (legacy) audio is not mistaken for an encrypted blob', () {
    // A real m4a starts with an ftyp box, never our "PPAENC" magic.
    final legacyAudio = Uint8List.fromList([
      0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, // ...ftyp
      ...List<int>.generate(200, (i) => i % 256),
    ]);
    expect(SecureEncryptionService.isEncryptedBlob(legacyAudio), isFalse);
  });

  test('tampered audio blob is rejected', () {
    final blob = SecureEncryptionService.encryptBytes(audio);
    // Flip a byte inside the ciphertext (past the 19-byte header).
    blob[25] = blob[25] ^ 0x01;
    expect(
      () => SecureEncryptionService.decryptBytes(blob),
      throwsA(isA<Exception>()),
    );
  });

  test('every audio encryption uses a fresh nonce', () {
    final a = SecureEncryptionService.encryptBytes(audio);
    final b = SecureEncryptionService.encryptBytes(audio);
    expect(a, isNot(equals(b)));
  });
}
