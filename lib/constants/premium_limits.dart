/// Premium feature limits for free tier users
class PremiumLimits {
  // Private constructor to prevent instantiation
  PremiumLimits._();

  // Cloud Sync Limits
  static const int maxSyncedNotesForFree = 50;
  static const int maxSyncedNotesForPremium = -1; // -1 means unlimited

  // Folder Limits
  static const int maxFoldersForFree = 5;
  static const int maxFoldersForPremium = -1;

  // OCR Limits (monthly)
  static const int maxOcrScansPerMonthForFree = 20;
  static const int maxOcrScansPerMonthForPremium = -1;

  // Export Limits (monthly)
  static const int maxExportsPerMonthForFree = 10;
  static const int maxExportsPerMonthForPremium = -1;

  // Voice Recording Limits (seconds)
  static const int maxVoiceRecordingDurationForFree = 120; // 2 minutes
  static const int maxVoiceRecordingDurationForPremium = -1;

  // Theme Limits
  static const int maxThemeColorsForFree = 2;
  static const List<String> freeThemeColors = ['Neon Mint', 'Blue Ocean'];

  // File Attachment Limits
  static const int maxAttachmentsPerNoteForFree = 3;
  static const int maxAttachmentsPerNoteForPremium = -1;

  // Helper methods
  static bool isUnlimited(int limit) => limit == -1;

  static String formatLimit(int limit) {
    if (isUnlimited(limit)) return 'Unlimited';
    return limit.toString();
  }
}

/// Shared preference keys for usage tracking
class UsageTrackingKeys {
  UsageTrackingKeys._();

  static const String syncedNotesCount = 'usage_synced_notes_count';
  static const String ocrScansThisMonth = 'usage_ocr_scans_month';
  static const String exportsThisMonth = 'usage_exports_month';
  static const String lastMonthlyReset = 'usage_last_monthly_reset';
}
