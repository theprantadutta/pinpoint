import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/zero_knowledge_service.dart';
import 'home_screen.dart';

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
            ? 'That recovery code didn\'t work. Check for typos and try again.'
            : 'Incorrect passphrase. Try again, or use your recovery code.';
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
                    _useRecoveryCode ? 'Enter recovery code' : 'Unlock your notes',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _useRecoveryCode
                        ? 'Paste the recovery code you saved when enabling Maximum Privacy.'
                        : 'Your notes are end-to-end encrypted. Enter your encryption passphrase to unlock them on this device.',
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
                          _useRecoveryCode ? 'Recovery code' : 'Encryption passphrase',
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
                          : Text(_useRecoveryCode ? 'Recover' : 'Unlock'),
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
                        ? 'Use passphrase instead'
                        : 'Forgot passphrase? Use recovery code'),
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
