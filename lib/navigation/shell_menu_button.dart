import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../design_system/design_system.dart';
import 'app_shell_scope.dart';

/// A menu button for a top-level tab's header, or null where one would be
/// redundant.
///
/// Between 840 and 1200 wide (a large tablet in portrait) the shell shows
/// neither the dock nor the pinned sidebar, so a tab other than Home — whose
/// logo already opens the drawer — had no visible way to reach the rest of
/// the app; only an edge swipe did.
Widget? shellMenuButton(BuildContext context) {
  final shell = AppShellScope.maybeOf(context);
  if (shell == null || shell.showsDock || shell.hasPermanentDrawer) {
    return null;
  }
  return CircleIconButton(
    icon: Icons.menu_rounded,
    semanticLabel: AppL10n.of(context).a11yOpenMenu,
    onPressed: shell.openDrawer,
  );
}
