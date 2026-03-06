import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../sync/sync_manager.dart';
import '../service_locators/init_service_locators.dart';
import '../services/analytics/analytics_facade.dart';
import '../services/backend_auth_service.dart';
import '../services/google_sign_in_service.dart';

/// Result of logout validation
class LogoutValidationResult {
  final bool canProceed;
  final String? errorMessage;
  final LogoutBlockReason? blockReason;
  final int? audioNotesCount;

  LogoutValidationResult({
    required this.canProceed,
    this.errorMessage,
    this.blockReason,
    this.audioNotesCount,
  });
}

/// Reasons why logout might be blocked
enum LogoutBlockReason {
  audioNotesExist,
  syncFailed,
}

/// Logout service phases for progress tracking
enum LogoutPhase {
  validating,
  syncing,
  cleaningData,
  signingOut,
  completed,
}

/// Service to handle complete logout flow with validation and cleanup
class LogoutService {
  final AppDatabase _database;
  final SyncManager _syncManager;
  final BackendAuthService _backendAuthService;
  final GoogleSignInService _googleSignInService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Progress tracking
  LogoutPhase _currentPhase = LogoutPhase.validating;
  Function(LogoutPhase)? onPhaseChanged;

  LogoutService({
    required AppDatabase database,
    required SyncManager syncManager,
    required BackendAuthService backendAuthService,
    required GoogleSignInService googleSignInService,
  })  : _database = database,
        _syncManager = syncManager,
        _backendAuthService = backendAuthService,
        _googleSignInService = googleSignInService;

  /// Factory constructor using service locator
  factory LogoutService.fromServiceLocator({
    required BackendAuthService backendAuthService,
    required GoogleSignInService googleSignInService,
  }) {
    return LogoutService(
      database: getIt<AppDatabase>(),
      syncManager: getIt<SyncManager>(),
      backendAuthService: backendAuthService,
      googleSignInService: googleSignInService,
    );
  }

  LogoutPhase get currentPhase => _currentPhase;

  /// Main logout method - validates, syncs, and cleans up
  Future<bool> performLogout() async {
    try {
      // Track analytics
      final analytics = getIt<AnalyticsFacade>();
      analytics.trackLogout();
      analytics.setUserId(null);

      // Phase 1: Validation
      _updatePhase(LogoutPhase.validating);
      final validation = await validateLogout();

      if (!validation.canProceed) {
        debugPrint(
            '❌ [LogoutService] Logout validation failed: ${validation.errorMessage}');
        return false;
      }

      // Phase 2: Sync unsynced notes
      _updatePhase(LogoutPhase.syncing);
      final syncSuccess = await _syncUnsyncedNotes();

      if (!syncSuccess) {
        debugPrint('❌ [LogoutService] Sync failed - cannot proceed with logout');
        // Throw error to show user the "Force Logout" dialog
        throw Exception('Sync failed - unsynced notes will be lost if you continue');
      }

      // Phase 3: Sign out from backend (BEFORE clearing auth token)
      _updatePhase(LogoutPhase.signingOut);
      await _signOutFromBackend();

      // Phase 4: Clean up local data (AFTER backend logout)
      _updatePhase(LogoutPhase.cleaningData);
      await _cleanupLocalData();

      // Phase 5: Complete
      _updatePhase(LogoutPhase.completed);
      debugPrint('✅ [LogoutService] Logout completed successfully');

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [LogoutService] Logout failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Validate if logout can proceed
  Future<LogoutValidationResult> validateLogout() async {
    try {
      // Check for audio notes (BLOCKER)
      final audioNotesCount = await _getAudioNotesCount();

      if (audioNotesCount > 0) {
        return LogoutValidationResult(
          canProceed: false,
          errorMessage:
              'You have $audioNotesCount audio recording${audioNotesCount > 1 ? 's' : ''} that will be lost',
          blockReason: LogoutBlockReason.audioNotesExist,
          audioNotesCount: audioNotesCount,
        );
      }

      // All validation passed
      return LogoutValidationResult(canProceed: true);
    } catch (e) {
      debugPrint('❌ [LogoutService] Validation error: $e');
      return LogoutValidationResult(
        canProceed: false,
        errorMessage: 'Validation failed: $e',
      );
    }
  }

  /// Check if there are unsynced notes
  Future<bool> hasUnsyncedNotes() async {
    try {
      final unsyncedNotes = await (_database.select(_database.notes)
            ..where((tbl) => tbl.isSynced.equals(false)))
          .get();

      return unsyncedNotes.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [LogoutService] Error checking unsynced notes: $e');
      return false;
    }
  }

  /// Get count of unsynced notes
  Future<int> getUnsyncedNotesCount() async {
    try {
      final unsyncedNotes = await (_database.select(_database.notes)
            ..where((tbl) => tbl.isSynced.equals(false)))
          .get();

      return unsyncedNotes.length;
    } catch (e) {
      debugPrint('❌ [LogoutService] Error counting unsynced notes: $e');
      return 0;
    }
  }

  /// Sync unsynced notes before logout
  Future<bool> _syncUnsyncedNotes() async {
    try {
      // Check if there are unsynced notes
      final hasUnsynced = await hasUnsyncedNotes();

      if (!hasUnsynced) {
        debugPrint('✅ [LogoutService] No unsynced notes, skipping sync');
        return true;
      }

      final unsyncedCount = await getUnsyncedNotesCount();
      debugPrint('📤 [LogoutService] Syncing $unsyncedCount unsynced notes...');

      // Perform sync (upload only)
      final result = await _syncManager.upload();

      if (result.success) {
        debugPrint('✅ [LogoutService] Sync completed: ${result.message}');
        return true;
      } else {
        debugPrint('❌ [LogoutService] Sync failed: ${result.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [LogoutService] Sync error: $e');
      return false;
    }
  }

  /// Clean up all local data
  Future<void> _cleanupLocalData() async {
    try {
      // 1. Delete audio files from filesystem
      await _deleteAudioFiles();

      // 2. Clear database tables
      await _clearDatabase();

      // 3. Clear secure storage (auth token & encryption key)
      await _clearSecureStorage();

      // 4. Clear SharedPreferences (selective - keep UI prefs)
      await _clearSharedPreferences();

      debugPrint('✅ [LogoutService] Local data cleanup completed');
    } catch (e) {
      debugPrint('❌ [LogoutService] Cleanup error: $e');
      rethrow;
    }
  }

  /// Delete all audio files from filesystem
  Future<void> _deleteAudioFiles() async {
    try {
      final audioNotes = await _database.select(_database.audioNotes).get();

      if (audioNotes.isEmpty) {
        debugPrint('ℹ️ [LogoutService] No audio files to delete');
        return;
      }

      debugPrint(
          '🗑️ [LogoutService] Deleting ${audioNotes.length} audio files...');

      int deletedCount = 0;
      for (final audioNote in audioNotes) {
        try {
          final file = File(audioNote.audioFilePath);
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        } catch (e) {
          debugPrint(
              '⚠️ [LogoutService] Failed to delete audio file: ${audioNote.audioFilePath} - $e');
          // Continue with other files
        }
      }

      debugPrint('✅ [LogoutService] Deleted $deletedCount audio files');
    } catch (e) {
      debugPrint('❌ [LogoutService] Error deleting audio files: $e');
      // Don't fail logout if audio deletion fails
    }
  }

  /// Clear all database tables
  Future<void> _clearDatabase() async {
    try {
      // Count items before deleting
      final notesCount = await _database.select(_database.notes).get();
      final foldersCount = await _database.select(_database.noteFolders).get();

      debugPrint('🗑️ [LogoutService] Clearing database...');
      debugPrint('   - Deleting ${notesCount.length} notes (and related data via CASCADE)');
      debugPrint('   - Deleting ${foldersCount.length} folders');

      await _database.transaction(() async {
        // Delete notes (CASCADE will handle related tables)
        await _database.delete(_database.notes).go();

        // Delete folders
        await _database.delete(_database.noteFolders).go();
      });

      // Verify deletion
      final remainingNotes = await _database.select(_database.notes).get();
      final remainingFolders = await _database.select(_database.noteFolders).get();

      if (remainingNotes.isEmpty && remainingFolders.isEmpty) {
        debugPrint('✅ [LogoutService] Database cleared successfully');
        debugPrint('   - Confirmed: 0 notes remaining');
        debugPrint('   - Confirmed: 0 folders remaining');
      } else {
        debugPrint('⚠️ [LogoutService] Warning: ${remainingNotes.length} notes and ${remainingFolders.length} folders still remain!');
      }
    } catch (e) {
      debugPrint('❌ [LogoutService] Error clearing database: $e');
      rethrow;
    }
  }

  /// Clear secure storage (auth tokens & encryption key)
  Future<void> _clearSecureStorage() async {
    try {
      debugPrint('🗑️ [LogoutService] Clearing secure storage...');

      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'encryption_key');

      debugPrint('✅ [LogoutService] Secure storage cleared');
    } catch (e) {
      debugPrint('❌ [LogoutService] Error clearing secure storage: $e');
      rethrow;
    }
  }

  /// Clear SharedPreferences (selective - preserve UI preferences)
  Future<void> _clearSharedPreferences() async {
    try {
      debugPrint('🗑️ [LogoutService] Clearing SharedPreferences...');

      final prefs = await SharedPreferences.getInstance();

      // Keys to preserve (UI preferences)
      const keysToKeep = {
        'is_dark_mode_key',
        'is_flex_scheme_key',
        'biometric_key',
        'selected-font-key',
        'home_screen_view_type_key',
        'home_screen_sort_type_key',
        'home_screen_sort_direction_key',
      };

      // Get all keys
      final allKeys = prefs.getKeys();

      // Remove keys that should not be preserved
      for (final key in allKeys) {
        if (!keysToKeep.contains(key)) {
          await prefs.remove(key);
        }
      }

      debugPrint(
          '✅ [LogoutService] SharedPreferences cleared (preserved ${keysToKeep.length} UI preferences)');
    } catch (e) {
      debugPrint('❌ [LogoutService] Error clearing SharedPreferences: $e');
      // Don't fail logout if SharedPreferences clearing fails
    }
  }

  /// Sign out from backend (must be called BEFORE clearing auth token)
  Future<void> _signOutFromBackend() async {
    try {
      debugPrint('👋 [LogoutService] Signing out from backend...');

      // Logout from backend (clears state & token on backend)
      // This must be called BEFORE we delete the auth token locally
      await _backendAuthService.logout();

      // Sign out from Google (doesn't require backend auth)
      await _googleSignInService.signOut();

      debugPrint('✅ [LogoutService] Signed out from backend and Google');
    } catch (e) {
      debugPrint('❌ [LogoutService] Error signing out from backend: $e');
      // Continue even if backend sign out fails
      // We'll still clear local data

      // Try to sign out from Google anyway
      try {
        await _googleSignInService.signOut();
      } catch (googleError) {
        debugPrint('❌ [LogoutService] Error signing out from Google: $googleError');
      }
    }
  }

  /// Get count of audio notes
  Future<int> _getAudioNotesCount() async {
    try {
      final audioNotes = await _database.select(_database.audioNotes).get();
      return audioNotes.length;
    } catch (e) {
      debugPrint('❌ [LogoutService] Error counting audio notes: $e');
      return 0;
    }
  }

  /// Update current phase and notify
  void _updatePhase(LogoutPhase phase) {
    _currentPhase = phase;
    onPhaseChanged?.call(phase);
  }
}
