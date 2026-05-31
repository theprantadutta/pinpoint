import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';
import 'encryption_service.dart';
import 'key_wrapping_service.dart';

/// Phase 4c (F1/F4) — orchestrates the two encryption modes.
///
/// - `standard` (default): the server holds the data key; nothing here changes
///   the existing behaviour. Every current user is in this mode.
/// - `zero_knowledge`: the data key is wrapped by a passphrase (Argon2id) and by
///   a recovery code; the server stores only wrapped material it cannot open.
///
/// The data key (DK) itself is never rotated when switching modes — only how it
/// is stored/recovered changes — so notes never become unreadable.
class ZeroKnowledgeService {
  static const String modeStandard = 'standard';
  static const String modeZeroKnowledge = 'zero_knowledge';

  /// Re-prompt the passphrase this often even though the key stays cached, so
  /// users keep it memorised (the user-chosen cadence).
  static const Duration relockAfter = Duration(days: 7);

  static const _modeKey = 'zk_mode';
  static const _lastUnlockKey = 'zk_last_unlock';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // --- mode state -----------------------------------------------------------

  static Future<String> cachedMode() async =>
      (await _storage.read(key: _modeKey)) ?? modeStandard;

  static Future<bool> isZeroKnowledge() async =>
      (await cachedMode()) == modeZeroKnowledge;

  /// Reconcile the locally cached mode with the server (call after login).
  /// Falls back to the cached value if the server can't be reached.
  static Future<String> refreshModeFromServer(ApiService api) async {
    try {
      final material = await api.getKeyMaterial();
      final mode = (material?['mode'] as String?) ?? modeStandard;
      await _storage.write(key: _modeKey, value: mode);
      return mode;
    } catch (e) {
      debugPrint('⚠️ [ZK] Could not refresh mode from server: $e');
      return cachedMode();
    }
  }

  /// Whether the UI must show an unlock screen before notes can be read.
  /// Always false for standard accounts (no behaviour change for them).
  static Future<bool> needsUnlock() async {
    if (!await isZeroKnowledge()) return false;

    // No usable key loaded yet (e.g. fresh install of a zero-knowledge account).
    if (!SecureEncryptionService.isInitialized) return true;

    final last = await _storage.read(key: _lastUnlockKey);
    final at = last == null ? null : DateTime.tryParse(last);
    if (at == null) return true;
    return DateTime.now().difference(at) > relockAfter;
  }

  // --- setup / upgrade ------------------------------------------------------

  /// Upgrade the current (standard) account to zero-knowledge.
  ///
  /// Wraps the EXISTING data key with the passphrase-derived master key and with
  /// a freshly generated recovery code, uploads the wrapped material (the server
  /// clears its plaintext key atomically), and returns the one-time recovery
  /// code to show the user once.
  static Future<String> enableZeroKnowledge(
    ApiService api,
    String passphrase,
  ) async {
    final dk = await SecureEncryptionService.exportDataKeyBytes();
    if (dk == null) {
      throw StateError('Encryption is not initialized; cannot enable zero-knowledge.');
    }

    final salt = KeyWrappingService.generateSalt();
    final params = KeyWrappingService.defaultParams();
    final masterKey = KeyWrappingService.deriveMasterKey(passphrase, salt, params);
    final recovery = KeyWrappingService.generateRecoveryCode();

    final wrappedKey = KeyWrappingService.wrapKey(dk, masterKey);
    final wrappedRecovery = KeyWrappingService.wrapKey(dk, recovery.key);

    await api.storeKeyMaterial(
      mode: modeZeroKnowledge,
      wrappedKey: wrappedKey,
      wrappedKeyRecovery: wrappedRecovery,
      kdfSalt: base64Encode(salt),
      kdfParams: params.toJson(),
    );

    await _storage.write(key: _modeKey, value: modeZeroKnowledge);
    await _markUnlockedNow();
    return recovery.code;
  }

  /// Revert to standard mode: re-upload the plaintext key so the account works
  /// seamlessly again. Requires the key to currently be unlocked/available.
  static Future<void> disableZeroKnowledge(ApiService api) async {
    final dk = await SecureEncryptionService.exportDataKeyBytes();
    if (dk == null) {
      throw StateError('Encryption is locked; unlock before disabling zero-knowledge.');
    }
    await api.storeKeyMaterial(
      mode: modeStandard,
      encryptionKey: base64Encode(dk),
    );
    await _storage.write(key: _modeKey, value: modeStandard);
  }

  // --- unlock ---------------------------------------------------------------

  /// Unlock with the passphrase. Returns true on success, false if the
  /// passphrase is wrong (GCM auth failure when unwrapping).
  static Future<bool> unlockWithPassphrase(
    ApiService api,
    String passphrase,
  ) =>
      _unlock(api, (material) {
        final salt = base64Decode(material['kdf_salt'] as String);
        final params = KeyWrapParams.fromJson(
            Map<String, dynamic>.from(material['kdf_params'] as Map));
        final mk = KeyWrappingService.deriveMasterKey(passphrase, salt, params);
        return KeyWrappingService.unwrapKey(material['wrapped_key'] as String, mk);
      });

  /// Unlock with the recovery code (e.g. forgotten passphrase / new device).
  static Future<bool> unlockWithRecoveryCode(
    ApiService api,
    String code,
  ) =>
      _unlock(api, (material) {
        final rk = KeyWrappingService.recoveryKeyFromCode(code);
        return KeyWrappingService.unwrapKey(
            material['wrapped_key_recovery'] as String, rk);
      });

  static Future<bool> _unlock(
    ApiService api,
    Uint8List Function(Map<String, dynamic> material) unwrap,
  ) async {
    final material = await api.getKeyMaterial();
    if (material == null || material['mode'] != modeZeroKnowledge) {
      return false;
    }
    try {
      final dk = unwrap(material);
      await SecureEncryptionService.applyDataKeyBytes(dk);
      await _markUnlockedNow();
      return true;
    } catch (e) {
      // Wrong passphrase/code or malformed input — never reveal which.
      return false;
    }
  }

  static Future<void> _markUnlockedNow() => _storage.write(
        key: _lastUnlockKey,
        value: DateTime.now().toIso8601String(),
      );

  /// Clear local zero-knowledge state (used on full sign-out/reset).
  static Future<void> clearLocalState() async {
    await _storage.delete(key: _modeKey);
    await _storage.delete(key: _lastUnlockKey);
  }
}
