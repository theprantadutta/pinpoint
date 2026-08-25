/// Coarse bucket for a search query's length.
///
/// Search analytics deliberately carry a bucket, never the query itself — see
/// [AnalyticsClient.trackSearchPerformed]. Buckets are a small closed set so the
/// event can never widen into a content channel.
String searchLengthBucket(int queryLength) {
  if (queryLength <= 3) return '1-3';
  if (queryLength <= 10) return '4-10';
  if (queryLength <= 25) return '11-25';
  return '26+';
}

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
  /// Search terms are note content on an end-to-end-encrypted app, so this
  /// signature carries a LENGTH, never the text. Do not add a `query`
  /// parameter back — not raw, not truncated, not hashed (a hash of a short
  /// query is trivially reversible and is still content-derived). Clients emit
  /// only the coarse [searchLengthBucket].
  Future<void> trackSearchPerformed({required int queryLength});
  Future<void> trackSortChanged({required String sortBy, required String direction});
  Future<void> trackViewModeChanged({required String viewMode});

  // Subscription
  //
  // The checkout funnel is deliberately split so every event means exactly what
  // it says. `checkout_launch_*` describe the STORE SHEET, not a sale; the only
  // conversion event is [trackPurchaseVerified].
  //
  // `reason` parameters are coarse closed-set codes — never an exception
  // string, a store debug message, or a purchase token. Raw detail goes to the
  // local logger via `log.e`, never into an analytics parameter.
  Future<void> trackSubscriptionScreenViewed();

  /// User tapped buy, before the store is called at all.
  Future<void> trackCheckoutStarted({required String productId});

  /// `buyNonConsumable()` returned true — the billing sheet was launched.
  /// This is NOT a purchase.
  Future<void> trackCheckoutLaunchSucceeded({required String productId});

  /// `buyNonConsumable()` returned false or threw before the sheet appeared.
  Future<void> trackCheckoutLaunchFailed({
    required String productId,
    required String reason,
  });

  /// `PurchaseStatus.canceled` on the purchase stream.
  Future<void> trackCheckoutCancelled({required String productId});

  /// `PurchaseStatus.pending` on the purchase stream (deferred payment).
  Future<void> trackCheckoutPending({required String productId});

  /// `PurchaseStatus.error` on the purchase stream.
  Future<void> trackCheckoutError({
    required String productId,
    required String reason,
  });

  /// `PurchaseStatus.purchased` / `.restored` seen on the purchase stream.
  /// [source] is `'purchase'` or `'restore'`.
  Future<void> trackStorePurchaseConfirmed({
    required String productId,
    required String source,
  });

  /// Backend verification succeeded. This is the single conversion event.
  ///
  /// [source] is `'purchase'` or `'restore'` so restores do not inflate it, or
  /// `'retry'` when a previously provisional purchase was confirmed later by
  /// the background retry. It fires only for a genuine backend confirmation —
  /// a provisional grant emits [trackPurchaseProvisionallyGranted] instead.
  Future<void> trackPurchaseVerified({
    required String productId,
    required String platform,
    required String source,
  });

  /// The store charged the user but the backend could not confirm it, so
  /// premium was unlocked locally and the purchase stored for retry.
  ///
  /// This is an entitlement, NOT a sale — do not count it as a conversion. If
  /// the retry later succeeds, that emits `purchase_verified` with
  /// `source: 'retry'`. A persistent gap between this event and that one means
  /// the verification endpoint is failing and users are running on trust.
  Future<void> trackPurchaseProvisionallyGranted({
    required String productId,
    required String platform,
    required String reason,
  });

  /// Verification was rejected, or could not be attempted at all.
  Future<void> trackVerificationFailed({
    required String productId,
    required String reason,
  });

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
