import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/encryption_service.dart';
import '../services/zero_knowledge_service.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

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
      appBar: AppBar(title: Text(AppL10n.of(context).encTitle)),
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
                    title: Text(isZk ? AppL10n.of(context).encMaxPrivacy : AppL10n.of(context).encStandard),
                    subtitle: Text(isZk
                        ? AppL10n.of(context).encMaxPrivacyDesc
                        : AppL10n.of(context).encStandardDesc),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isZk) ...[
                  Text(AppL10n.of(context).encUpgradeHeading,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(AppL10n.of(context).encWrapExplain),
                  const SizedBox(height: 12),
                  Text(AppL10n.of(context).encLoseBothWarning),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.lock_rounded),
                    label: Text(AppL10n.of(context).encEnableButton),
                    onPressed: _startEnableFlow,
                  ),
                ] else ...[
                  Text(AppL10n.of(context).encOnDescription),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text(AppL10n.of(context).encSwitchBackButton),
                    onPressed: _confirmDisable,
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _startEnableFlow() async {
    if (!SecureEncryptionService.isInitialized) {
      _toast(AppL10n.of(context).encStillInitializing);
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
          title: Text(AppL10n.of(context).encSetPassphraseTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: p1,
                obscureText: true,
                decoration: InputDecoration(labelText: AppL10n.of(context).encPassphrase),
              ),
              TextField(
                controller: p2,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: AppL10n.of(context).encConfirmPassphrase, errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppL10n.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () {
                if (p1.text.length < 8) {
                  setLocal(() => error = AppL10n.of(context).encPassphraseTooShort);
                  return;
                }
                if (p1.text != p2.text) {
                  setLocal(() => error = AppL10n.of(context).encPassphraseMismatch);
                  return;
                }
                Navigator.pop(ctx, p1.text);
              },
              child: Text(AppL10n.of(context).encContinue),
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
        title: Text(AppL10n.of(context).encSaveRecoveryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppL10n.of(context).encRecoveryOnlyWay),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 16, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: Text(AppL10n.of(context).encCopy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                _toast(AppL10n.of(context).encRecoveryCopied);
              },
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppL10n.of(context).encSavedIt),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppL10n.of(context).encSwitchBackTitle),
        content: Text(AppL10n.of(context).encSwitchBackBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppL10n.of(context).commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppL10n.of(context).encSwitchBack)),
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
      _toast(AppL10n.of(context).encSwitchedBack);
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
      if (!mounted) return null;
      Navigator.of(context, rootNavigator: true).pop();
      // Guarded above: the message is read off the context, and `action()`
      // may have taken long enough for this screen to be disposed.
      _toast(AppL10n.of(context).encSomethingWrong(e.toString()));
      return null;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
