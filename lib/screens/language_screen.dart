import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/settings/settings_widgets.dart';
import '../design_system/design_system.dart';
import '../generated/l10n/app_localizations.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/firebase_notification_service.dart';
import '../services/locale_controller.dart';

/// Language picker.
///
/// Each row shows the language's endonym — its name in its own language and
/// script — because someone looking for Thai scans for "ไทย", not for the
/// English word "Thai". Under it is the language's name in the current app
/// language, so the list still reads for someone who landed in the wrong
/// one. That means this one screen renders every script the app supports at
/// once, which makes it the fastest way to eyeball whether the bundled font
/// fallbacks are actually working.
class LanguageScreen extends StatelessWidget {
  static const String kRouteName = '/language';

  const LanguageScreen({super.key});

  /// The language's name in the current UI language ("Spanish", "Espagnol").
  static String localizedName(AppL10n l10n, Locale locale) =>
      switch (locale.languageCode) {
        'en' => l10n.stLangEnglish,
        'es' => l10n.stLangSpanish,
        'pt' => l10n.stLangPortuguese,
        'it' => l10n.stLangItalian,
        'fr' => l10n.stLangFrench,
        'th' => l10n.stLangThai,
        'bn' => l10n.stLangBengali,
        'ar' => l10n.stLangArabic,
        'fa' => l10n.stLangPersian,
        _ => LocaleController.displayName(locale),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final controller = context.watch<LocaleController>();
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SketchScaffold(
      title: l10n.settingsLanguageTitle,
      doodleTop: DoodleBackground.settingsTop,
      body: ListView(
        padding: EdgeInsets.only(top: 18, bottom: 40 + bottom),
        children: [
          SketchGroup(
            children: [
              SketchChoiceRow(
                label: l10n.languageSystemDefault,
                subtitle: l10n.languageSystemDefaultSubtitle,
                selected: controller.locale == null,
                leading: Icon(Icons.phone_android_rounded,
                    size: 20, color: context.sketch.ink),
                onTap: () => _select(context, null),
              ),
            ],
          ),
          SketchOverline(l10n.settingsLanguageSubtitle),
          SketchGroup(
            children: [
              for (final locale in LocaleController.supportedLocales)
                SketchChoiceRow(
                  label: LocaleController.displayName(locale),
                  // The endonym must be laid out in its own script's
                  // direction, otherwise Arabic and Persian names render
                  // backwards inside an otherwise left-to-right list.
                  labelDirection: LocaleController.isRtl(locale)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  subtitle: localizedName(l10n, locale),
                  selected: controller.locale == locale,
                  onTap: () => _select(context, locale),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _select(BuildContext context, Locale? locale) async {
    PinpointHaptics.medium();
    await context.read<LocaleController>().setLocale(locale);
    getIt<AnalyticsFacade>().trackScreenView(
      screenName:
          'Language/${locale == null ? 'system' : LocaleController.keyFor(locale)}',
    );

    // Re-report to the backend so push notifications switch too. Token
    // registration is normally once per session, so without forcing it the
    // server would keep the old language until the next sign-in — the user
    // would see a translated app still sending them English notifications.
    // Fire-and-forget: it already swallows its own errors and retries on login.
    unawaited(
      FirebaseNotificationService().registerTokenWithBackend(force: true),
    );
  }
}
