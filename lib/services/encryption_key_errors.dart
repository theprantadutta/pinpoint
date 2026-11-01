/// The server holds a different key for this account and never replaces it:
/// read that one instead (another device registered first).
class EncryptionKeyExistsException implements Exception {
  const EncryptionKeyExistsException();
  @override
  String toString() => 'EncryptionKeyExistsException';
}

/// The account is in zero-knowledge mode: it has no server-readable key and
/// accepts none. Its key comes from unwrapping with the passphrase.
class ZeroKnowledgeAccountException implements Exception {
  const ZeroKnowledgeAccountException();
  @override
  String toString() => 'ZeroKnowledgeAccountException';
}

/// This account's key could not be read (offline, server error) and there is
/// no local copy. Nothing is generated in its place: a guessed key would
/// encrypt new notes that no other device can read, and used to be uploaded
/// over the real one. Recovery is retried on the next sync.
class KeyRecoveryPendingException implements Exception {
  const KeyRecoveryPendingException();
  @override
  String toString() => 'KeyRecoveryPendingException';
}
