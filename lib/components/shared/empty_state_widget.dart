import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

import '../../design_system/components/empty_state.dart';

/// Preset empty states. Delegates to the Sketchbook [EmptyState].
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData iconData;

  const EmptyStateWidget({
    super.key,
    required this.message,
    required this.iconData,
  });

  // Preset variants. Each takes a BuildContext because the copy is localized;
  // they can no longer be const for the same reason.
  factory EmptyStateWidget.defaultNoNotes(BuildContext context) =>
      EmptyStateWidget(
        message: AppL10n.of(context).emptyNoNotes,
        iconData: Icons.edit_rounded,
      );

  factory EmptyStateWidget.searchNoResults(
          BuildContext context, String query) =>
      EmptyStateWidget(
        message: AppL10n.of(context).emptyNoSearchResults(query),
        iconData: Icons.search_off_rounded,
      );

  factory EmptyStateWidget.archiveEmpty(BuildContext context) =>
      EmptyStateWidget(
        message: AppL10n.of(context).emptyNoArchived,
        iconData: Icons.inventory_2_outlined,
      );

  factory EmptyStateWidget.trashEmpty(BuildContext context) => EmptyStateWidget(
        message: AppL10n.of(context).trashEmpty,
        iconData: Icons.delete_outline_rounded,
      );

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: iconData, title: message);
}
