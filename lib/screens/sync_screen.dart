import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/widgets/premium_gate_dialog.dart';
import '../components/settings/settings_format.dart';
import '../components/settings/settings_widgets.dart';
import '../design_system/design_system.dart';
import '../navigation/app_navigation.dart';
import '../services/pending_changes_service.dart';
import 'sync_debug_screen.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';

class SyncScreen extends StatefulWidget {
  static const String kRouteName = '/sync';

  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late SyncManager _syncManager;
  late final Stream<int> _pending = PendingChangesService.watchCount();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    getIt<AnalyticsFacade>().trackScreenView(screenName: 'Sync');
    _syncManager = getIt<SyncManager>();
    _syncManager.addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    _syncManager.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (mounted) {
      setState(() {
        _isSyncing = _syncManager.isSyncing;
      });
    }
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;

    PinpointHaptics.medium();
    setState(() {
      _isSyncing = true;
    });

    final analytics = getIt<AnalyticsFacade>();
    analytics.trackSyncStarted();

    try {
      final result = await _syncManager.sync();

      if (mounted) {
        if (result.success) {
          analytics.trackSyncCompleted();
          PinpointHaptics.success();
          showSuccessToast(
            context: context,
            title: AppL10n.of(context).setSyncComplete,
            description: result.message,
          );
        } else {
          analytics.trackSyncFailed(error: result.message);
          PinpointHaptics.error();

          // Check if error is due to premium limit
          if (result.message.toLowerCase().contains('limit reached') ||
              result.message.toLowerCase().contains('upgrade to premium')) {
            // Show premium gate dialog
            PremiumGateDialog.showSyncLimit(context, 0);
          } else {
            showErrorToast(
              context: context,
              title: AppL10n.of(context).setSyncFailed,
              description: result.message,
            );
          }
        }
      }
    } catch (e) {
      analytics.trackSyncFailed(error: e.toString());
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: AppL10n.of(context).syncErrorTitle,
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _triggerUpload() async {
    if (_isSyncing) return;

    PinpointHaptics.medium();
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncManager.upload();

      if (mounted) {
        if (result.success) {
          PinpointHaptics.success();
          showSuccessToast(
            context: context,
            title: AppL10n.of(context).syncUploadComplete,
            description: result.message,
          );
        } else {
          PinpointHaptics.error();
          showErrorToast(
            context: context,
            title: AppL10n.of(context).syncUploadFailed,
            description: result.message,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: AppL10n.of(context).syncUploadError,
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _triggerDownload() async {
    if (_isSyncing) return;

    PinpointHaptics.medium();
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncManager.download();

      if (mounted) {
        if (result.success) {
          PinpointHaptics.success();
          showSuccessToast(
            context: context,
            title: AppL10n.of(context).syncDownloadComplete,
            description: result.message,
          );
        } else {
          PinpointHaptics.error();
          showErrorToast(
            context: context,
            title: AppL10n.of(context).syncDownloadFailed,
            description: result.message,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: AppL10n.of(context).syncDownloadError,
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final t = context.type;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final status = _isSyncing ? SyncStatus.syncing : _syncManager.status;
    final last = _syncManager.lastSyncDateTime;
    final SyncStickerState sticker = switch (status) {
      SyncStatus.syncing => SyncStickerState.syncing,
      SyncStatus.error => SyncStickerState.error,
      SyncStatus.synced => SyncStickerState.synced,
      SyncStatus.idle =>
        last == null ? SyncStickerState.idle : SyncStickerState.synced,
    };
    final title = switch (status) {
      SyncStatus.synced => l10n.syncStatusSynced,
      SyncStatus.error => l10n.syncStatusError,
      SyncStatus.syncing => l10n.syncStatusSyncing,
      SyncStatus.idle =>
        last == null ? l10n.syncStatusNotSynced : l10n.syncStatusSynced,
    };

    const showDebug = kDebugMode;

    return SketchScaffold(
      title: l10n.syncTitle,
      doodleTop: DoodleBackground.settingsTop,
      body: ListView(
        padding: EdgeInsets.only(top: 18, bottom: 40 + bottom),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
            child: SketchCard(
              radius: SketchRadius.group,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  SyncStatusSticker(state: sticker),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(title,
                        textAlign: TextAlign.center, style: t.emptyTitle),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    last == null
                        ? l10n.stNotSyncedYet
                        : l10n.syncLastSync(relativeAgo(context, last.toLocal())),
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<int>(
                    stream: _pending,
                    builder: (context, snap) => Text(
                      l10n.stPendingChanges(snap.data ?? 0),
                      textAlign: TextAlign.center,
                      style: t.bodySmall,
                    ),
                  ),
                  if (status == SyncStatus.error &&
                      _syncManager.lastSyncMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SketchErrorPill(message: _syncManager.lastSyncMessage),
                  ],
                  const SizedBox(height: 20),
                  PillButton(
                    label: l10n.stSyncNow,
                    icon: Icons.sync_rounded,
                    loading: _isSyncing,
                    onPressed: _isSyncing ? null : _triggerSync,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: PillButton.secondary(
                          label: l10n.syncUpload,
                          icon: Icons.upload_rounded,
                          height: 48,
                          onPressed: _isSyncing ? null : _triggerUpload,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PillButton.secondary(
                          label: l10n.syncDownload,
                          icon: Icons.download_rounded,
                          height: 48,
                          onPressed: _isSyncing ? null : _triggerDownload,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SketchOverline(l10n.stSyncHowTitle),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: SketchSpace.screenX),
            child: SketchCard(
              radius: SketchRadius.group,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  SketchBulletLine(text: l10n.stSyncHowEncrypt),
                  SketchBulletLine(text: l10n.stSyncHowDevices),
                  SketchBulletLine(text: l10n.stSyncHowOffline),
                  SketchBulletLine(text: l10n.stSyncHowConflicts),
                ],
              ),
            ),
          ),
          if (showDebug) ...[
            SketchOverline(l10n.stSectionDeveloper),
            SketchGroup(
              children: [
                SketchRow(
                  icon: Icons.bug_report_outlined,
                  label: l10n.setSyncDebug,
                  subtitle: l10n.setSyncDebugSubtitle,
                  onTap: () {
                    PinpointHaptics.medium();
                    AppNavigation.router.push(SyncDebugScreen.kRouteName);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum SyncStickerState { synced, syncing, error, idle }

/// The big status sticker: mint check when synced, a yellow spinning sync
/// arrow while syncing (still under reduced motion), pink "!" on error, and a
/// lavender cloud before the first sync.
class SyncStatusSticker extends StatefulWidget {
  const SyncStatusSticker({super.key, required this.state, this.size = 96});

  final SyncStickerState state;
  final double size;

  @override
  State<SyncStatusSticker> createState() => _SyncStatusStickerState();
}

class _SyncStatusStickerState extends State<SyncStatusSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSpin();
  }

  @override
  void didUpdateWidget(SyncStatusSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSpin();
  }

  void _updateSpin() {
    final spin = widget.state == SyncStickerState.syncing &&
        SketchMotion.enabled(context);
    if (spin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!spin && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (widget.state) {
      SyncStickerState.synced => (SketchPastels.mint, Icons.check_rounded),
      SyncStickerState.syncing => (SketchPastels.yellow, Icons.sync_rounded),
      SyncStickerState.error =>
        (SketchPastels.pink, Icons.priority_high_rounded),
      SyncStickerState.idle => (SketchPastels.lavender, Icons.cloud_outlined),
    };

    final glyph = widget.state == SyncStickerState.syncing
        ? RotationTransition(
            turns: Tween<double>(begin: 0, end: -1).animate(_spin),
            child: Icon(icon,
                size: widget.size * 0.46, color: SketchPastels.onPastel),
          )
        : Icon(icon, size: widget.size * 0.46, color: SketchPastels.onPastel);

    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: StickerTile(
        color: color,
        size: widget.size,
        angle: -6,
        shadowOffset: 4,
        child: glyph,
      ),
    );
  }
}
