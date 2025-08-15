import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/service_locators/init_service_locators.dart';
import 'package:pinpoint/sync/sync_manager.dart';
import 'package:pinpoint/sync/sync_service.dart';

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
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      final result = await _syncManager.sync();
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
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
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      final result = await _syncManager.upload();
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: Colors.red,
          ),
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
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      final result = await _syncManager.download();
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cloud Sync',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sync your notes across devices',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            
            // Sync status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sync Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          _syncManager.status == SyncStatus.synced
                              ? Icons.check_circle
                              : _syncManager.status == SyncStatus.error
                                  ? Icons.error
                                  : Icons.info,
                          color: _syncManager.status == SyncStatus.synced
                              ? Colors.green
                              : _syncManager.status == SyncStatus.error
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _syncManager.status == SyncStatus.synced
                                    ? 'Synced'
                                    : _syncManager.status == SyncStatus.error
                                        ? 'Error'
                                        : _syncManager.status == SyncStatus.syncing
                                            ? 'Syncing...'
                                            : 'Not synced',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _syncManager.lastSyncMessage,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              if (_syncManager.lastSyncDateTime != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Last sync: ${_syncManager.lastSyncDateTime!.toLocal()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
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
            ),
            
            const SizedBox(height: 32),
            
            // Sync actions
            const Text(
              'Sync Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _triggerSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: const Text('Sync Now'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _triggerUpload,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Changes'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _triggerDownload,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Changes'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Sync info
            const Text(
              'How Sync Works',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Sync automatically uploads your notes to the cloud\n'
              '• Download changes from other devices\n'
              '• Resolve conflicts automatically\n'
              '• Works offline - syncs when connection is restored',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}