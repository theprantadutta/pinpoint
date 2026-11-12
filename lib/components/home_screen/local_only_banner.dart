import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/design_system.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../screens/subscription_screen.dart';
import '../../sync/held_back_notes.dart';

/// "3 notes are only on this phone · Go Pro", while the free plan's sync
/// limit keeps notes from backing up. Dismissed, it returns only if more
/// notes stop backing up.
class LocalOnlyBanner extends StatelessWidget {
  const LocalOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: HeldBackNotes.notifier,
      builder: (context, heldBack, _) => ValueListenableBuilder<int>(
        valueListenable: HeldBackNotes.dismissedAt,
        builder: (context, dismissedAt, _) {
          final count = heldBack.length;
          if (count == 0 || count <= dismissedAt) return const SizedBox.shrink();
          final l10n = AppL10n.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(SketchSpace.screenX, 4, SketchSpace.screenX, 16),
            child: UpgradeBanner(
              title: l10n.localOnlyBannerTitle(count),
              message: l10n.localOnlyBannerBody,
              actionLabel: l10n.localOnlyGoPro,
              onAction: () => context.push(SubscriptionScreen.kRouteName),
              onDismiss: HeldBackNotes.dismissBanner,
              dismissLabel: l10n.localOnlyDismiss,
            ),
          );
        },
      ),
    );
  }
}
