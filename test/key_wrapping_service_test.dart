import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/services/key_wrapping_service.dart';

/// Phase 4a (F1/F4) tests for the zero-knowledge key-wrapping primitives.
void main() {
  // Light Argon2 cost so tests run fast; correctness is independent of cost.
  const fastParams = KeyWrapParams(iterations: 1, memoryKiB: 8192, lanes: 1);

  // Stand-in for the note data key (DK).
  final dataKey = Uint8List.fromList(List<int>.generate(32, (i) => (i * 7) % 256));

  test('Argon2id derivation is deterministic for the same inputs', () {
    final salt = KeyWrappingService.generateSalt();
    final a = KeyWrappingService.deriveMasterKey('hunter2', salt, fastParams);
    final b = KeyWrappingService.deriveMasterKey('hunter2', salt, fastParams);
    expect(a, equals(b));
    expect(a.length, 32);
  });

  test('different salts produce different master keys', () {
    final mk1 = KeyWrappingService.deriveMasterKey(
        'pass', KeyWrappingService.generateSalt(), fastParams);
    final mk2 = KeyWrappingService.deriveMasterKey(
        'pass', KeyWrappingService.generateSalt(), fastParams);
    expect(mk1, isNot(equals(mk2)));
  });

  test('passphrase wrap/unwrap round-trips the data key', () {
    final salt = KeyWrappingService.generateSalt();
    final mk = KeyWrappingService.deriveMasterKey('correct horse', salt, fastParams);

    final wrapped = KeyWrappingService.wrapKey(dataKey, mk);
    final unwrapped = KeyWrappingService.unwrapKey(wrapped, mk);

    expect(unwrapped, equals(dataKey));
  });

  test('wrong passphrase fails to unwrap (GCM auth failure)', () {
    final salt = KeyWrappingService.generateSalt();
    final mk = KeyWrappingService.deriveMasterKey('correct horse', salt, fastParams);
    final wrapped = KeyWrappingService.wrapKey(dataKey, mk);

    final wrongMk =
        KeyWrappingService.deriveMasterKey('wrong horse', salt, fastParams);
    expect(
      () => KeyWrappingService.unwrapKey(wrapped, wrongMk),
      throwsA(anything),
    );
  });

  test('recovery code round-trips the data key', () {
    final recovery = KeyWrappingService.generateRecoveryCode();
    final wrapped = KeyWrappingService.wrapKey(dataKey, recovery.key);

    final recoveredKey = KeyWrappingService.recoveryKeyFromCode(recovery.code);
    final unwrapped = KeyWrappingService.unwrapKey(wrapped, recoveredKey);

    expect(unwrapped, equals(dataKey));
  });

  test('recovery code is forgiving of messy formatting', () {
    final recovery = KeyWrappingService.generateRecoveryCode();
    final wrapped = KeyWrappingService.wrapKey(dataKey, recovery.key);

    // Lowercase, extra spaces, stray dashes — should still recover.
    final messy = '  ${recovery.code.toLowerCase().replaceAll('-', ' - ')}  ';
    final recoveredKey = KeyWrappingService.recoveryKeyFromCode(messy);

    expect(KeyWrappingService.unwrapKey(wrapped, recoveredKey), equals(dataKey));
  });

  test('recovery code is grouped and uses an unambiguous alphabet', () {
    final recovery = KeyWrappingService.generateRecoveryCode();
    expect(recovery.code, contains('-'));
    // No ambiguous characters in the display alphabet.
    expect(recovery.code.replaceAll('-', ''), matches(RegExp(r'^[A-Z2-7]+$')));
  });

  test('both passphrase and recovery independently unwrap the SAME data key',
      () {
    final salt = KeyWrappingService.generateSalt();
    final mk = KeyWrappingService.deriveMasterKey('my pass', salt, fastParams);
    final recovery = KeyWrappingService.generateRecoveryCode();

    final wrappedByPass = KeyWrappingService.wrapKey(dataKey, mk);
    final wrappedByRecovery = KeyWrappingService.wrapKey(dataKey, recovery.key);

    expect(KeyWrappingService.unwrapKey(wrappedByPass, mk), equals(dataKey));
    expect(
      KeyWrappingService.unwrapKey(
        wrappedByRecovery,
        KeyWrappingService.recoveryKeyFromCode(recovery.code),
      ),
      equals(dataKey),
    );
  });

  test('KeyWrapParams serializes round-trip', () {
    final p = KeyWrappingService.defaultParams();
    final restored = KeyWrapParams.fromJson(p.toJson());
    expect(restored.iterations, p.iterations);
    expect(restored.memoryKiB, p.memoryKiB);
    expect(restored.lanes, p.lanes);
  });

  group('KeyWrapParams.fromJson enforces a security floor', () {
    test('accepts default (floor) params', () {
      expect(() => KeyWrapParams.fromJson(KeyWrappingService.defaultParams().toJson()),
          returnsNormally);
    });

    test('rejects weakened params (a malicious server cannot downgrade the KDF)', () {
      expect(
        () => KeyWrapParams.fromJson(
            {'alg': 'argon2id', 'v': 0x13, 't': 1, 'm': 1024, 'p': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing params', () {
      expect(
        () => KeyWrapParams.fromJson({'alg': 'argon2id', 'v': 0x13, 't': 3}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
