import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:pinpoint/design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/services/locale_controller.dart';

/// Registers the bundled fonts with the test engine, so goldens render real
/// glyphs instead of the Ahem test boxes.
Future<void> loadSketchFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/google_fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  // google_fonts registers families under "<Family>_<variant>" names; the
  // goldens only need the faces to exist under the plain family too.
  await load('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await load('Caveat', ['Caveat-SemiBold.ttf']);

  // Material icons ship with the SDK, not the app.
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  }
}

/// Wraps [child] in a themed, localized app.
Widget sketchApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextDirection? textDirection,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: PinpointTheme.light(),
    darkTheme: PinpointTheme.dark(),
    themeMode:
        brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: locale,
    supportedLocales: LocaleController.supportedLocales,
    localizationsDelegates: const [
      AppL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      ...material_ui.GlobalMaterialLocalizations.delegates,
    ],
    home: Builder(
      builder: (context) {
        Widget body = Scaffold(
          body: SafeArea(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        );
        if (textDirection != null) {
          body = Directionality(textDirection: textDirection, child: body);
        }
        return body;
      },
    ),
  );
}
