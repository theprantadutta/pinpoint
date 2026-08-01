import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

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
        iconData: Icons.note_add,
      );

  factory EmptyStateWidget.searchNoResults(BuildContext context, String query) =>
      EmptyStateWidget(
        message: AppL10n.of(context).emptyNoSearchResults(query),
        iconData: Icons.search_off,
      );

  factory EmptyStateWidget.archiveEmpty(BuildContext context) =>
      EmptyStateWidget(
        message: AppL10n.of(context).emptyNoArchived,
        iconData: Icons.archive_outlined,
      );

  factory EmptyStateWidget.trashEmpty(BuildContext context) =>
      EmptyStateWidget(
        message: AppL10n.of(context).trashEmpty,
        iconData: Icons.delete_outline,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon inside subtle glass-like ring
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  (dark ? Colors.white : Colors.black).withValues(alpha: 0.04),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.26 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              iconData,
              size: 40,
              color: cs.primary.withValues(alpha: dark ? 0.55 : 0.42),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.88),
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
