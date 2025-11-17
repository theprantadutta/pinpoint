import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug info copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Debug Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugInfo,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyDebugInfo,
            tooltip: 'Copy to clipboard',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _debugInfo.isEmpty
              ? const Center(child: Text('No debug info available'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._debugInfo.entries.map(
                      (section) => _buildSection(section.key, section.value),
                    ),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
    );
  }

  Widget _buildSection(String title, dynamic data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
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
                        child: Text(
                          '${entry.key}:',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: TextStyle(
                            color: _getValueColor(entry.value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(data.toString()),
          ],
        ),
      ),
    );
  }

  Color? _getValueColor(dynamic value) {
    final str = value.toString().toLowerCase();
    if (str == 'yes' || str == 'true' || str == 'none') {
      return Colors.green;
    } else if (str == 'no' || str == 'false') {
      return Colors.orange;
    } else if (str.contains('error') || str.contains('failed')) {
      return Colors.red;
    }
    return null;
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Troubleshooting Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            final syncManager = getIt<SyncManager>();
            final result = await syncManager.sync();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message),
                  backgroundColor:
                      result.success ? Colors.green : Colors.red,
                ),
              );
              _loadDebugInfo(); // Refresh after sync
            }
          },
          icon: const Icon(Icons.sync),
          label: const Text('Force Sync Now'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final apiService = ApiService();
            try {
              final success =
                  await SecureEncryptionService.syncKeyFromCloud(apiService);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Encryption key synced successfully'
                        : 'Failed to sync encryption key'),
                    backgroundColor: success ? Colors.green : Colors.orange,
                  ),
                );
                _loadDebugInfo(); // Refresh after key sync
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.key),
          label: const Text('Re-sync Encryption Key'),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Need Help?',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'If you\'re experiencing sync issues:\n'
          '1. Check that you have internet connection\n'
          '2. Try "Force Sync Now" button above\n'
          '3. If notes are missing, they may have failed to decrypt (wrong encryption key)\n'
          '4. Try "Re-sync Encryption Key" to fix decryption issues\n'
          '5. Copy debug info and contact support if issues persist',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
