import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinpoint/services/premium_service.dart';
import '../components/settings/settings_appearance_group.dart';
import '../components/settings/settings_widgets.dart';
import '../design_system/design_system.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/theme_controller.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Theme: mode, accent colour and the UI font, as grouped cards.
class ThemeScreen extends StatefulWidget {
  static const String kRouteName = '/theme';
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Theme');
  }

  void _selectFont(String family) {
    PinpointHaptics.medium();
    // ThemeController persists the choice (kSelectedFontKey) and re-themes.
    context.read<ThemeController>().setFontFamily(family);
    getIt<AnalyticsFacade>().trackFontChanged(fontFamily: family);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final s = context.sketch;
    final controller = context.watch<ThemeController>();
    final premium = PremiumService();
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget modeRow(ThemeMode mode, String label, IconData icon) =>
        SketchChoiceRow(
          label: label,
          selected: controller.mode == mode,
          leading: Icon(icon, size: 20, color: s.ink),
          onTap: () => setThemeMode(context, mode),
        );

    return SketchScaffold(
      title: l10n.themeTitle,
      doodleTop: DoodleBackground.settingsTop,
      body: ListenableBuilder(
        listenable: premium,
        builder: (context, _) => ListView(
          padding: EdgeInsets.only(top: 6, bottom: 40 + bottom),
          children: [
            SketchOverline(l10n.stModeOverline),
            SketchGroup(
              children: [
                modeRow(ThemeMode.light, l10n.themeLight,
                    Icons.light_mode_outlined),
                modeRow(
                    ThemeMode.dark, l10n.themeDark, Icons.dark_mode_outlined),
                modeRow(ThemeMode.system, l10n.themeSystemDefault,
                    Icons.brightness_auto_outlined),
              ],
            ),
            SketchOverline(l10n.stAccentOverline),
            SketchGroup(
              children: [
                for (final accent in kAccentDisplayOrder)
                  SketchChoiceRow(
                    label: accentDisplayName(context, accent),
                    selected: controller.accent == accent,
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accent.legacyColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    trailing:
                        premium.isThemeColorAvailable(accent.premiumName)
                            ? null
                            : const ProTag(),
                    onTap: () => selectAccent(context, accent),
                  ),
              ],
            ),
            SketchOverline(l10n.stFont),
            SketchGroup(
              children: [
                for (final family in PinpointTypography.selectableFonts)
                  SketchChoiceRow(
                    label: family,
                    labelStyle:
                        PinpointTypography.fontPreview(family, color: s.ink),
                    selected: controller.fontFamily == family,
                    onTap: () => _selectFont(family),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
