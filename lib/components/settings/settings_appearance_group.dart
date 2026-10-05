import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../navigation/app_navigation.dart';
import '../../screens/theme_screen.dart';
import '../../service_locators/init_service_locators.dart';
import '../../services/analytics/analytics_facade.dart';
import '../../services/premium_service.dart';
import '../../services/theme_controller.dart';
import '../../widgets/premium_gate_dialog.dart';

/// Accent swatches in the order Settings shows them — the pre-redesign order
/// of the old accent list, so people find their colour where it used to be.
const List<SketchAccent> kAccentDisplayOrder = [
  SketchAccent.mint,
  SketchAccent.iris,
  SketchAccent.rose,
  SketchAccent.amber,
  SketchAccent.ocean,
];

/// Localized name of an accent. The English `premiumName` stays the stable
/// identifier for PremiumService and analytics; only the label is translated.
String accentDisplayName(BuildContext context, SketchAccent accent) {
  final l10n = AppL10n.of(context);
  return switch (accent) {
    SketchAccent.mint => l10n.themeAccentNeonMint,
    SketchAccent.iris => l10n.themeAccentPurpleDream,
    SketchAccent.rose => l10n.themeAccentPinkBliss,
    SketchAccent.amber => l10n.themeAccentOrangeSunset,
    SketchAccent.ocean => l10n.themeAccentBlueOcean,
  };
}

/// Applies an accent pick: the premium gate for locked colours, otherwise the
/// controller plus the existing `accent_color_changed` event.
void selectAccent(BuildContext context, SketchAccent accent) {
  if (!PremiumService().isThemeColorAvailable(accent.premiumName)) {
    PinpointHaptics.error();
    PremiumGateDialog.showThemeLimit(context);
    return;
  }
  PinpointHaptics.medium();
  context.read<ThemeController>().setAccent(accent);
  getIt<AnalyticsFacade>().trackAccentColorChanged(colorName: accent.premiumName);
}

/// The five accent dots: the selected one ringed in ink, Pro-only ones at
/// 35% with a yellow "PRO" tag after the row.
class AccentDots extends StatelessWidget {
  const AccentDots({
    super.key,
    required this.selected,
    required this.isAvailable,
    required this.onSelect,
    this.accents = kAccentDisplayOrder,
  });

  final SketchAccent selected;
  final bool Function(SketchAccent) isAvailable;
  final ValueChanged<SketchAccent> onSelect;
  final List<SketchAccent> accents;

  @override
  Widget build(BuildContext context) {
    final s = context.sketch;
    final l10n = AppL10n.of(context);
    final dur = SketchMotion.of(context, SketchMotion.base);
    final anyLocked = accents.any((a) => !isAvailable(a));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in accents)
          SketchPressable(
            onTap: () => onSelect(a),
            selected: a == selected,
            semanticLabel: isAvailable(a)
                ? l10n.stAccentSemantic(accentDisplayName(context, a))
                : l10n.stAccentLockedSemantic(accentDisplayName(context, a)),
            // 34 wide keeps the 30px pitch of the mock readable on a 360dp
            // phone; the height still meets the 44 target.
            child: SizedBox(
              width: 34,
              height: SketchSpace.minTap,
              child: Center(
                child: AnimatedContainer(
                  duration: dur,
                  curve: SketchMotion.enter,
                  width: 29,
                  height: 29,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: a == selected ? s.ink : Colors.transparent,
                      width: SketchStroke.outline,
                    ),
                  ),
                  child: Opacity(
                    opacity: isAvailable(a) ? 1 : 0.35,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: a.legacyColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (anyLocked) ...[
          const SizedBox(width: 4),
          const ProTag(),
        ],
      ],
    );
  }
}

/// The tiny yellow "PRO" tag.
class ProTag extends StatelessWidget {
  const ProTag({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: SketchPastels.yellow,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SketchPastels.onPastel, width: 1),
        ),
        child: Text(
          AppL10n.of(context).stProTag,
          style: context.type.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: SketchPastels.onPastel,
          ),
        ),
      ),
    );
  }
}

/// Light / Dark / Auto, persisted through [ThemeController] with the existing
/// `theme_changed` event.
class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key, required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SketchSegmentedControl<ThemeMode>(
      semanticLabel: l10n.setTheme,
      selected: mode,
      onChanged: onChanged,
      segments: [
        SketchSegment(value: ThemeMode.light, label: l10n.themeLight),
        SketchSegment(value: ThemeMode.dark, label: l10n.themeDark),
        SketchSegment(value: ThemeMode.system, label: l10n.stThemeAuto),
      ],
    );
  }
}

void setThemeMode(BuildContext context, ThemeMode mode) {
  PinpointHaptics.medium();
  context.read<ThemeController>().setMode(mode);
  getIt<AnalyticsFacade>()
      .trackThemeChanged(theme: ThemeController.modeAnalyticsLabel(mode));
}

/// APPEARANCE: theme mode, accent dots and the font row.
class SettingsAppearanceGroup extends StatelessWidget {
  const SettingsAppearanceGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = context.watch<ThemeController>();
    final premium = PremiumService();

    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) => SketchGroup(
        children: [
          SketchRow(
            label: l10n.setTheme,
            trailing: ThemeModeSwitch(
              mode: theme.mode,
              onChanged: (m) => setThemeMode(context, m),
            ),
          ),
          SketchRow(
            label: l10n.stAccent,
            trailing: AccentDots(
              selected: theme.accent,
              isAvailable: (a) => premium.isThemeColorAvailable(a.premiumName),
              onSelect: (a) => selectAccent(context, a),
            ),
          ),
          SketchRow(
            label: l10n.stFont,
            value: theme.fontFamily,
            onTap: () {
              PinpointHaptics.medium();
              AppNavigation.router.push(ThemeScreen.kRouteName);
            },
          ),
        ],
      ),
    );
  }
}
