/// Abstract interface for analytics tracking.
/// Each method corresponds to a typed event with specific parameters.
abstract class AnalyticsClient {
  // Auth
  Future<void> trackSignUp({required String method});
  Future<void> trackLogin({required String method});
  Future<void> trackLogout();
  Future<void> trackAccountLink({required String method});

  // User properties
  Future<void> setUserId(String? userId);

  // Onboarding
  Future<void> trackOnboardingComplete();
  Future<void> trackTermsAccepted();

  // Screen views
  Future<void> trackScreenView({required String screenName});

  // Notes
  Future<void> trackNoteCreated({required String noteType});
  Future<void> trackNoteUpdated({required String noteType});
  Future<void> trackNoteDeleted({required String noteType});
  Future<void> trackNoteArchived({required String noteType});
  Future<void> trackNoteRestored({required String noteType});
  Future<void> trackNoteShared();
  Future<void> trackNoteExported({required String format});
  Future<void> trackNotePrinted();

  // Media
  Future<void> trackAudioRecorded({required int durationSeconds});
  Future<void> trackOcrPerformed();
  Future<void> trackDrawingSaved();
  Future<void> trackFileAttached();

  // Folders
  Future<void> trackFolderCreated();
  Future<void> trackFolderDeleted();

  // Search & Organization
  Future<void> trackSearchPerformed({required String query});
  Future<void> trackSortChanged({required String sortBy, required String direction});
  Future<void> trackViewModeChanged({required String viewMode});

  // Subscription
  Future<void> trackSubscriptionScreenViewed();
  Future<void> trackPurchaseInitiated({required String productId});
  Future<void> trackPurchaseCompleted({required String productId});
  Future<void> trackPurchaseFailed({required String productId, required String error});

  // Sync
  Future<void> trackSyncStarted();
  Future<void> trackSyncCompleted();
  Future<void> trackSyncFailed({required String error});

  // Settings
  Future<void> trackThemeChanged({required String theme});
  Future<void> trackAccentColorChanged({required String colorName});
  Future<void> trackFontChanged({required String fontFamily});
  Future<void> trackBiometricToggled({required bool enabled});
  Future<void> trackHighContrastToggled({required bool enabled});

  // Trash
  Future<void> trackNoteRestoredFromTrash();
  Future<void> trackTrashEmptied();

  // Todo
  Future<void> trackTodoFilterChanged({required String filter});

  // Premium
  Future<void> trackPremiumGateShown({required String feature});

  // Notifications
  Future<void> trackNotificationPermissionResult({required bool granted});

  // Subscription
  Future<void> trackRestorePurchaseInitiated();

  // Folders
  Future<void> trackFolderRenamed();
}
