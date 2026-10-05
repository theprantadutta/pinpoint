import 'package:flutter/material.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_system/design_system.dart';
import '../../services/update/app_release_policy.dart';
import '../../services/update/app_release_service.dart';
import '../../services/update/in_app_update_service.dart';
import '../../util/show_a_toast.dart';

/// Tell an iOS user there is a newer build on the App Store.
///
/// One sheet, two shapes, because the cases differ only in whether there is a
/// way out:
///
///   [UpdatePrompt.optional]  Later + Update. Dismissible by drag, scrim or
///                            back; Later snoozes for 24h.
///   [UpdatePrompt.required]  no Later, no dismiss, and a PopScope that
///                            refuses back. The build has been declared unfit
///                            to keep using, so the sheet stays until it is
///                            resolved — including after a trip to the App
///                            Store that did not end in an update.
///
/// Reachable only when an operator deliberately raised the floor above the
/// running build in the dashboard.
Future<void> showAppUpdatePrompt(
    BuildContext context, UpdatePrompt prompt) async {
  if (prompt == UpdatePrompt.none) return;

  final service = AppReleaseService();
  final storeUrl = service.storeUrl;
  // "Update" with no way to do it is worse than saying nothing.
  if (storeUrl == null) return;

  final blocking = prompt == UpdatePrompt.required;

  await showSketchSheet<void>(
    context: context,
    isDismissible: !blocking,
    enableDrag: !blocking,
    builder: (sheetContext) {
      final l10n = AppL10n.of(sheetContext);
      final s = sheetContext.sketch;
      final t = sheetContext.type;
      return PopScope(
        canPop: !blocking,
        child: SketchSheet(
          scrollable: false,
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StickerTile(
                color: blocking ? SketchPastels.pink : s.highlight,
                size: 64,
                angle: -6,
                shadowOffset: 3,
                icon: blocking
                    ? Icons.lock_outline_rounded
                    : Icons.system_update_rounded,
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  blocking
                      ? l10n.updateRequiredTitle
                      : l10n.updateAvailableTitle,
                  style: t.emptyTitle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                blocking
                    ? l10n.updateRequiredBody
                    : l10n.updateAvailableBody(service.latestVersion ?? ''),
                style: t.bodyRegular.copyWith(fontSize: 14, color: s.muted),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillButton(
                label: l10n.updateNow,
                icon: Icons.open_in_new_rounded,
                onPressed: () async {
                  final opened = await _openStore(storeUrl);
                  if (!sheetContext.mounted) return;
                  if (!opened) {
                    showErrorToast(
                      context: sheetContext,
                      title: l10n.updateRequiredTitle,
                      description: l10n.updateOpenStoreFailed,
                    );
                    return;
                  }
                  // Only the dismissible one closes. The blocking sheet stays
                  // behind the App Store, so coming back without updating
                  // does not drop the user into a build we said is unfit.
                  if (!blocking) Navigator.of(sheetContext).pop();
                },
              ),
              if (!blocking) ...[
                const SizedBox(height: 10),
                PillButton(
                  label: l10n.updateLater,
                  variant: PillButtonVariant.secondary,
                  onPressed: () {
                    // Record before closing so the snooze is written even if
                    // the next frame is the last.
                    service.recordDeclined();
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _openStore(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// A small inverse pill floating above the dock: a flexible Play update has
/// downloaded and only needs a restart. Renders nothing until then.
///
/// This is the whole "ask" for a routine Android update. Play already asked
/// once, quietly, to download; the restart is the user's call and waits for
/// them.
class UpdateReadyPill extends StatelessWidget {
  const UpdateReadyPill({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: InAppUpdateService().updateReadyToInstall,
      builder: (context, ready, _) {
        if (!ready) return const SizedBox.shrink();
        final l10n = AppL10n.of(context);
        final s = context.sketch;
        final t = context.type;
        return Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6),
            decoration: BoxDecoration(
              color: s.inverse,
              borderRadius: BorderRadius.circular(999),
              boxShadow: SketchShadows.dock,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_done_rounded, size: 18, color: s.onInverse),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.updateReadyTitle,
                    style: t.bodyRegular.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: s.onInverse),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: s.highlight,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => InAppUpdateService().completeUpdate(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Text(
                        l10n.updateReadyRestart,
                        style: t.bodyRegular.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: SketchPastels.onPastel),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
