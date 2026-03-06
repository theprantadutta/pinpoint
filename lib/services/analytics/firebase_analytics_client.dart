import 'package:firebase_analytics/firebase_analytics.dart';
import 'analytics_client.dart';

/// Firebase Analytics SDK implementation of [AnalyticsClient].
class FirebaseAnalyticsClient implements AnalyticsClient {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalytics get instance => _analytics;

  @override
  Future<void> trackSignUp({required String method}) =>
      _analytics.logSignUp(signUpMethod: method);

  @override
  Future<void> trackLogin({required String method}) =>
      _analytics.logLogin(loginMethod: method);

  @override
  Future<void> trackLogout() =>
      _analytics.logEvent(name: 'logout');

  @override
  Future<void> trackAccountLink({required String method}) =>
      _analytics.logEvent(name: 'account_link', parameters: {'method': method});

  @override
  Future<void> setUserId(String? userId) =>
      _analytics.setUserId(id: userId);

  @override
  Future<void> trackOnboardingComplete() =>
      _analytics.logEvent(name: 'onboarding_complete');

  @override
  Future<void> trackTermsAccepted() =>
      _analytics.logEvent(name: 'terms_accepted');

  @override
  Future<void> trackScreenView({required String screenName}) =>
      _analytics.logScreenView(screenName: screenName);

  @override
  Future<void> trackNoteCreated({required String noteType}) =>
      _analytics.logEvent(name: 'note_created', parameters: {'note_type': noteType});

  @override
  Future<void> trackNoteUpdated({required String noteType}) =>
      _analytics.logEvent(name: 'note_updated', parameters: {'note_type': noteType});

  @override
  Future<void> trackNoteDeleted({required String noteType}) =>
      _analytics.logEvent(name: 'note_deleted', parameters: {'note_type': noteType});

  @override
  Future<void> trackNoteArchived({required String noteType}) =>
      _analytics.logEvent(name: 'note_archived', parameters: {'note_type': noteType});

  @override
  Future<void> trackNoteRestored({required String noteType}) =>
      _analytics.logEvent(name: 'note_restored', parameters: {'note_type': noteType});

  @override
  Future<void> trackNoteShared() =>
      _analytics.logEvent(name: 'note_shared');

  @override
  Future<void> trackNoteExported({required String format}) =>
      _analytics.logEvent(name: 'note_exported', parameters: {'format': format});

  @override
  Future<void> trackNotePrinted() =>
      _analytics.logEvent(name: 'note_printed');

  @override
  Future<void> trackAudioRecorded({required int durationSeconds}) =>
      _analytics.logEvent(name: 'audio_recorded', parameters: {'duration_seconds': durationSeconds});

  @override
  Future<void> trackOcrPerformed() =>
      _analytics.logEvent(name: 'ocr_performed');

  @override
  Future<void> trackDrawingSaved() =>
      _analytics.logEvent(name: 'drawing_saved');

  @override
  Future<void> trackFileAttached() =>
      _analytics.logEvent(name: 'file_attached');

  @override
  Future<void> trackFolderCreated() =>
      _analytics.logEvent(name: 'folder_created');

  @override
  Future<void> trackFolderDeleted() =>
      _analytics.logEvent(name: 'folder_deleted');

  @override
  Future<void> trackSearchPerformed({required String query}) =>
      _analytics.logEvent(name: 'search_performed', parameters: {'query': query});

  @override
  Future<void> trackSortChanged({required String sortBy, required String direction}) =>
      _analytics.logEvent(name: 'sort_changed', parameters: {'sort_by': sortBy, 'direction': direction});

  @override
  Future<void> trackViewModeChanged({required String viewMode}) =>
      _analytics.logEvent(name: 'view_mode_changed', parameters: {'view_mode': viewMode});

  @override
  Future<void> trackSubscriptionScreenViewed() =>
      _analytics.logEvent(name: 'subscription_screen_viewed');

  @override
  Future<void> trackPurchaseInitiated({required String productId}) =>
      _analytics.logEvent(name: 'purchase_initiated', parameters: {'product_id': productId});

  @override
  Future<void> trackPurchaseCompleted({required String productId}) =>
      _analytics.logEvent(name: 'purchase_completed', parameters: {'product_id': productId});

  @override
  Future<void> trackPurchaseFailed({required String productId, required String error}) =>
      _analytics.logEvent(name: 'purchase_failed', parameters: {'product_id': productId, 'error': error});

  @override
  Future<void> trackSyncStarted() =>
      _analytics.logEvent(name: 'sync_started');

  @override
  Future<void> trackSyncCompleted() =>
      _analytics.logEvent(name: 'sync_completed');

  @override
  Future<void> trackSyncFailed({required String error}) =>
      _analytics.logEvent(name: 'sync_failed', parameters: {'error': error});

  @override
  Future<void> trackThemeChanged({required String theme}) =>
      _analytics.logEvent(name: 'theme_changed', parameters: {'theme': theme});

  @override
  Future<void> trackAccentColorChanged({required String colorName}) =>
      _analytics.logEvent(name: 'accent_color_changed', parameters: {'color_name': colorName});

  @override
  Future<void> trackFontChanged({required String fontFamily}) =>
      _analytics.logEvent(name: 'font_changed', parameters: {'font_family': fontFamily});

  @override
  Future<void> trackBiometricToggled({required bool enabled}) =>
      _analytics.logEvent(name: 'biometric_toggled', parameters: {'enabled': enabled});

  @override
  Future<void> trackHighContrastToggled({required bool enabled}) =>
      _analytics.logEvent(name: 'high_contrast_toggled', parameters: {'enabled': enabled});

  @override
  Future<void> trackNoteRestoredFromTrash() =>
      _analytics.logEvent(name: 'note_restored_from_trash');

  @override
  Future<void> trackTrashEmptied() =>
      _analytics.logEvent(name: 'trash_emptied');
}
