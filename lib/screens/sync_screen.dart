import 'package:flutter/material.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:pinpoint/services/analytics/analytics_facade.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import 'package:pinpoint/widgets/premium_gate_dialog.dart';
import '../design_system/design_system.dart';
import 'package:pinpoint/generated/l10n/app_localizations.dart';
import 'package:pinpoint/util/localized_dates.dart';

class SyncScreen extends StatefulWidget {
  static const String kRouteName = '/sync';

  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late SyncManager _syncManager;
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.sync_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Text(AppL10n.of(context).syncTitle),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              AppL10n.of(context).syncCloudSync,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppL10n.of(context).syncAcrossDevices,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 24),

            // Sync status card
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppL10n.of(context).syncStatus,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        _syncManager.status == SyncStatus.synced
                            ? Icons.check_circle_rounded
                            : _syncManager.status == SyncStatus.error
                                ? Icons.error_rounded
                                : Icons.info_rounded,
                        color: _syncManager.status == SyncStatus.synced
                            ? Colors.green
                            : _syncManager.status == SyncStatus.error
                                ? cs.error
                                : cs.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _syncManager.status == SyncStatus.synced
                                  ? AppL10n.of(context).syncStatusSynced
                                  : _syncManager.status == SyncStatus.error
                                      ? AppL10n.of(context).syncStatusError
                                      : _syncManager.status ==
                                              SyncStatus.syncing
                                          ? AppL10n.of(context).syncStatusSyncing
                                          : AppL10n.of(context).syncStatusNotSynced,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _syncManager.lastSyncMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withAlpha(180),
                              ),
                            ),
                            if (_syncManager.lastSyncDateTime != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                AppL10n.of(context).syncLastSync(LocalizedDates.dateTime(context, _syncManager.lastSyncDateTime!.toLocal())),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurface.withAlpha(150),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sync actions
            Text(
              AppL10n.of(context).syncActions,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSyncing ? null : _triggerSync,
                icon: _isSyncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(AppL10n.of(context).setSyncNow),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _triggerUpload,
                    icon: const Icon(Icons.upload_rounded),
                    label: Text(AppL10n.of(context).syncUpload),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _triggerDownload,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(AppL10n.of(context).syncDownload),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Sync info
            Text(
              AppL10n.of(context).syncHowItWorks,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '• Sync automatically uploads your notes to the cloud\n'
              '• Download changes from other devices\n'
              '• Resolve conflicts automatically\n'
              '• Works offline - syncs when connection is restored',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: cs.onSurface.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
