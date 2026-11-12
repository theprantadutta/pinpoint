import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Runs before every test file.
///
/// google_fonts loads a bundled face the first time a style asks for it, and
/// the load finishes asynchronously. When it lands after a widget test has
/// already ended, the engine's "fontsChange" message schedules a relayout
/// frame on a disposed tree, and since Flutter 3.50 the test fails with "An
/// animation is still running even after the widget tree was disposed".
/// Loading the app's default faces once up front, before any widget exists,
/// means no load is ever in flight when a test finishes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final family in const ['Plus Jakarta Sans', 'Caveat', 'JetBrains Mono']) {
    for (final weight in FontWeight.values) {
      for (final style in FontStyle.values) {
        GoogleFonts.getFont(family, fontWeight: weight, fontStyle: style);
      }
    }
  }
  try {
    await GoogleFonts.pendingFonts();
  } catch (_) {
    // A face missing from the bundle fails only the test that uses it.
  }

  await testMain();
}
