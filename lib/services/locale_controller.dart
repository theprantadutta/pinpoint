import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/shared_preference_keys.dart';

/// Central, reactive owner of the app's language selection.
///
/// Deliberately mirrors [ThemeController]: a [ChangeNotifier] provided at the
/// top of the tree that `MaterialApp.router` watches, so changing the language
/// re-renders the app instantly with no restart.
///
/// A null [locale] means "follow the system locale", which is the default and
/// is what Flutter does when `MaterialApp.locale` is null. A non-null value
/// pins the app to one language regardless of the device setting.
class LocaleController extends ChangeNotifier {
  Locale? _locale;
  bool _loaded = false;

  /// The user's explicit choice, or null to follow the device language.
  Locale? get locale => _locale;
  bool get isLoaded => _loaded;

  /// Every locale the app ships translations for.
  ///
  /// Order matters: the first entry is the fallback Flutter resolves to when
  /// the device language matches nothing here, so English must stay first.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    // Plain 'pt' rather than 'pt_BR': Brazil is the only Portuguese-speaking
    // market we target, and a country-coded .arb would force gen-l10n to also
    // demand a base app_pt.arb. The copy itself is Brazilian Portuguese.
    Locale('pt'),
    Locale('it'),
    Locale('fr'),
    Locale('th'),
    Locale('bn'),
    Locale('ar'),
    Locale('fa'),
  ];

  /// Endonyms — each language's name *in that language*, which is what a
  /// language picker should show. A user looking for Thai is scanning for
  /// "ไทย", not for the English word "Thai".
  static const Map<String, String> localeNames = <String, String>{
    'en': 'English',
    'es': 'Español',
    'pt': 'Português (Brasil)',
    'it': 'Italiano',
    'fr': 'Français',
    'th': 'ไทย',
    'bn': 'বাংলা',
    'ar': 'العربية',
    'fa': 'فارسی',
  };

  /// The locales written right-to-left. Flutter derives text direction from
  /// the locale itself, so this is only for our own layout decisions.
  static const Set<String> rtlLanguageCodes = <String>{'ar', 'fa'};

  static bool isRtl(Locale locale) =>
      rtlLanguageCodes.contains(locale.languageCode);

  /// Stable key for a locale, used both for persistence and as the
  /// [localeNames] lookup. Matches the `pt_BR` style of the .arb filenames.
  static String keyFor(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  /// Display name for a locale, falling back to its raw key if we somehow
  /// gain a supported locale without adding an endonym for it.
  static String displayName(Locale locale) =>
      localeNames[keyFor(locale)] ?? keyFor(locale);

  /// The language the app is actually showing right now, as a tag like `es`.
  ///
  /// Exists for code with no [BuildContext] — services and background handlers
  /// that need to tell the server which language to render emails and push
  /// bodies in. Widgets should read `Localizations.localeOf(context)` instead;
  /// this is a snapshot, not something that rebuilds.
  ///
  /// Resolves an unpinned locale against the device language, falling back to
  /// English when the device speaks something we don't ship.
  static String get currentTag {
    final pinned = _current;
    if (pinned != null) return keyFor(pinned);

    final device = PlatformDispatcher.instance.locale;
    final match = supportedLocales.any((l) => l.languageCode == device.languageCode);
    return match ? device.languageCode : 'en';
  }

  /// Backing value for [currentTag]. Static because the resolver has no
  /// instance to consult; kept in step by [load] and [setLocale].
  static Locale? _current;

  /// Load the persisted language. Call once at startup, before the first
  /// frame, so the app never flashes English and then switch.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kLocaleKey);
    if (stored != null && stored.isNotEmpty) {
      _locale = _parse(stored);
    }
    _current = _locale;
    _loaded = true;
    notifyListeners();
  }

  /// Pin the app to [locale], or pass null to go back to following the device.
  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    _current = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(kLocaleKey);
    } else {
      await prefs.setString(kLocaleKey, keyFor(locale));
    }
  }

  /// Parse a persisted key back into a Locale, tolerating both `pt_BR` and
  /// `pt-BR` since the two spellings are easy to mix up.
  static Locale? _parse(String value) {
    final parts = value.split(RegExp(r'[_-]'));
    final candidate =
        parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    // Never restore a locale we no longer ship — a downgrade or a dropped
    // language would otherwise leave the app pinned to something unresolvable.
    final isSupported = supportedLocales.any(
      (l) =>
          l.languageCode == candidate.languageCode &&
          l.countryCode == candidate.countryCode,
    );
    return isSupported ? candidate : null;
  }
}
