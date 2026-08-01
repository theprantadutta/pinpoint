import 'package:flutter/widgets.dart';

import '../generated/l10n/app_localizations.dart';
import '../sync/sync_service.dart';

/// Renders a [SyncProgress] as localized text.
///
/// The sync services run with no [BuildContext] — they are plain services and
/// background tasks — so they cannot localize their own status. Instead they
/// emit a machine-readable [SyncPhase] plus counters, and this maps that to
/// copy at the point it is actually displayed. That also means a progress
/// object captured before a language change still renders in the new language.
///
/// [SyncPhase.error] is the one case that falls through to the raw message,
/// because the underlying failure text comes from the network or crypto layer
/// and has no phase of its own.
String syncPhaseLabel(BuildContext context, SyncProgress progress) {
  final l10n = AppL10n.of(context);
  final hasCount = progress.totalItems > 0;
  final current = progress.currentItem;
  final total = progress.totalItems;

  switch (progress.phase) {
    case SyncPhase.idle:
      return l10n.syncPhaseIdle;
    case SyncPhase.preparingFolders:
      return l10n.syncPhasePreparingFolders;
    case SyncPhase.syncingFolders:
      return hasCount
          ? l10n.syncPhaseSyncingFoldersCount(current, total)
          : l10n.syncPhaseSyncingFolders;
    case SyncPhase.preparingNotes:
      return l10n.syncPhasePreparingNotes;
    case SyncPhase.uploadingNotes:
      return hasCount
          ? l10n.syncPhaseUploadingNotesCount(current, total)
          : l10n.syncPhaseUploadingNotes;
    case SyncPhase.downloadingNotes:
      return hasCount
          ? l10n.syncPhaseDownloadingNotesCount(current, total)
          : l10n.syncPhaseDownloadingNotes;
    case SyncPhase.processingNotes:
      return hasCount
          ? l10n.syncPhaseProcessingNotesCount(current, total)
          : l10n.syncPhaseProcessingNotes;
    case SyncPhase.syncingReminders:
      return hasCount
          ? l10n.syncPhaseSyncingRemindersCount(current, total)
          : l10n.syncPhaseSyncingReminders;
    case SyncPhase.finalizing:
      return l10n.syncPhaseFinalizing;
    case SyncPhase.completed:
      return l10n.syncPhaseCompleted;
    case SyncPhase.error:
      // Underlying error text; produced by the layer that failed.
      return progress.message;
  }
}
