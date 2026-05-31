import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/encryption_service.dart';
import '../services/zero_knowledge_service.dart';

/// Lets the user choose between Standard (server-managed key) and Maximum
/// Privacy (zero-knowledge: passphrase + recovery code). Opt-in; existing users
/// stay Standard until they choose otherwise.
class EncryptionSettingsScreen extends StatefulWidget {
  const EncryptionSettingsScreen({super.key});

  static const String kRouteName = '/encryption-settings';

  @override
  State<EncryptionSettingsScreen> createState() =>
      _EncryptionSettingsScreenState();
}

class _EncryptionSettingsScreenState extends State<EncryptionSettingsScreen> {
  final _api = ApiService();
  String _mode = ZeroKnowledgeService.modeStandard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await ZeroKnowledgeService.refreshModeFromServer(_api);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isZk = _mode == ZeroKnowledgeService.modeZeroKnowledge;
    return Scaffold(
      appBar: AppBar(title: const Text('Encryption')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      isZk ? Icons.verified_user_rounded : Icons.cloud_done_rounded,
                    ),
                    title: Text(isZk ? 'Maximum Privacy' : 'Standard'),
                    subtitle: Text(isZk
                        ? 'Only you can read your notes. We cannot — your key never leaves your device unwrapped.'
                        : 'Your notes are encrypted, but we hold a recovery copy of your key so you never get locked out.'),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isZk) ...[
                  Text('Upgrade to Maximum Privacy',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'You set an encryption passphrase. Your data key is wrapped with '
                    'it before it ever reaches our servers, so we can no longer read '
                    'your notes. You also get a one-time recovery code in case you '
                    'forget the passphrase.\n\n'
                    'Important: if you lose BOTH the passphrase and the recovery '
                    'code, your notes cannot be recovered by anyone.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('Enable Maximum Privacy'),
                    onPressed: _startEnableFlow,
                  ),
                ] else ...[
                  const Text(
                    'Maximum Privacy is on. You will be asked for your passphrase '
                    'on a new device and about once a week on this one.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: const Text('Switch back to Standard'),
                    onPressed: _confirmDisable,
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _startEnableFlow() async {
    if (!SecureEncryptionService.isInitialized) {
      _toast('Encryption is still initializing. Try again in a moment.');
      return;
    }
    final passphrase = await _promptNewPassphrase();
    if (passphrase == null) return;

    final code = await _runBusy(() =>
        ZeroKnowledgeService.enableZeroKnowledge(_api, passphrase));
    if (code == null) return;

    await _showRecoveryCode(code);
    if (!mounted) return;
    setState(() => _mode = ZeroKnowledgeService.modeZeroKnowledge);
  }

  Future<String?> _promptNewPassphrase() async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Set encryption passphrase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: p1,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Passphrase'),
              ),
              TextField(
                controller: p2,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: 'Confirm passphrase', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (p1.text.length < 8) {
                  setLocal(() => error = 'Use at least 8 characters');
                  return;
                }
                if (p1.text != p2.text) {
                  setLocal(() => error = 'Passphrases do not match');
                  return;
                }
                Navigator.pop(ctx, p1.text);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    p1.dispose();
    p2.dispose();
    return result;
  }

  Future<void> _showRecoveryCode(String code) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Save your recovery code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This is the ONLY way to recover your notes if you forget your '
              'passphrase. Store it somewhere safe. It will not be shown again.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 16, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                _toast('Recovery code copied');
              },
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I have saved it'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch back to Standard?'),
        content: const Text(
          'Your encryption key will be uploaded to our servers again so you '
          'never get locked out. This means we could technically read your '
          'notes. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch back')),
        ],
      ),
    );
    if (ok != true) return;

    final done = await _runBusy(() async {
      await ZeroKnowledgeService.disableZeroKnowledge(_api);
      return true;
    });
    if (done == true && mounted) {
      setState(() => _mode = ZeroKnowledgeService.modeStandard);
      _toast('Switched back to Standard');
    }
  }

  /// Runs [action] behind a modal spinner; returns its result or null on error.
  Future<T?> _runBusy<T>(Future<T> Function() action) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await action();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return result;
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _toast('Something went wrong: $e');
      return null;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
