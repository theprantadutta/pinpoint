import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/design_system.dart';
import '../services/api_service.dart';
import '../services/zero_knowledge_service.dart';
import 'home_screen.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Unlocks with [value]; [recoveryCode] says which secret it is. Returns
/// whether the notes are now unlocked.
typedef UnlockAttempt = Future<bool> Function(String value, bool recoveryCode);

/// Shown when a zero-knowledge account must be unlocked before notes can be
/// read (fresh device, or the 7-day re-lock window has passed).
///
/// There is no biometric shortcut: unlocking needs the passphrase-derived
/// key, and nothing stores that behind biometrics.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, @visibleForTesting this.unlockAttempt});

  static const String kRouteName = '/unlock';

  /// Test seam replacing the [ZeroKnowledgeService] call. Production leaves
  /// it null.
  final UnlockAttempt? unlockAttempt;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen>
    with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _useRecoveryCode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<bool> _attempt(String value) {
    final override = widget.unlockAttempt;
    if (override != null) return override(value, _useRecoveryCode);
    // Resolved here rather than in a field: the API client reads its config
    // on first use, which only an unlock attempt should trigger.
    final api = ApiService();
    return _useRecoveryCode
        ? ZeroKnowledgeService.unlockWithRecoveryCode(api, value)
        : ZeroKnowledgeService.unlockWithPassphrase(api, value);
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
      ok = await _attempt(value);
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
      // Shake the field 6px, three times — not under reduced motion.
      if (SketchMotion.enabled(context)) _shake.forward(from: 0);
    }
  }

  void _toggleMode() {
    setState(() {
      _useRecoveryCode = !_useRecoveryCode;
      _error = null;
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final t = context.type;
    final l10n = AppL10n.of(context);

    final field = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(6 * math.sin(_shake.value * 3 * 2 * math.pi), 0),
        child: child,
      ),
      child: SketchTextField(
        // A fresh field per mode, so the obscured passphrase never carries
        // its state into the plain-text recovery code.
        key: ValueKey(_useRecoveryCode),
        controller: _input,
        autofocus: true,
        obscureText: !_useRecoveryCode,
        enabled: !_busy,
        hint: _useRecoveryCode
            ? l10n.unlockRecoveryCodeLabel
            : l10n.unlockPassphraseLabel,
        prefixIcon:
            _useRecoveryCode ? Icons.key_rounded : Icons.lock_outline_rounded,
        textInputAction: TextInputAction.go,
        invalid: _error != null,
        onSubmitted: (_) {
          if (!_busy) _unlock();
        },
      ),
    );

    return Scaffold(
      backgroundColor: s.bg,
      body: DoodleBackground(
        top: 40,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: SketchSpace.screenX + 4, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: ExcludeSemantics(
                        child: BrandSticker(size: 88, shadow: true),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      child: Text(
                        _useRecoveryCode
                            ? l10n.unlockEnterRecoveryCode
                            : l10n.unlockTitle,
                        textAlign: TextAlign.center,
                        style: t.sheetTitle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _useRecoveryCode
                          ? l10n.unlockRecoveryHelp
                          : l10n.unlockPassphraseHelp,
                      textAlign: TextAlign.center,
                      style: t.bodyRegular
                          .copyWith(fontSize: 14, height: 1.5, color: s.muted),
                    ),
                    const SizedBox(height: 28),
                    field,
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      SketchErrorPill(message: _error!),
                    ],
                    const SizedBox(height: 20),
                    PillButton(
                      label: _useRecoveryCode
                          ? l10n.unlockRecover
                          : l10n.unlockAction,
                      loading: _busy,
                      onPressed: _unlock,
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: SketchTextAction(
                        label: _useRecoveryCode
                            ? l10n.unlockUsePassphrase
                            : l10n.ulUseRecoveryCode,
                        style: t.chip.copyWith(fontSize: 14),
                        onTap: _busy ? null : _toggleMode,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
