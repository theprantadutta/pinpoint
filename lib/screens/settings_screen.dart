import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/settings/settings_account_actions.dart';
import '../components/settings/settings_account_card.dart';
import '../components/settings/settings_appearance_group.dart';
import '../components/settings/settings_more_groups.dart';
import '../components/settings/settings_privacy_group.dart';
import '../components/settings/settings_usage_section.dart';
import '../design_system/design_system.dart';
import '../generated/l10n/app_localizations.dart';
import '../navigation/app_navigation.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/backend_auth_service.dart';

/// Settings, in the Sketchbook grouped-card style.
///
/// The screen is only the layout; each group lives in
/// `lib/components/settings/` and owns its own state and actions.
class SettingsScreen extends StatefulWidget {
  static const String kRouteName = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Settings');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final backendAuth = context.watch<BackendAuthService>();
    final signedIn = backendAuth.isAuthenticated;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SketchScaffold(
      title: l10n.setTitle,
      doodleTop: DoodleBackground.settingsTop,
      body: ListView(
        padding: EdgeInsets.only(top: 18, bottom: 40 + bottom),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
            child: signedIn
                ? const SettingsAccountSection()
                : SettingsSignInCard(
                    onSignIn: () {
                      PinpointHaptics.medium();
                      AppNavigation.router.push('/auth');
                    },
                  ),
          ),
          SketchOverline(l10n.setSectionAppearance),
          const SettingsAppearanceGroup(),
          SketchOverline(l10n.stSectionPrivacy),
          const SettingsPrivacyGroup(),
          const SettingsUsageSection(),
          SketchOverline(l10n.stSectionGeneral),
          const SettingsGeneralGroup(),
          SketchOverline(l10n.stSectionNotes),
          const SettingsNotesGroup(),
          SketchOverline(l10n.stSectionHelp),
          const SettingsHelpGroup(),
          if (SettingsDeveloperGroup.visible(context)) ...[
            SketchOverline(l10n.stSectionDeveloper),
            const SettingsDeveloperGroup(),
          ],
          if (signedIn) SettingsAccountActions(backendAuth: backendAuth),
        ],
      ),
    );
  }
}
