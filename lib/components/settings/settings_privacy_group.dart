import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/design_system.dart';
import '../../main.dart';
import '../../navigation/app_navigation.dart';
import '../../screens/encryption_settings_screen.dart';
import '../../services/zero_knowledge_service.dart';
import 'settings_widgets.dart';

/// PRIVACY & SECURITY: biometric lock, zero-knowledge mode, encryption.
///
/// The zero-knowledge value is the locally cached mode (secure storage), so
/// the row renders offline; the Encryption screen reconciles with the server.
class SettingsPrivacyGroup extends StatefulWidget {
  const SettingsPrivacyGroup({super.key});

  @override
  State<SettingsPrivacyGroup> createState() => _SettingsPrivacyGroupState();
}

class _SettingsPrivacyGroupState extends State<SettingsPrivacyGroup> {
  bool? _zeroKnowledge;

  /// Mirrors the app-level flag so the toggle animates immediately; the app
  /// state does not necessarily rebuild this route when it changes.
  bool? _biometric;

  void _setBiometric(bool value) {
    PinpointHaptics.light();
    PinPointApp.of(context).changeBiometricEnabledEnabled(value);
    setState(() => _biometric = value);
  }

  @override
  void initState() {
    super.initState();
    _readMode();
  }

  Future<void> _readMode() async {
    bool zk;
    try {
      zk = await ZeroKnowledgeService.isZeroKnowledge();
    } catch (_) {
      zk = false;
    }
    if (mounted) setState(() => _zeroKnowledge = zk);
  }

  Future<void> _openEncryption() async {
    PinpointHaptics.light();
    await AppNavigation.router.push(EncryptionSettingsScreen.kRouteName);
    // The mode may have changed on that screen.
    await _readMode();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final biometric = _biometric ?? PinPointApp.of(context).isBiometricEnabled;

    return SketchGroup(
      children: [
        SketchRow(
          label: l10n.stBiometricLock,
          onTap: () => _setBiometric(!biometric),
          trailing: SketchToggle(
            value: biometric,
            semanticLabel: l10n.stBiometricLock,
            onChanged: _setBiometric,
          ),
        ),
        SketchRow(
          label: l10n.stZeroKnowledge,
          subtitle: l10n.stZeroKnowledgeSubtitle,
          trailing: _zeroKnowledge == null
              ? null
              : SettingsValue(_zeroKnowledge! ? l10n.stOn : l10n.stOff),
          chevron: true,
          onTap: _openEncryption,
        ),
        SketchRow(
          label: l10n.setEncryption,
          onTap: _openEncryption,
          trailing: SketchTag(
            label: l10n.stEncryptionPill,
            pastel: SketchPastels.mint,
            dense: false,
          ),
        ),
      ],
    );
  }
}
