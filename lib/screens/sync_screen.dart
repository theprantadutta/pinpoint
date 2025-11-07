import 'package:flutter/material.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';
import 'package:pinpoint/util/show_a_toast.dart';
import '../design_system/design_system.dart';

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

    try {
      final result = await _syncManager.sync();

      if (mounted) {
        if (result.success) {
          PinpointHaptics.success();
          showSuccessToast(
            context: context,
            title: 'Sync Complete',
            description: result.message,
          );
        } else {
          PinpointHaptics.error();
          showErrorToast(
            context: context,
            title: 'Sync Failed',
            description: result.message,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: 'Sync Error',
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
            title: 'Upload Complete',
            description: result.message,
          );
        } else {
          PinpointHaptics.error();
          showErrorToast(
            context: context,
            title: 'Upload Failed',
            description: result.message,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: 'Upload Error',
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
            title: 'Download Complete',
            description: result.message,
          );
        } else {
          PinpointHaptics.error();
          showErrorToast(
            context: context,
            title: 'Download Failed',
            description: result.message,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        PinpointHaptics.error();
        showErrorToast(
          context: context,
          title: 'Download Error',
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
            const Text('Sync'),
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
              'Cloud Sync',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync your notes across devices',
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
                    'Sync Status',
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
                                  ? 'Synced'
                                  : _syncManager.status == SyncStatus.error
                                      ? 'Error'
                                      : _syncManager.status ==
                                              SyncStatus.syncing
                                          ? 'Syncing...'
                                          : 'Not synced',
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
                                'Last sync: ${_syncManager.lastSyncDateTime!.toLocal()}',
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
              'Sync Actions',
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
                label: const Text('Sync Now'),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _triggerUpload,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Upload'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _triggerDownload,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Sync info
            Text(
              'How Sync Works',
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
