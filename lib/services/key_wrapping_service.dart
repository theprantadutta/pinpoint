import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2.dart';

/// Phase 4 (F1/F4) — zero-knowledge key wrapping primitives.
///
/// The note data key (DK) never changes. In zero-knowledge mode it is *wrapped*
/// (encrypted) twice with secrets the server never sees:
///   - by a master key derived from the user's passphrase (Argon2id), and
///   - by a recovery key derived from a one-time recovery code,
/// so either secret can unwrap the same DK. The server only ever stores the
/// wrapped blobs + KDF salt/params, so it cannot decrypt notes.
///
/// This file is pure logic (no I/O, no platform channels) so it is fully unit
/// testable. A wrong passphrase surfaces as a GCM authentication failure when
/// unwrapping — no separate verifier is needed.
class KeyWrappingService {
  static const int _saltLength = 16;
  static const int _ivLength = 12; // AES-GCM nonce
  static const int _keyLength = 32; // AES-256
  static const int _recoverySeedLength = 20; // 160-bit -> 32 base32 chars

  /// Argon2id cost. Tuned for a once-per-week mobile unlock: 64 MiB, 3 passes.
  /// Persisted alongside the wrapped key so it can be changed later without
  /// breaking existing accounts.
  static KeyWrapParams defaultParams() =>
      const KeyWrapParams(iterations: 3, memoryKiB: 65536, lanes: 1);

  static final Random _rng = Random.secure();

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  /// Random per-user salt for passphrase derivation.
  static Uint8List generateSalt() => _randomBytes(_saltLength);

  /// Derive a 256-bit master key from a passphrase using Argon2id.
  static Uint8List deriveMasterKey(
    String passphrase,
    Uint8List salt,
    KeyWrapParams params,
  ) {
    final argonParams = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: _keyLength,
      iterations: params.iterations,
      memory: params.memoryKiB,
      lanes: params.lanes,
      version: Argon2Parameters.ARGON2_VERSION_13,
    );
    final generator = Argon2BytesGenerator()..init(argonParams);
    final out = Uint8List(_keyLength);
    generator.deriveKey(
      Uint8List.fromList(utf8.encode(passphrase)),
      0,
      out,
      0,
    );
    return out;
  }

  /// Wrap [dataKey] with [wrappingKey] (master or recovery key) via AES-GCM.
  /// Output is base64 of `[iv(12)][ciphertext + 128-bit tag]`.
  static String wrapKey(Uint8List dataKey, Uint8List wrappingKey) {
    final gcm = enc.Encrypter(enc.AES(enc.Key(wrappingKey), mode: enc.AESMode.gcm));
    final iv = enc.IV.fromSecureRandom(_ivLength);
    final encrypted = gcm.encryptBytes(dataKey, iv: iv);

    final out = BytesBuilder(copy: false)
      ..add(iv.bytes)
      ..add(encrypted.bytes);
    return base64Encode(out.toBytes());
  }

  /// Unwrap a blob from [wrapKey]. Throws on a wrong key or tampering
  /// (GCM authentication failure).
  static Uint8List unwrapKey(String wrappedBase64, Uint8List wrappingKey) {
    final blob = base64Decode(wrappedBase64);
    if (blob.length <= _ivLength) {
      throw const FormatException('Wrapped key blob is too short.');
    }
    final iv = enc.IV(Uint8List.fromList(blob.sublist(0, _ivLength)));
    final cipher = enc.Encrypted(Uint8List.fromList(blob.sublist(_ivLength)));
    final gcm = enc.Encrypter(enc.AES(enc.Key(wrappingKey), mode: enc.AESMode.gcm));
    return Uint8List.fromList(gcm.decryptBytes(cipher, iv: iv));
  }

  /// Generate a one-time recovery code. Returns the human-facing string
  /// (grouped base32, e.g. `ABCD-EFGH-...`) and the recovery key derived from
  /// it. The code alone is sufficient to recover — nothing else is stored.
  static RecoveryCode generateRecoveryCode() {
    final seed = _randomBytes(_recoverySeedLength);
    final code = _group(_base32Encode(seed));
    return RecoveryCode(code: code, key: _recoveryKeyFromSeed(seed));
  }

  /// Re-derive the recovery key from a (possibly messily formatted) code.
  /// Throws [FormatException] if the code isn't valid base32.
  static Uint8List recoveryKeyFromCode(String code) {
    final seed = _base32Decode(_normalize(code));
    if (seed.length != _recoverySeedLength) {
      throw const FormatException('Invalid recovery code length.');
    }
    return _recoveryKeyFromSeed(seed);
  }

  // The recovery code is already high-entropy, so a single SHA-256 is an
  // adequate (and fast) KDF — no need for the slow Argon2 used on passphrases.
  static Uint8List _recoveryKeyFromSeed(Uint8List seed) =>
      SHA256Digest().process(seed);

  // --- base32 (RFC 4648, no padding) ----------------------------------------

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static String _base32Encode(Uint8List data) {
    final buffer = StringBuffer();
    var bits = 0;
    var value = 0;
    for (final b in data) {
      value = (value << 8) | b;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        buffer.write(_alphabet[(value >> bits) & 0x1f]);
      }
    }
    if (bits > 0) {
      buffer.write(_alphabet[(value << (5 - bits)) & 0x1f]);
    }
    return buffer.toString();
  }

  static Uint8List _base32Decode(String input) {
    final out = <int>[];
    var bits = 0;
    var value = 0;
    for (final ch in input.split('')) {
      final idx = _alphabet.indexOf(ch);
      if (idx < 0) {
        throw FormatException('Invalid base32 character: $ch');
      }
      value = (value << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((value >> bits) & 0xff);
      }
    }
    return Uint8List.fromList(out);
  }

  /// Normalize user input: uppercase, strip anything outside the base32 set
  /// (spaces, dashes, ambiguous typing). Maps common look-alikes 0->O, 1->I.
  static String _normalize(String code) => code
      .toUpperCase()
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('8', 'B')
      .split('')
      .where((c) => _alphabet.contains(c))
      .join();

  /// Group into 4-char chunks separated by dashes for readability.
  static String _group(String s) {
    final parts = <String>[];
    for (var i = 0; i < s.length; i += 4) {
      parts.add(s.substring(i, min(i + 4, s.length)));
    }
    return parts.join('-');
  }
}

/// Argon2id cost parameters, serialized alongside the wrapped key.
@immutable
class KeyWrapParams {
  final int iterations;
  final int memoryKiB;
  final int lanes;

  // Defense-in-depth floor. The KDF params are stored server-side and read back
  // at unlock; enforcing a client-side minimum prevents a compromised/malicious
  // server from ever feeding weakened Argon2 params (e.g. t=1, m=1 KiB) into key
  // derivation. Matches the values in [KeyWrappingService.defaultParams].
  static const int _minIterations = 3;
  static const int _minMemoryKiB = 65536; // 64 MiB
  static const int _minLanes = 1;

  const KeyWrapParams({
    required this.iterations,
    required this.memoryKiB,
    required this.lanes,
  });

  Map<String, dynamic> toJson() => {
        'alg': 'argon2id',
        'v': 0x13,
        't': iterations,
        'm': memoryKiB,
        'p': lanes,
      };

  /// Parses params, rejecting anything below the security floor. Throws
  /// [FormatException] on missing fields or sub-floor cost, so a downgraded set
  /// of params can never be used to derive a key.
  factory KeyWrapParams.fromJson(Map<String, dynamic> json) {
    final iterations = json['t'] as int?;
    final memoryKiB = json['m'] as int?;
    final lanes = json['p'] as int?;
    if (iterations == null || memoryKiB == null || lanes == null) {
      throw const FormatException('Missing Argon2 KDF params (t/m/p).');
    }
    if (iterations < _minIterations ||
        memoryKiB < _minMemoryKiB ||
        lanes < _minLanes) {
      throw FormatException(
          'Argon2 KDF params below security floor '
          '(t=$iterations, m=$memoryKiB, p=$lanes).');
    }
    return KeyWrapParams(
      iterations: iterations,
      memoryKiB: memoryKiB,
      lanes: lanes,
    );
  }
}

/// A freshly generated recovery code and the key derived from it.
@immutable
class RecoveryCode {
  /// Human-facing grouped string to show the user once.
  final String code;

  /// The recovery key that wraps the data key.
  final Uint8List key;

  const RecoveryCode({required this.code, required this.key});
}
