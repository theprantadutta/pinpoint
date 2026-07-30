import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
/// English word "Thai". That means this one screen renders every script the
/// app supports at once, which makes it the fastest way to eyeball whether the
/// bundled font fallbacks are actually working.
class LanguageScreen extends StatelessWidget {
  static const String kRouteName = '/language';

  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final controller = context.watch<LocaleController>();

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.translate_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Text(l10n.settingsLanguageTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LanguageOption(
            label: l10n.languageSystemDefault,
            sublabel: l10n.languageSystemDefaultSubtitle,
            isSelected: controller.locale == null,
            onTap: () => _select(context, null),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.settingsLanguageSubtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          ...LocaleController.supportedLocales.map(
            (locale) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LanguageOption(
                label: LocaleController.displayName(locale),
                // The endonym must be laid out in its own script's direction,
                // otherwise Arabic and Persian names render backwards inside
                // an otherwise left-to-right list.
                labelDirection: LocaleController.isRtl(locale)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                isSelected: controller.locale == locale,
                onTap: () => _select(context, locale),
              ),
            ),
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

    // Re-report to the backend so emails and push notifications switch too.
    // Token registration is normally once per session, so without forcing it
    // the server would keep the old language until the next sign-in — the user
    // would see a translated app still sending them English notifications.
    // Fire-and-forget: it already swallows its own errors and retries on login.
    unawaited(
      FirebaseNotificationService().registerTokenWithBackend(force: true),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.sublabel,
    this.labelDirection,
  });

  final String label;
  final String? sublabel;
  final TextDirection? labelDirection;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget name = Text(
      label,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    if (labelDirection != null) {
      name = Directionality(textDirection: labelDirection!, child: name);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? cs.surface.withValues(alpha: 0.7)
            : cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.5)
              : cs.outline.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      if (sublabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sublabel!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
