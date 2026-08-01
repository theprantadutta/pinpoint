import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

/// Bottom navigation destinations.
///
/// A function rather than a const list: the labels are localized, so they need
/// a [BuildContext] and cannot be resolved at compile time.
List<Widget> bottomDestinations(BuildContext context) => [
      NavigationDestination(
        selectedIcon: const Icon(Icons.home),
        icon: const Icon(Icons.home_outlined),
        label: AppL10n.of(context).navHome,
      ),
      NavigationDestination(
        icon: const Icon(Icons.folder_copy_outlined),
        label: AppL10n.of(context).navFolder,
      ),
      NavigationDestination(
        icon: const Icon(Icons.check_box_outlined),
        label: AppL10n.of(context).navTodo,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        label: AppL10n.of(context).navSettingsShort,
      ),
    ];
