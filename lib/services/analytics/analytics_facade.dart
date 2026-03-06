import 'dart:async';
import 'analytics_client.dart';
import 'firebase_analytics_client.dart';
import 'logger_analytics_client.dart';

typedef _QueuedEvent = Future<void> Function(FirebaseAnalyticsClient client);

/// Multi-client analytics dispatcher.
/// Queues Firebase events until [onFirebaseReady] is called, then flushes.
/// Logger events fire immediately regardless.
class AnalyticsFacade implements AnalyticsClient {
  final LoggerAnalyticsClient? _logger;
  FirebaseAnalyticsClient? _firebaseClient;
  bool _firebaseReady = false;
  final List<_QueuedEvent> _eventQueue = [];

  AnalyticsFacade({LoggerAnalyticsClient? logger}) : _logger = logger;

  /// Call after Firebase.initializeApp() completes.
  void onFirebaseReady() {
    _firebaseClient = FirebaseAnalyticsClient();
    _firebaseReady = true;
    _flushQueue();
  }

  void _flushQueue() {
    if (!_firebaseReady || _firebaseClient == null) return;
    final queued = List<_QueuedEvent>.from(_eventQueue);
    _eventQueue.clear();
    for (final event in queued) {
      unawaited(event(_firebaseClient!));
    }
  }

  void _trackFirebase(_QueuedEvent event) {
    if (_firebaseReady && _firebaseClient != null) {
      unawaited(event(_firebaseClient!));
    } else {
      _eventQueue.add(event);
    }
  }

  // Auth
  @override
  Future<void> trackSignUp({required String method}) async {
    unawaited(_logger?.trackSignUp(method: method));
    _trackFirebase((c) => c.trackSignUp(method: method));
  }

  @override
  Future<void> trackLogin({required String method}) async {
    unawaited(_logger?.trackLogin(method: method));
    _trackFirebase((c) => c.trackLogin(method: method));
  }

  @override
  Future<void> trackLogout() async {
    unawaited(_logger?.trackLogout());
    _trackFirebase((c) => c.trackLogout());
  }

  @override
  Future<void> trackAccountLink({required String method}) async {
    unawaited(_logger?.trackAccountLink(method: method));
    _trackFirebase((c) => c.trackAccountLink(method: method));
  }

  @override
  Future<void> setUserId(String? userId) async {
    unawaited(_logger?.setUserId(userId));
    _trackFirebase((c) => c.setUserId(userId));
  }

  // Onboarding
  @override
  Future<void> trackOnboardingComplete() async {
    unawaited(_logger?.trackOnboardingComplete());
    _trackFirebase((c) => c.trackOnboardingComplete());
  }

  @override
  Future<void> trackTermsAccepted() async {
    unawaited(_logger?.trackTermsAccepted());
    _trackFirebase((c) => c.trackTermsAccepted());
  }

  // Screen views
  @override
  Future<void> trackScreenView({required String screenName}) async {
    unawaited(_logger?.trackScreenView(screenName: screenName));
    _trackFirebase((c) => c.trackScreenView(screenName: screenName));
  }

  // Notes
  @override
  Future<void> trackNoteCreated({required String noteType}) async {
    unawaited(_logger?.trackNoteCreated(noteType: noteType));
    _trackFirebase((c) => c.trackNoteCreated(noteType: noteType));
  }

  @override
  Future<void> trackNoteUpdated({required String noteType}) async {
    unawaited(_logger?.trackNoteUpdated(noteType: noteType));
    _trackFirebase((c) => c.trackNoteUpdated(noteType: noteType));
  }

  @override
  Future<void> trackNoteDeleted({required String noteType}) async {
    unawaited(_logger?.trackNoteDeleted(noteType: noteType));
    _trackFirebase((c) => c.trackNoteDeleted(noteType: noteType));
  }

  @override
  Future<void> trackNoteArchived({required String noteType}) async {
    unawaited(_logger?.trackNoteArchived(noteType: noteType));
    _trackFirebase((c) => c.trackNoteArchived(noteType: noteType));
  }

  @override
  Future<void> trackNoteRestored({required String noteType}) async {
    unawaited(_logger?.trackNoteRestored(noteType: noteType));
    _trackFirebase((c) => c.trackNoteRestored(noteType: noteType));
  }

  @override
  Future<void> trackNoteShared() async {
    unawaited(_logger?.trackNoteShared());
    _trackFirebase((c) => c.trackNoteShared());
  }

  @override
  Future<void> trackNoteExported({required String format}) async {
    unawaited(_logger?.trackNoteExported(format: format));
    _trackFirebase((c) => c.trackNoteExported(format: format));
  }

  @override
  Future<void> trackNotePrinted() async {
    unawaited(_logger?.trackNotePrinted());
    _trackFirebase((c) => c.trackNotePrinted());
  }

  // Media
  @override
  Future<void> trackAudioRecorded({required int durationSeconds}) async {
    unawaited(_logger?.trackAudioRecorded(durationSeconds: durationSeconds));
    _trackFirebase((c) => c.trackAudioRecorded(durationSeconds: durationSeconds));
  }

  @override
  Future<void> trackOcrPerformed() async {
    unawaited(_logger?.trackOcrPerformed());
    _trackFirebase((c) => c.trackOcrPerformed());
  }

  @override
  Future<void> trackDrawingSaved() async {
    unawaited(_logger?.trackDrawingSaved());
    _trackFirebase((c) => c.trackDrawingSaved());
  }

  @override
  Future<void> trackFileAttached() async {
    unawaited(_logger?.trackFileAttached());
    _trackFirebase((c) => c.trackFileAttached());
  }

  // Folders
  @override
  Future<void> trackFolderCreated() async {
    unawaited(_logger?.trackFolderCreated());
    _trackFirebase((c) => c.trackFolderCreated());
  }

  @override
  Future<void> trackFolderDeleted() async {
    unawaited(_logger?.trackFolderDeleted());
    _trackFirebase((c) => c.trackFolderDeleted());
  }

  // Search & Organization
  @override
  Future<void> trackSearchPerformed({required String query}) async {
    unawaited(_logger?.trackSearchPerformed(query: query));
    _trackFirebase((c) => c.trackSearchPerformed(query: query));
  }

  @override
  Future<void> trackSortChanged({required String sortBy, required String direction}) async {
    unawaited(_logger?.trackSortChanged(sortBy: sortBy, direction: direction));
    _trackFirebase((c) => c.trackSortChanged(sortBy: sortBy, direction: direction));
  }

  @override
  Future<void> trackViewModeChanged({required String viewMode}) async {
    unawaited(_logger?.trackViewModeChanged(viewMode: viewMode));
    _trackFirebase((c) => c.trackViewModeChanged(viewMode: viewMode));
  }

  // Subscription
  @override
  Future<void> trackSubscriptionScreenViewed() async {
    unawaited(_logger?.trackSubscriptionScreenViewed());
    _trackFirebase((c) => c.trackSubscriptionScreenViewed());
  }

  @override
  Future<void> trackPurchaseInitiated({required String productId}) async {
    unawaited(_logger?.trackPurchaseInitiated(productId: productId));
    _trackFirebase((c) => c.trackPurchaseInitiated(productId: productId));
  }

  @override
  Future<void> trackPurchaseCompleted({required String productId}) async {
    unawaited(_logger?.trackPurchaseCompleted(productId: productId));
    _trackFirebase((c) => c.trackPurchaseCompleted(productId: productId));
  }

  @override
  Future<void> trackPurchaseFailed({required String productId, required String error}) async {
    unawaited(_logger?.trackPurchaseFailed(productId: productId, error: error));
    _trackFirebase((c) => c.trackPurchaseFailed(productId: productId, error: error));
  }

  // Sync
  @override
  Future<void> trackSyncStarted() async {
    unawaited(_logger?.trackSyncStarted());
    _trackFirebase((c) => c.trackSyncStarted());
  }

  @override
  Future<void> trackSyncCompleted() async {
    unawaited(_logger?.trackSyncCompleted());
    _trackFirebase((c) => c.trackSyncCompleted());
  }

  @override
  Future<void> trackSyncFailed({required String error}) async {
    unawaited(_logger?.trackSyncFailed(error: error));
    _trackFirebase((c) => c.trackSyncFailed(error: error));
  }

  // Settings
  @override
  Future<void> trackThemeChanged({required String theme}) async {
    unawaited(_logger?.trackThemeChanged(theme: theme));
    _trackFirebase((c) => c.trackThemeChanged(theme: theme));
  }

  @override
  Future<void> trackAccentColorChanged({required String colorName}) async {
    unawaited(_logger?.trackAccentColorChanged(colorName: colorName));
    _trackFirebase((c) => c.trackAccentColorChanged(colorName: colorName));
  }

  @override
  Future<void> trackFontChanged({required String fontFamily}) async {
    unawaited(_logger?.trackFontChanged(fontFamily: fontFamily));
    _trackFirebase((c) => c.trackFontChanged(fontFamily: fontFamily));
  }

  @override
  Future<void> trackBiometricToggled({required bool enabled}) async {
    unawaited(_logger?.trackBiometricToggled(enabled: enabled));
    _trackFirebase((c) => c.trackBiometricToggled(enabled: enabled));
  }

  @override
  Future<void> trackHighContrastToggled({required bool enabled}) async {
    unawaited(_logger?.trackHighContrastToggled(enabled: enabled));
    _trackFirebase((c) => c.trackHighContrastToggled(enabled: enabled));
  }

  // Trash
  @override
  Future<void> trackNoteRestoredFromTrash() async {
    unawaited(_logger?.trackNoteRestoredFromTrash());
    _trackFirebase((c) => c.trackNoteRestoredFromTrash());
  }

  @override
  Future<void> trackTrashEmptied() async {
    unawaited(_logger?.trackTrashEmptied());
    _trackFirebase((c) => c.trackTrashEmptied());
  }
}
