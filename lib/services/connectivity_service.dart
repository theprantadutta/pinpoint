import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity status enum
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// Service to monitor network connectivity state
class ConnectivityService with ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ConnectivityStatus _status = ConnectivityStatus.unknown;
  bool _initialized = false;

  /// Current connectivity status
  ConnectivityStatus get status => _status;

  /// Whether the device is currently online
  bool get isOnline => _status == ConnectivityStatus.online;

  /// Whether the device is currently offline
  bool get isOffline => _status == ConnectivityStatus.offline;

  /// Whether the service has been initialized
  bool get isInitialized => _initialized;

  /// Stream of connectivity status changes
  Stream<ConnectivityStatus> get onStatusChange => _statusController.stream;
  final _statusController = StreamController<ConnectivityStatus>.broadcast();

  /// Initialize the connectivity service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get initial connectivity status
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);

      // Listen for connectivity changes
      _connectivitySubscription?.cancel();
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateStatus,
        onError: (error) {
          debugPrint('❌ [Connectivity] Error monitoring connectivity: $error');
        },
      );

      _initialized = true;
      debugPrint('✅ [Connectivity] Service initialized. Status: $_status');
    } catch (e) {
      debugPrint('❌ [Connectivity] Failed to initialize: $e');
      _status = ConnectivityStatus.unknown;
    }
  }

  /// Update connectivity status based on results
  void _updateStatus(List<ConnectivityResult> results) {
    final previousStatus = _status;

    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _status = ConnectivityStatus.offline;
    } else {
      // Any connectivity (wifi, mobile, ethernet, etc.) means online
      _status = ConnectivityStatus.online;
    }

    if (previousStatus != _status) {
      debugPrint('🌐 [Connectivity] Status changed: $previousStatus -> $_status');
      _statusController.add(_status);
      notifyListeners();
    }
  }

  /// Check current connectivity (one-time check)
  Future<ConnectivityStatus> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return _status;
    } catch (e) {
      debugPrint('❌ [Connectivity] Error checking connectivity: $e');
      return ConnectivityStatus.unknown;
    }
  }

  /// Execute a callback when connectivity is restored
  /// Returns a subscription that can be cancelled
  StreamSubscription<ConnectivityStatus> onConnectivityRestored(
    VoidCallback callback,
  ) {
    return onStatusChange.listen((status) {
      if (status == ConnectivityStatus.online) {
        callback();
      }
    });
  }

  /// Wait for connectivity to be restored
  /// Returns true if online, or waits until online (with optional timeout)
  Future<bool> waitForConnectivity({Duration? timeout}) async {
    if (isOnline) return true;

    final completer = Completer<bool>();
    StreamSubscription<ConnectivityStatus>? subscription;

    subscription = onStatusChange.listen((status) {
      if (status == ConnectivityStatus.online) {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    if (timeout != null) {
      Future.delayed(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    return completer.future;
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _statusController.close();
    _initialized = false;
    debugPrint('🧹 [Connectivity] Service disposed');
  }
}
