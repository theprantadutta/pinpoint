import 'package:flutter/foundation.dart';
import 'analytics_client.dart';

/// Debug console logger implementation of [AnalyticsClient].
/// Logs all events via debugPrint with [Analytics] prefix.
class LoggerAnalyticsClient implements AnalyticsClient {
  void _log(String event, [Map<String, dynamic>? params]) {
    final paramStr = params != null && params.isNotEmpty ? ' $params' : '';
    debugPrint('[Analytics] $event$paramStr');
  }

  @override
  Future<void> trackSignUp({required String method}) async =>
      _log('sign_up', {'method': method});

  @override
  Future<void> trackLogin({required String method}) async =>
      _log('login', {'method': method});

  @override
  Future<void> trackLogout() async => _log('logout');

  @override
  Future<void> trackAccountLink({required String method}) async =>
      _log('account_link', {'method': method});

  @override
  Future<void> setUserId(String? userId) async =>
      _log('set_user_id', {'user_id': userId});

  @override
  Future<void> trackOnboardingComplete() async => _log('onboarding_complete');

  @override
  Future<void> trackTermsAccepted() async => _log('terms_accepted');

  @override
  Future<void> trackScreenView({required String screenName}) async =>
      _log('screen_view', {'screen_name': screenName});

  @override
  Future<void> trackNoteCreated({required String noteType}) async =>
      _log('note_created', {'note_type': noteType});

  @override
  Future<void> trackNoteUpdated({required String noteType}) async =>
      _log('note_updated', {'note_type': noteType});

  @override
  Future<void> trackNoteDeleted({required String noteType}) async =>
      _log('note_deleted', {'note_type': noteType});

  @override
  Future<void> trackNoteArchived({required String noteType}) async =>
      _log('note_archived', {'note_type': noteType});

  @override
  Future<void> trackNoteRestored({required String noteType}) async =>
      _log('note_restored', {'note_type': noteType});

  @override
  Future<void> trackNoteShared() async => _log('note_shared');

  @override
  Future<void> trackNoteExported({required String format}) async =>
      _log('note_exported', {'format': format});

  @override
  Future<void> trackNotePrinted() async => _log('note_printed');

  @override
  Future<void> trackAudioRecorded({required int durationSeconds}) async =>
      _log('audio_recorded', {'duration_seconds': durationSeconds});

  @override
  Future<void> trackOcrPerformed() async => _log('ocr_performed');

  @override
  Future<void> trackDrawingSaved() async => _log('drawing_saved');

  @override
  Future<void> trackFileAttached() async => _log('file_attached');

  @override
  Future<void> trackFolderCreated() async => _log('folder_created');

  @override
  Future<void> trackFolderDeleted() async => _log('folder_deleted');

  @override
  Future<void> trackSearchPerformed({required String query}) async =>
      _log('search_performed', {'query': query});

  @override
  Future<void> trackSortChanged({required String sortBy, required String direction}) async =>
      _log('sort_changed', {'sort_by': sortBy, 'direction': direction});

  @override
  Future<void> trackViewModeChanged({required String viewMode}) async =>
      _log('view_mode_changed', {'view_mode': viewMode});

  @override
  Future<void> trackSubscriptionScreenViewed() async =>
      _log('subscription_screen_viewed');

  @override
  Future<void> trackPurchaseInitiated({required String productId}) async =>
      _log('purchase_initiated', {'product_id': productId});

  @override
  Future<void> trackPurchaseCompleted({required String productId}) async =>
      _log('purchase_completed', {'product_id': productId});

  @override
  Future<void> trackPurchaseFailed({required String productId, required String error}) async =>
      _log('purchase_failed', {'product_id': productId, 'error': error});

  @override
  Future<void> trackSyncStarted() async => _log('sync_started');

  @override
  Future<void> trackSyncCompleted() async => _log('sync_completed');

  @override
  Future<void> trackSyncFailed({required String error}) async =>
      _log('sync_failed', {'error': error});

  @override
  Future<void> trackThemeChanged({required String theme}) async =>
      _log('theme_changed', {'theme': theme});

  @override
  Future<void> trackAccentColorChanged({required String colorName}) async =>
      _log('accent_color_changed', {'color_name': colorName});

  @override
  Future<void> trackFontChanged({required String fontFamily}) async =>
      _log('font_changed', {'font_family': fontFamily});

  @override
  Future<void> trackBiometricToggled({required bool enabled}) async =>
      _log('biometric_toggled', {'enabled': enabled});

  @override
  Future<void> trackHighContrastToggled({required bool enabled}) async =>
      _log('high_contrast_toggled', {'enabled': enabled});

  @override
  Future<void> trackNoteRestoredFromTrash() async =>
      _log('note_restored_from_trash');

  @override
  Future<void> trackTrashEmptied() async => _log('trash_emptied');
}
