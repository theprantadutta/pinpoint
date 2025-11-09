import 'dart:async';
import 'package:async_queue/async_queue.dart';
import 'package:flutter/foundation.dart';

import '../database/database.dart' as db;
import 'drift_note_service.dart';

/// Result of a save operation
class SaveResult {
  final bool success;
  final int noteId;
  final String? reason;

  SaveResult({
    required this.success,
    required this.noteId,
    this.reason,
  });

  @override
  String toString() => 'SaveResult(success: $success, noteId: $noteId, '
      'reason: $reason)';
}

/// Manages background saving of notes using a sequential queue
/// to prevent race conditions and improve UI responsiveness
class BackgroundSaveQueueService {
  // Singleton pattern
  static final BackgroundSaveQueueService _instance =
      BackgroundSaveQueueService._internal();

  factory BackgroundSaveQueueService() => _instance;

  BackgroundSaveQueueService._internal() {
    _initializeQueue();
  }

  late final AsyncQueue _saveQueue;

  // Track last enqueued save per note to avoid duplicate saves
  final Map<String, DateTime> _lastEnqueuedTime = {};

  // Minimum time between saves for same note (debouncing at queue level)
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  // Metrics
  int _totalEnqueued = 0;
  int _totalSucceeded = 0;
  int _totalFailed = 0;

  void _initializeQueue() {
    _saveQueue = AsyncQueue.autoStart();

    // Add queue listener for monitoring/debugging
    _saveQueue.addQueueListener((data) {
      debugPrint('[SaveQueue] Queue event: $data');
    });
  }

  /// Enqueue a note save operation
  /// Returns a Future that completes when the save is done
  Future<SaveResult> enqueueSave({
    required db.NotesCompanion noteCompanion,
    required int? previousNoteId,
    bool debounce = true,
  }) async {
    // Generate unique key for this note
    final noteKey = previousNoteId?.toString() ?? 'new_note';

    // Debounce check (optional, since screen already debounces)
    if (debounce) {
      final lastTime = _lastEnqueuedTime[noteKey];
      if (lastTime != null &&
          DateTime.now().difference(lastTime) < _debounceDuration) {
        debugPrint('[SaveQueue] Skipping duplicate save for note: $noteKey');
        return SaveResult(
            success: false, noteId: 0, reason: 'Debounced - too soon');
      }
    }

    _lastEnqueuedTime[noteKey] = DateTime.now();
    _totalEnqueued++;

    // Enqueue the save job
    debugPrint('[SaveQueue] Enqueueing save for note: $noteKey');

    final completer = Completer<SaveResult>();

    _saveQueue.addJob((job) async {
      try {
        debugPrint('[SaveQueue] Processing save for note: $noteKey');

        final noteId = await DriftNoteService.upsertANewTitleContentNote(
          noteCompanion,
          previousNoteId,
        );

        if (noteId == 0) {
          debugPrint('[SaveQueue] Save failed for note: $noteKey');
          _totalFailed++;
          completer.complete(SaveResult(
              success: false,
              noteId: 0,
              reason: 'Database save returned 0'));
        } else {
          debugPrint(
              '[SaveQueue] Successfully saved note: $noteKey (ID: $noteId)');
          _totalSucceeded++;
          completer.complete(SaveResult(success: true, noteId: noteId));
        }
      } catch (e, st) {
        debugPrint('[SaveQueue] Exception saving note: $noteKey - $e');
        debugPrint('[SaveQueue] Stack trace: $st');
        _totalFailed++;
        completer.complete(
            SaveResult(success: false, noteId: 0, reason: e.toString()));
      }
    }, retryTime: 3); // Retry up to 3 times on failure

    return completer.future;
  }

  /// Clear debounce history (useful for testing or reset)
  void clearDebounceHistory() {
    _lastEnqueuedTime.clear();
  }

  /// Get queue status for debugging
  Map<String, dynamic> getQueueStatus() {
    return {
      'pending_saves': _lastEnqueuedTime.length,
      'last_enqueued_times': _lastEnqueuedTime,
    };
  }

  /// Get queue metrics
  Map<String, dynamic> getMetrics() {
    return {
      'total_enqueued': _totalEnqueued,
      'total_succeeded': _totalSucceeded,
      'total_failed': _totalFailed,
      'success_rate': _totalEnqueued > 0
          ? '${(_totalSucceeded / _totalEnqueued * 100).toStringAsFixed(2)}%'
          : 'N/A',
    };
  }

  /// Clean up old entries from debounce map
  void cleanup() {
    final now = DateTime.now();
    _lastEnqueuedTime.removeWhere(
        (key, time) => now.difference(time) > const Duration(minutes: 5));
  }
}
