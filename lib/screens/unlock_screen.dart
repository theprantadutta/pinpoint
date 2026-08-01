import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/zero_knowledge_service.dart';
import 'home_screen.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Shown when a zero-knowledge account must be unlocked before notes can be
/// read (fresh device, or the 7-day re-lock window has passed).
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  static const String kRouteName = '/unlock';

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _input = TextEditingController();
  final _api = ApiService();
  bool _useRecoveryCode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final value = _input.text.trim();
    if (value.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    bool ok;
    try {
      ok = _useRecoveryCode
          ? await ZeroKnowledgeService.unlockWithRecoveryCode(_api, value)
          : await ZeroKnowledgeService.unlockWithPassphrase(_api, value);
    } catch (e) {
      ok = false;
    }

    if (!mounted) return;
    if (ok) {
      context.go(HomeScreen.kRouteName);
    } else {
      setState(() {
        _busy = false;
        _error = _useRecoveryCode
            ? AppL10n.of(context).unlockBadRecoveryCode
            : AppL10n.of(context).unlockBadPassphrase;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    _useRecoveryCode ? AppL10n.of(context).unlockEnterRecoveryCode : AppL10n.of(context).unlockTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _useRecoveryCode
                        ? AppL10n.of(context).unlockRecoveryHelp
                        : AppL10n.of(context).unlockPassphraseHelp,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _input,
                    autofocus: true,
                    obscureText: !_useRecoveryCode,
                    enabled: !_busy,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _busy ? null : _unlock(),
                    decoration: InputDecoration(
                      labelText:
                          _useRecoveryCode ? AppL10n.of(context).unlockRecoveryCodeLabel : AppL10n.of(context).unlockPassphraseLabel,
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _unlock,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_useRecoveryCode ? AppL10n.of(context).unlockRecover : AppL10n.of(context).unlockAction),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _useRecoveryCode = !_useRecoveryCode;
                              _error = null;
                              _input.clear();
                            }),
                    child: Text(_useRecoveryCode
                        ? AppL10n.of(context).unlockUsePassphrase
                        : AppL10n.of(context).unlockForgot),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
