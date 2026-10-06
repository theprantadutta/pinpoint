import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/settings/secret_input_sheet.dart';
import '../components/settings/settings_widgets.dart';
import '../design_system/design_system.dart';
import '../services/api_service.dart';
import '../services/encryption_service.dart';
import '../services/zero_knowledge_service.dart';
import '../util/show_a_toast.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Lets the user choose between Standard (server-managed key) and
/// zero-knowledge (passphrase + recovery code). Opt-in; existing users stay
/// Standard until they choose otherwise.
///
/// The copy is deliberately plain about the trade-offs: Standard keeps a
/// usable key on our server, and in either mode reminder text is not
/// end-to-end encrypted, nor are voice recordings synced before June 2026.
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
    // The cached mode first, so the screen renders offline; then reconcile
    // with the server (which itself falls back to the cache when offline).
    try {
      final cached = await ZeroKnowledgeService.cachedMode();
      if (mounted) {
        setState(() {
          _mode = cached;
          _loading = false;
        });
      }
    } catch (_) {}
    final mode = await ZeroKnowledgeService.refreshModeFromServer(_api);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final isZk = _mode == ZeroKnowledgeService.modeZeroKnowledge;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SketchScaffold(
      title: l10n.encTitle,
      doodleTop: DoodleBackground.settingsTop,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(SketchSpace.screenX, 14,
                  SketchSpace.screenX, 40 + bottom),
              children: [
                Text(l10n.stEncIntro, style: t.bodySmall),
                const SizedBox(height: 18),
                EncryptionModeCard(
                  title: l10n.encStandard,
                  icon: Icons.cloud_done_outlined,
                  selected: !isZk,
                  points: [
                    l10n.stEncStdPoint1,
                    l10n.stEncStdPoint2,
                    l10n.stEncNotE2ee,
                  ],
                  onTap: isZk ? _confirmDisable : null,
                ),
                const SizedBox(height: 12),
                EncryptionModeCard(
                  title: l10n.stZeroKnowledge,
                  icon: Icons.lock_outline_rounded,
                  selected: isZk,
                  points: [
                    l10n.stEncZkPoint1,
                    l10n.stEncZkPoint2,
                    l10n.stEncNotE2ee,
                  ],
                  onTap: isZk ? null : _startEnableFlow,
                ),
                const SizedBox(height: 20),
                if (!isZk) ...[
                  Text(l10n.encWrapExplain, style: t.bodySmall),
                  const SizedBox(height: 16),
                  PillButton(
                    icon: Icons.lock_rounded,
                    label: l10n.stEncTurnOn,
                    onPressed: _startEnableFlow,
                  ),
                ] else ...[
                  Text(l10n.encOnDescription, style: t.bodySmall),
                  const SizedBox(height: 16),
                  PillButton.secondary(
                    icon: Icons.cloud_upload_outlined,
                    label: l10n.encSwitchBackButton,
                    onPressed: _confirmDisable,
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _startEnableFlow() async {
    final l10n = AppL10n.of(context);
    if (!SecureEncryptionService.isInitialized) {
      _toast(l10n.encStillInitializing);
      return;
    }
    final passphrase = await showSecretInputSheet(
      context: context,
      title: l10n.encSetPassphraseTitle,
      message: l10n.encLoseBothWarning,
      fieldLabels: [l10n.encPassphrase, l10n.encConfirmPassphrase],
      confirmLabel: l10n.encContinue,
      isDismissible: false,
      validate: (values) {
        if (values[0].length < 8) return l10n.encPassphraseTooShort;
        if (values[0] != values[1]) return l10n.encPassphraseMismatch;
        return null;
      },
    );
    if (passphrase == null || !mounted) return;

    final code = await _runBusy(() =>
        ZeroKnowledgeService.enableZeroKnowledge(_api, passphrase));
    if (code == null) return;

    await _showRecoveryCode(code);
    if (!mounted) return;
    setState(() => _mode = ZeroKnowledgeService.modeZeroKnowledge);
  }

  Future<void> _showRecoveryCode(String code) async {
    final l10n = AppL10n.of(context);
    await showSketchSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => SketchSheet(
        title: l10n.encSaveRecoveryTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.encRecoveryOnlyWay,
                style: ctx.type.bodyRegular
                    .copyWith(fontSize: 14, color: ctx.sketch.muted)),
            const SizedBox(height: 16),
            SketchCard(
              pastel: SketchPastels.yellow,
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  letterSpacing: 1,
                  color: SketchPastels.onPastel,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SketchChip(
                label: l10n.encCopy,
                leading: const Icon(Icons.copy_rounded),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  _toast(l10n.encRecoveryCopied);
                },
              ),
            ),
            const SizedBox(height: 18),
            PillButton(
              label: l10n.encSavedIt,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDisable() async {
    final l10n = AppL10n.of(context);
    final ok = await showSketchConfirm(
      context: context,
      title: l10n.encSwitchBackTitle,
      message: l10n.encSwitchBackBody,
      confirmLabel: l10n.encSwitchBack,
      cancelLabel: l10n.commonCancel,
      destructive: false,
    );
    if (!ok || !mounted) return;

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
      barrierColor: context.sketch.scrim,
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
    showSketchToast(context: context, message: message);
  }
}

/// One of the two large mode cards. Selected: lavender with an ink outline
/// and a "Current" tag; otherwise an outlined surface card that starts the
/// switch when tapped.
class EncryptionModeCard extends StatelessWidget {
  const EncryptionModeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.points,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final List<String> points;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final fg = selected ? SketchPastels.onPastel : s.ink;

    return SketchCard(
      pastel: selected ? SketchPastels.lavender : null,
      radius: SketchRadius.group,
      borderWidth: selected ? 2 : null,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      selected: selected,
      onTap: onTap,
      semanticLabel: [title, if (selected) l10n.stEncCurrent, ...points]
          .join('. '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: t.cardTitleLarge.copyWith(color: fg)),
                ),
                if (selected)
                  SketchTag(
                      label: l10n.stEncCurrent, pastel: SketchPastels.mint)
                else
                  SketchChevron(color: s.muted),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in points) SketchBulletLine(text: p, color: fg),
          ],
        ),
      ),
    );
  }
}
