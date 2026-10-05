import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/design_system.dart';
import '../util/show_a_toast.dart';
import '../sync/sync_manager.dart';
import '../service_locators/init_service_locators.dart';
import '../services/encryption_service.dart';
import '../services/api_service.dart';
import '../database/database.dart';

/// Debug screen for viewing sync status and troubleshooting issues
class SyncDebugScreen extends StatefulWidget {
  static const String kRouteName = '/sync-debug';

  const SyncDebugScreen({super.key});

  @override
  State<SyncDebugScreen> createState() => _SyncDebugScreenState();
}

class _SyncDebugScreenState extends State<SyncDebugScreen> {
  Map<String, dynamic> _debugInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() => _isLoading = true);

    try {
      final syncManager = getIt<SyncManager>();
      final database = getIt<AppDatabase>();
      final apiService = ApiService();

      // Count local data
      final notes = await (database.select(database.notes)
            ..where((tbl) => tbl.isDeleted.equals(false)))
          .get();
      final unsyncedNotes = await (database.select(database.notes)
            ..where((tbl) => tbl.isSynced.equals(false)))
          .get();
      final folders = await database.select(database.noteFolders).get();
      final reminders = await database.select(database.reminderNotesV2).get();

      // Get sync status
      final syncStatus = syncManager.status.toString();
      final lastSyncTime = syncManager.lastSyncTimestamp;
      final lastSyncMessage = syncManager.lastSyncMessage.isEmpty
          ? 'N/A'
          : syncManager.lastSyncMessage;

      // Check encryption status
      final encryptionInitialized = SecureEncryptionService.isInitialized;

      // Check backend connectivity
      bool backendReachable = false;
      String? backendError;
      try {
        await apiService.getSubscriptionStatus();
        backendReachable = true;
      } catch (e) {
        backendError = e.toString();
      }

      setState(() {
        _debugInfo = {
          'Local Data': {
            'Total Notes': notes.length,
            'Unsynced Notes': unsyncedNotes.length,
            'Folders': folders.length,
            'Reminders': reminders.length,
          },
          'Sync Status': {
            'Status': syncStatus,
            'Last Sync': lastSyncTime > 0
                ? DateTime.fromMillisecondsSinceEpoch(lastSyncTime * 1000)
                    .toString()
                : 'Never',
            'Last Message': lastSyncMessage,
          },
          'Encryption': {
            'Initialized': encryptionInitialized ? 'Yes' : 'No',
          },
          'Backend': {
            'Reachable': backendReachable ? 'Yes' : 'No',
            'Error': backendError ?? 'None',
          },
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = {'Error': e.toString()};
        _isLoading = false;
      });
    }
  }

  void _copyDebugInfo() {
    final buffer = StringBuffer();
    buffer.writeln('=== Pinpoint Sync Debug Info ===');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln();

    _debugInfo.forEach((section, data) {
      buffer.writeln('## $section');
      if (data is Map) {
        data.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
      } else {
        buffer.writeln('  $data');
      }
      buffer.writeln();
    });

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (mounted) {
      showSketchToast(
        context: context,
        message: 'Debug info copied to clipboard',
        tone: ToastTone.success,
      );
    }
  }

  // Admin / debug tooling: deliberately left in English.
  @override
  Widget build(BuildContext context) {
    return SketchScaffold(
      title: 'Sync Debug Info',
      actions: [
        CircleIconButton(
          icon: Icons.refresh_rounded,
          onPressed: _loadDebugInfo,
          semanticLabel: 'Refresh',
        ),
        const SizedBox(width: 6),
        CircleIconButton(
          icon: Icons.copy_rounded,
          onPressed: _copyDebugInfo,
          semanticLabel: 'Copy to clipboard',
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _debugInfo.isEmpty
              ? const Center(child: Text('No debug info available'))
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                      SketchSpace.screenX,
                      18,
                      SketchSpace.screenX,
                      32 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    ..._debugInfo.entries.map(
                      (section) => _buildSection(section.key, section.value),
                    ),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
    );
  }

  Widget _buildSection(String title, dynamic data) {
    final t = context.type;
    final s = context.sketch;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SketchCard(
        radius: SketchRadius.group,
        padding: const EdgeInsets.all(SketchSpace.cardPadLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.sectionTitle),
            const SizedBox(height: 8),
            Container(height: SketchStroke.outline, color: s.hairline),
            const SizedBox(height: 8),
            if (data is Map)
              ...data.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text('${entry.key}:', style: t.chip),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: t.bodyRegular.copyWith(
                            fontSize: 14,
                            color: _getValueColor(entry.value) ?? s.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(data.toString(), style: t.bodyRegular),
          ],
        ),
      ),
    );
  }

  Color? _getValueColor(dynamic value) {
    final str = value.toString().toLowerCase();
    if (str == 'yes' || str == 'true' || str == 'none') {
      return SketchFunctional.success;
    } else if (str == 'no' || str == 'false') {
      return context.sketch.muted;
    } else if (str.contains('error') || str.contains('failed')) {
      return SketchFunctional.error;
    }
    return null;
  }

  Widget _buildActionButtons() {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Troubleshooting Actions', style: t.sectionTitle),
        const SizedBox(height: 14),
        PillButton(
          onPressed: () async {
            final syncManager = getIt<SyncManager>();
            final result = await syncManager.sync();

            if (mounted) {
              showSketchToast(
                context: context,
                message: result.message,
                tone: result.success ? ToastTone.success : ToastTone.error,
              );
              _loadDebugInfo(); // Refresh after sync
            }
          },
          icon: Icons.sync_rounded,
          label: 'Force Sync Now',
        ),
        const SizedBox(height: 10),
        PillButton.secondary(
          onPressed: () async {
            final apiService = ApiService();
            try {
              final success =
                  await SecureEncryptionService.syncKeyFromCloud(apiService);

              if (mounted) {
                showSketchToast(
                  context: context,
                  message: success
                      ? 'Encryption key synced successfully'
                      : 'Failed to sync encryption key',
                  tone: success ? ToastTone.success : ToastTone.warning,
                );
                _loadDebugInfo(); // Refresh after key sync
              }
            } catch (e) {
              if (mounted) {
                showSketchToast(
                  context: context,
                  message: 'Error: $e',
                  tone: ToastTone.error,
                );
              }
            }
          },
          icon: Icons.key_rounded,
          label: 'Re-sync Encryption Key',
        ),
        const SizedBox(height: 22),
        Text('Need Help?', style: t.body),
        const SizedBox(height: 8),
        Text(
          'If you\'re experiencing sync issues:\n'
          '1. Check that you have internet connection\n'
          '2. Try "Force Sync Now" button above\n'
          '3. If notes are missing, they may have failed to decrypt (wrong encryption key)\n'
          '4. Try "Re-sync Encryption Key" to fix decryption issues\n'
          '5. Copy debug info and contact support if issues persist',
          style: t.caption,
        ),
      ],
    );
  }
}
