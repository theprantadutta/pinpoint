import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pinpoint/sync/sync_service.dart';

/// File-based sync service for local testing
class FileSyncService extends SyncService {
  static const String syncFilename = 'pinpoint_sync_data.json';
  File? _syncFile;
  final List<VoidCallback> _listeners = [];

  @override
  Future<void> init() async {
    await super.init();
    final dir = await getApplicationDocumentsDirectory();
    _syncFile = File('${dir.path}/$syncFilename');

    // Create file if it doesn't exist
    if (!(await _syncFile!.exists())) {
      await _syncFile!.writeAsString(jsonEncode({
        'notes': [],
        'folders': [],
        'tags': [],
        'last_updated': DateTime.now().toIso8601String(),
      }));
    }
  }

  @override
  Future<bool> isConfigured() async {
    return _syncFile != null && await _syncFile!.exists();
  }

  @override
  Future<SyncResult> sync(
      {SyncDirection direction = SyncDirection.both}) async {
    return await super.sync(direction: direction);
  }

  @override
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void dispose() {
    _listeners.clear();
    super.dispose();
  }
}
