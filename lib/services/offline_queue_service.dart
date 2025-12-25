import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';

/// Types of operations that can be queued
enum QueuedOperationType {
  createNote,
  updateNote,
  deleteNote,
  syncNote,
  createFolder,
  updateFolder,
  deleteFolder,
  custom,
}

/// A queued operation to be executed when online
class QueuedOperation {
  final String id;
  final QueuedOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  QueuedOperation copyWith({
    int? retryCount,
    String? errorMessage,
  }) {
    return QueuedOperation(
      id: id,
      type: type,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'errorMessage': errorMessage,
      };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'],
      type: QueuedOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QueuedOperationType.custom,
      ),
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      errorMessage: json['errorMessage'],
    );
  }

  @override
  String toString() =>
      'QueuedOperation(id: $id, type: ${type.name}, retries: $retryCount)';
}

/// Result of processing a queued operation
class OperationResult {
  final String operationId;
  final bool success;
  final String? errorMessage;

  OperationResult({
    required this.operationId,
    required this.success,
    this.errorMessage,
  });
}

/// Service to queue operations when offline and process them when online
class OfflineQueueService with ChangeNotifier {
  static const String _storageKey = 'offline_operation_queue';
  static const int _maxRetries = 3;

  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final List<QueuedOperation> _queue = [];
  final ConnectivityService _connectivity = ConnectivityService();
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  bool _isProcessing = false;
  bool _initialized = false;

  /// Handler functions for each operation type
  final Map<QueuedOperationType, Future<bool> Function(Map<String, dynamic>)>
      _handlers = {};

  /// Current queue
  List<QueuedOperation> get queue => List.unmodifiable(_queue);

  /// Number of pending operations
  int get pendingCount => _queue.length;

  /// Whether operations are currently being processed
  bool get isProcessing => _isProcessing;

  /// Stream of queue changes
  Stream<int> get onQueueChange => _queueController.stream;
  final _queueController = StreamController<int>.broadcast();

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;

    // Load persisted queue
    await _loadQueue();

    // Listen for connectivity changes
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onStatusChange.listen((status) {
      if (status == ConnectivityStatus.online && _queue.isNotEmpty) {
        debugPrint(
            '🌐 [OfflineQueue] Connectivity restored, processing ${_queue.length} queued operations');
        processQueue();
      }
    });

    _initialized = true;
    debugPrint(
        '✅ [OfflineQueue] Initialized with ${_queue.length} pending operations');
  }

  /// Register a handler for an operation type
  void registerHandler(
    QueuedOperationType type,
    Future<bool> Function(Map<String, dynamic>) handler,
  ) {
    _handlers[type] = handler;
    debugPrint('📝 [OfflineQueue] Registered handler for ${type.name}');
  }

  /// Add an operation to the queue
  Future<void> enqueue({
    required QueuedOperationType type,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    final operation = QueuedOperation(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );

    _queue.add(operation);
    await _saveQueue();
    _notifyQueueChange();

    debugPrint('📥 [OfflineQueue] Enqueued operation: $operation');

    // If online, try to process immediately
    if (_connectivity.isOnline) {
      processQueue();
    }
  }

  /// Remove an operation from the queue
  Future<void> remove(String operationId) async {
    _queue.removeWhere((op) => op.id == operationId);
    await _saveQueue();
    _notifyQueueChange();
    debugPrint('🗑️ [OfflineQueue] Removed operation: $operationId');
  }

  /// Clear all operations from the queue
  Future<void> clear() async {
    _queue.clear();
    await _saveQueue();
    _notifyQueueChange();
    debugPrint('🧹 [OfflineQueue] Cleared all operations');
  }

  /// Process all queued operations
  Future<List<OperationResult>> processQueue() async {
    if (_isProcessing) {
      debugPrint('⚠️ [OfflineQueue] Already processing, skipping');
      return [];
    }

    if (_queue.isEmpty) {
      debugPrint('ℹ️ [OfflineQueue] Queue is empty, nothing to process');
      return [];
    }

    if (!_connectivity.isOnline) {
      debugPrint('⚠️ [OfflineQueue] Offline, cannot process queue');
      return [];
    }

    _isProcessing = true;
    notifyListeners();

    final results = <OperationResult>[];
    final toRemove = <String>[];
    final toRetry = <QueuedOperation>[];

    debugPrint(
        '🔄 [OfflineQueue] Processing ${_queue.length} queued operations');

    for (final operation in List<QueuedOperation>.from(_queue)) {
      try {
        final handler = _handlers[operation.type];
        if (handler == null) {
          debugPrint(
              '⚠️ [OfflineQueue] No handler for ${operation.type.name}, skipping');
          continue;
        }

        debugPrint('▶️ [OfflineQueue] Processing: $operation');
        final success = await handler(operation.data);

        if (success) {
          debugPrint('✅ [OfflineQueue] Success: $operation');
          toRemove.add(operation.id);
          results.add(OperationResult(
            operationId: operation.id,
            success: true,
          ));
        } else {
          debugPrint('❌ [OfflineQueue] Failed: $operation');
          if (operation.retryCount < _maxRetries) {
            toRetry.add(operation.copyWith(retryCount: operation.retryCount + 1));
          } else {
            toRemove.add(operation.id);
            results.add(OperationResult(
              operationId: operation.id,
              success: false,
              errorMessage: 'Max retries exceeded',
            ));
          }
        }
      } catch (e) {
        debugPrint('❌ [OfflineQueue] Error processing $operation: $e');
        if (operation.retryCount < _maxRetries) {
          toRetry.add(operation.copyWith(
            retryCount: operation.retryCount + 1,
            errorMessage: e.toString(),
          ));
        } else {
          toRemove.add(operation.id);
          results.add(OperationResult(
            operationId: operation.id,
            success: false,
            errorMessage: e.toString(),
          ));
        }
      }
    }

    // Remove completed/failed operations
    _queue.removeWhere((op) => toRemove.contains(op.id));

    // Update retry counts
    for (final retry in toRetry) {
      final index = _queue.indexWhere((op) => op.id == retry.id);
      if (index >= 0) {
        _queue[index] = retry;
      }
    }

    await _saveQueue();
    _isProcessing = false;
    _notifyQueueChange();
    notifyListeners();

    debugPrint(
        '✅ [OfflineQueue] Processed ${results.length} operations. ${_queue.length} remaining.');

    return results;
  }

  /// Load queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString == null) return;

      final jsonList = json.decode(jsonString) as List<dynamic>;
      _queue.clear();
      _queue.addAll(
        jsonList.map((e) => QueuedOperation.fromJson(e as Map<String, dynamic>)),
      );
      debugPrint('📂 [OfflineQueue] Loaded ${_queue.length} operations');
    } catch (e) {
      debugPrint('❌ [OfflineQueue] Error loading queue: $e');
    }
  }

  /// Save queue to persistent storage
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _queue.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('❌ [OfflineQueue] Error saving queue: $e');
    }
  }

  void _notifyQueueChange() {
    _queueController.add(_queue.length);
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _queueController.close();
    _initialized = false;
    debugPrint('🧹 [OfflineQueue] Disposed');
  }
}
