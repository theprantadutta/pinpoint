import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Exception thrown when account linking is required
class AccountLinkingRequiredException implements Exception {
  final String message;
  final bool requiresLinking;

  AccountLinkingRequiredException(this.message, {this.requiresLinking = true});

  @override
  String toString() => message;
}

/// Exception thrown when rate limit is exceeded (HTTP 429)
class RateLimitExceededException implements Exception {
  final String message;
  final Duration? retryAfter;
  final int? remainingRequests;

  RateLimitExceededException(
    this.message, {
    this.retryAfter,
    this.remainingRequests,
  });

  @override
  String toString() =>
      'RateLimitExceededException: $message${retryAfter != null ? ' (retry after ${retryAfter!.inSeconds}s)' : ''}';
}

/// Structured API error with user-friendly messaging
class ApiError implements Exception {
  final String userMessage;
  final String? suggestion;
  final int? statusCode;
  final String? technicalDetails;
  final ApiErrorType type;

  ApiError({
    required this.userMessage,
    this.suggestion,
    this.statusCode,
    this.technicalDetails,
    required this.type,
  });

  @override
  String toString() => userMessage;

  /// Get a combined message with suggestion
  String get fullMessage => suggestion != null
      ? '$userMessage $suggestion'
      : userMessage;
}

/// Types of API errors for programmatic handling
enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  rateLimit,
  serverError,
  maintenance,
  unknown,
}

class ApiService {
  // Backend API configuration - uses prod URL in release mode, dev URL otherwise
  static final String baseUrl = kReleaseMode
      ? dotenv.env['API_BASE_URL_PROD']!
      : dotenv.env['API_BASE_URL_DEV']!;
  static const String apiV1 = '/api/v1';

  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  // Refresh token state
  bool _isRefreshing = false;

  /// Callback for when session expires and user needs to re-login
  VoidCallback? onSessionExpired;

  ApiService._internal() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl + apiV1,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Request interceptor to add JWT token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          _logger.d('REQUEST[${options.method}] => ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('RESPONSE[${response.statusCode}] => ${response.data}');
          return handler.next(response);
        },
        onError: (error, handler) async {
          _logger.e('ERROR[${error.response?.statusCode}] => ${error.message}');
          if (error.response != null) {
            _logger.e('ERROR Response Data: ${error.response?.data}');
            _logger.e('ERROR Response Headers: ${error.response?.headers}');
          }

          // Handle 401 Unauthorized - attempt token refresh
          if (error.response?.statusCode == 401) {
            // Don't try to refresh if we're already refreshing or if this is a refresh request
            final isRefreshRequest = error.requestOptions.path.contains('/auth/refresh');
            if (!_isRefreshing && !isRefreshRequest) {
              _logger.i('🔄 Access token expired, attempting refresh...');
              final refreshed = await _tryRefreshToken();

              if (refreshed) {
                _logger.i('✅ Token refreshed successfully, retrying request...');
                // Retry the original request with new token
                try {
                  final opts = error.requestOptions;
                  final newToken = await getToken();
                  opts.headers['Authorization'] = 'Bearer $newToken';
                  final response = await _dio.fetch(opts);
                  return handler.resolve(response);
                } catch (retryError) {
                  _logger.e('❌ Retry after refresh failed: $retryError');
                  return handler.next(error);
                }
              } else {
                _logger.w('❌ Token refresh failed, session expired');
                await _handleSessionExpired();
              }
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Attempt to refresh the access token using the refresh token
  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        _logger.w('No refresh token available');
        return false;
      }

      _logger.d('Calling /auth/refresh endpoint...');

      // Make refresh request without the interceptor adding auth header
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'] as String;
        final newRefreshToken = response.data['refresh_token'] as String?;

        await saveToken(newAccessToken);
        if (newRefreshToken != null) {
          await saveRefreshToken(newRefreshToken);
        }

        _logger.i('🔐 Tokens refreshed successfully');
        return true;
      }

      return false;
    } catch (e) {
      _logger.e('Token refresh failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Handle session expiration - clear tokens and notify
  Future<void> _handleSessionExpired() async {
    await deleteToken();
    await deleteRefreshToken();
    onSessionExpired?.call();
  }

  // ============================================================================
  // Token Management
  // ============================================================================

  static const String _accessTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Save refresh token to secure storage
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Get refresh token from secure storage
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Delete refresh token from secure storage
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Save both access and refresh tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await saveToken(accessToken);
    await saveRefreshToken(refreshToken);
  }

  /// Delete both access and refresh tokens
  Future<void> clearTokens() async {
    await deleteToken();
    await deleteRefreshToken();
  }

  // ============================================================================
  // Authentication Endpoints
  // ============================================================================

  /// Register new user
  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
        },
      );

      // Save tokens
      final accessToken = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String?;
      await saveToken(accessToken);
      if (refreshToken != null) {
        await saveRefreshToken(refreshToken);
      }

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      // Save tokens
      final accessToken = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String?;
      await saveToken(accessToken);
      if (refreshToken != null) {
        await saveRefreshToken(refreshToken);
      }

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      _logger.e('Logout error: $e');
    } finally {
      await clearTokens();
    }
  }

  /// Authenticate with Firebase token (Google Sign-In)
  Future<Map<String, dynamic>> authenticateWithFirebase(
      String firebaseToken) async {
    try {
      _logger.i('🔐 Authenticating with Firebase token...');
      _logger.d(
          'Firebase token (first 50 chars): ${firebaseToken.substring(0, firebaseToken.length > 50 ? 50 : firebaseToken.length)}...');

      final response = await _dio.post(
        '/auth/firebase',
        data: {
          'firebase_token': firebaseToken,
        },
      );

      _logger.i('✅ Firebase authentication successful');

      // Save tokens
      final accessToken = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String?;
      await saveToken(accessToken);
      if (refreshToken != null) {
        await saveRefreshToken(refreshToken);
      }

      return response.data;
    } on DioException catch (e) {
      _logger.e(
          '❌ Firebase authentication failed with status: ${e.response?.statusCode}');
      _logger.e('Error type: ${e.type}');
      _logger.e('Error message: ${e.message}');

      if (e.response != null) {
        _logger.e('Response data: ${e.response?.data}');
        _logger.e('Response headers: ${e.response?.headers}');
      }

      // Check if this is an account linking conflict (HTTP 409)
      if (e.response?.statusCode == 409) {
        // Return the error with conflict flag for handling
        throw AccountLinkingRequiredException(
          'An account with this email already exists. Please link your accounts.',
          requiresLinking: true,
        );
      }
      throw _handleError(e);
    }
  }

  /// Link Google account to existing account (requires password verification)
  Future<Map<String, dynamic>> linkGoogleAccount({
    required String firebaseToken,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/link-google',
        data: {
          'firebase_token': firebaseToken,
          'password': password,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Unlink Google account from current account
  Future<Map<String, dynamic>> unlinkGoogleAccount() async {
    try {
      final response = await _dio.post('/auth/unlink-google');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get linked authentication providers
  Future<Map<String, dynamic>> getAuthProviders() async {
    try {
      final response = await _dio.get('/auth/providers');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Notes Sync Endpoints
  // ============================================================================

  /// Get all encrypted notes for sync
  Future<List<Map<String, dynamic>>> getNotes({
    int since = 0,
    bool includeDeleted = false,
  }) async {
    try {
      final response = await _dio.get(
        '/notes/sync',
        queryParameters: {
          'since': since,
          'include_deleted': includeDeleted,
        },
      );

      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload encrypted notes for sync
  Future<Map<String, dynamic>> syncNotes({
    required List<Map<String, dynamic>> notes,
    required String deviceId,
  }) async {
    try {
      final response = await _dio.post(
        '/notes/sync',
        data: {
          'notes': notes,
          'device_id': deviceId,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete notes
  Future<Map<String, dynamic>> deleteNotes({
    required List<String> clientNoteUuids,
    bool hardDelete = false,
  }) async {
    try {
      final response = await _dio.delete(
        '/notes/notes',
        queryParameters: {'hard_delete': hardDelete},
        data: {'client_note_uuids': clientNoteUuids},
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Folders Sync Endpoints
  // ============================================================================

  /// Sync folders bidirectionally (upload + download)
  /// CRITICAL: Call this BEFORE note sync to prevent race conditions
  Future<Map<String, dynamic>> syncFolders({
    required List<Map<String, dynamic>> folders,
  }) async {
    try {
      final response = await _dio.post(
        '/folders/sync',
        data: {'folders': folders},
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get all folders for the user
  Future<List<Map<String, dynamic>>> getAllFolders() async {
    try {
      final response = await _dio.get('/folders/all');

      // Backend returns list directly, not wrapped in 'folders' key
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Subscription Endpoints
  // ============================================================================

  /// Verify Google Play purchase
  Future<Map<String, dynamic>> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    try {
      final response = await _dio.post(
        '/subscription/verify',
        data: {
          'purchase_token': purchaseToken,
          'product_id': productId,
        },
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get subscription status
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await _dio.get('/subscription/status');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Verify purchase with device ID (no authentication required)
  ///
  /// Optionally pass [userId] to sync the subscription with the user's account
  /// when they are authenticated. This keeps both device and user records in sync.
  Future<Map<String, dynamic>> verifyPurchaseWithDevice({
    required String deviceId,
    required String purchaseToken,
    required String productId,
    String? userId,
  }) async {
    try {
      final data = {
        'device_id': deviceId,
        'purchase_token': purchaseToken,
        'product_id': productId,
      };

      // Include user_id if available to sync with user record
      if (userId != null) {
        data['user_id'] = userId;
      }

      final response = await _dio.post(
        '/subscription/verify-device',
        data: data,
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get subscription status by device ID (no authentication required)
  Future<Map<String, dynamic>> getSubscriptionStatusByDevice(
      String deviceId) async {
    try {
      final response = await _dio.get('/subscription/status/$deviceId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Notification Endpoints
  // ============================================================================

  /// Register FCM token for push notifications
  Future<void> registerFCMToken({
    required String fcmToken,
    required String deviceId,
    required String platform,
  }) async {
    try {
      await _dio.post(
        '/notifications/register',
        data: {
          'fcm_token': fcmToken,
          'device_id': deviceId,
          'platform': platform,
        },
      );
    } on DioException catch (e) {
      _logger.e('FCM registration error: ${_handleError(e)}');
    }
  }

  /// Remove FCM token
  Future<void> removeFCMToken(String deviceId) async {
    try {
      await _dio.delete('/notifications/token/$deviceId');
    } on DioException catch (e) {
      _logger.e('FCM removal error: ${_handleError(e)}');
    }
  }

  // ============================================================================
  // Encryption Key Management
  // ============================================================================

  /// Get encryption key from cloud
  Future<String?> getEncryptionKey() async {
    try {
      final response = await _dio.get('/encryption/key');
      if (response.statusCode == 200) {
        return response.data['encryption_key'] as String;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Key not found in cloud - this is normal for new users
        _logger.d('No encryption key found in cloud (new user)');
        return null;
      }
      _logger.e('Get encryption key error: ${_handleError(e)}');
      throw Exception(_handleError(e));
    }
  }

  /// Store encryption key in cloud
  Future<void> storeEncryptionKey(String encryptionKey) async {
    try {
      await _dio.post(
        '/encryption/key',
        data: {
          'encryption_key': encryptionKey,
        },
      );
    } on DioException catch (e) {
      _logger.e('Store encryption key error: ${_handleError(e)}');
      throw Exception(_handleError(e));
    }
  }

  // ============================================================================
  // Usage Tracking Endpoints
  // ============================================================================

  /// Get comprehensive usage statistics for the authenticated user
  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final response = await _dio.get('/usage/stats');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Reconcile synced notes count with actual database count
  Future<Map<String, dynamic>> reconcileUsage() async {
    try {
      final response = await _dio.post(
        '/usage/reconcile',
        data: {}, // Empty body required by backend
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Increment OCR scans counter on the backend
  /// Called after each successful OCR operation
  Future<Map<String, dynamic>> incrementOcrScans() async {
    try {
      final response = await _dio.post(
        '/usage/ocr',
        data: {},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Increment exports counter on the backend
  /// Called after each successful export (PDF/Markdown)
  Future<Map<String, dynamic>> incrementExports() async {
    try {
      final response = await _dio.post(
        '/usage/export',
        data: {},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Reminder Endpoints (Backend-Controlled Notifications)
  // ============================================================================

  /// Create a new reminder (schedules backend notification)
  Future<Map<String, dynamic>> createReminder({
    required String noteUuid,
    required String title,
    required String notificationTitle,
    String? notificationContent,
    required DateTime reminderTime,
    String recurrenceType = 'once',
    int recurrenceInterval = 1,
    String recurrenceEndType = 'never',
    String? recurrenceEndValue,
  }) async {
    try {
      final data = {
        'note_uuid': noteUuid,
        'title': title,
        'notification_title': notificationTitle,
        'notification_content': notificationContent,
        'reminder_time': reminderTime.toUtc().toIso8601String(),
        'recurrence_type': recurrenceType,
        'recurrence_interval': recurrenceInterval,
        'recurrence_end_type': recurrenceEndType,
      };

      if (recurrenceEndValue != null) {
        data['recurrence_end_value'] = recurrenceEndValue;
      }

      final response = await _dio.post(
        '/reminders',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update an existing reminder (reschedules if time changed)
  Future<Map<String, dynamic>> updateReminder({
    required String reminderId,
    String? title,
    String? notificationTitle,
    String? notificationContent,
    DateTime? reminderTime,
    String? recurrenceType,
    int? recurrenceInterval,
    String? recurrenceEndType,
    String? recurrenceEndValue,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (notificationTitle != null) data['notification_title'] = notificationTitle;
      if (notificationContent != null) data['notification_content'] = notificationContent;
      if (reminderTime != null) {
        data['reminder_time'] = reminderTime.toUtc().toIso8601String();
      }
      if (recurrenceType != null) data['recurrence_type'] = recurrenceType;
      if (recurrenceInterval != null) data['recurrence_interval'] = recurrenceInterval;
      if (recurrenceEndType != null) data['recurrence_end_type'] = recurrenceEndType;
      if (recurrenceEndValue != null) data['recurrence_end_value'] = recurrenceEndValue;

      final response = await _dio.put(
        '/reminders/$reminderId',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete a reminder (cancels scheduled notification)
  Future<Map<String, dynamic>> deleteReminder(String reminderId) async {
    try {
      final response = await _dio.delete('/reminders/$reminderId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get all reminders for the current user
  Future<List<Map<String, dynamic>>> getReminders({
    bool includeTriggered = true,
  }) async {
    try {
      final response = await _dio.get(
        '/reminders',
        queryParameters: {
          'include_triggered': includeTriggered,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['reminders'] as List);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get a specific reminder
  Future<Map<String, dynamic>> getReminder(String reminderId) async {
    try {
      final response = await _dio.get('/reminders/$reminderId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Bulk sync reminders from client (for migration)
  Future<Map<String, dynamic>> syncReminders(
    List<Map<String, dynamic>> reminders,
  ) async {
    try {
      final response = await _dio.post(
        '/reminders/sync',
        data: {
          'reminders': reminders,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Audio File Management
  // ============================================================================

  /// Upload an audio file to the backend
  /// Returns the server file path
  Future<String> uploadAudioFile(String localFilePath) async {
    try {
      final file = await MultipartFile.fromFile(
        localFilePath,
        filename: localFilePath.split('/').last,
      );

      final formData = FormData.fromMap({
        'file': file,
      });

      final response = await _dio.post(
        '/audio/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data['success'] == true) {
        return response.data['file_path'] as String;
      } else {
        throw Exception('Upload failed: ${response.data['message']}');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Download an audio file from the backend
  /// Returns the local file path where the audio was saved
  Future<String> downloadAudioFile(
    String serverFilePath,
    String localSavePath,
  ) async {
    try {
      // Parse server path: userId/filename
      final parts = serverFilePath.split('/');
      if (parts.length != 2) {
        throw Exception('Invalid server file path: $serverFilePath');
      }

      final userId = parts[0];
      final filename = parts[1];

      // Download file
      await _dio.download(
        '/audio/download/$userId/$filename',
        localSavePath,
      );

      return localSavePath;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Check if an audio file exists on the server
  Future<bool> audioFileExists(String serverFilePath) async {
    try {
      final parts = serverFilePath.split('/');
      if (parts.length != 2) {
        return false;
      }

      final userId = parts[0];
      final filename = parts[1];

      final response = await _dio.head(
        '/audio/download/$userId/$filename',
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete an audio file from the backend
  Future<void> deleteAudioFile(String serverFilePath) async {
    try {
      final parts = serverFilePath.split('/');
      if (parts.length != 2) {
        throw Exception('Invalid server file path: $serverFilePath');
      }

      final userId = parts[0];
      final filename = parts[1];

      final response = await _dio.delete(
        '/audio/delete/$userId/$filename',
      );

      if (response.data['success'] != true) {
        throw Exception('Delete failed: ${response.data['message']}');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================================================
  // Error Handling
  // ============================================================================

  /// Handle DioException and return a user-friendly error message
  /// Throws [RateLimitExceededException] for 429 responses
  /// Throws [ApiError] for structured error handling
  String _handleError(DioException error) {
    // Handle network/connection errors first
    if (error.type == DioExceptionType.connectionTimeout) {
      throw ApiError(
        userMessage: 'Connection timed out.',
        suggestion: 'Please check your internet connection and try again.',
        type: ApiErrorType.timeout,
        technicalDetails: error.message,
      );
    }

    if (error.type == DioExceptionType.receiveTimeout) {
      throw ApiError(
        userMessage: 'Server is taking too long to respond.',
        suggestion: 'Please try again in a moment.',
        type: ApiErrorType.timeout,
        technicalDetails: error.message,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      throw ApiError(
        userMessage: 'Unable to connect to server.',
        suggestion: 'Please check your internet connection.',
        type: ApiErrorType.network,
        technicalDetails: error.message,
      );
    }

    if (error.type == DioExceptionType.sendTimeout) {
      throw ApiError(
        userMessage: 'Request timed out while sending data.',
        suggestion: 'Please check your connection and try again.',
        type: ApiErrorType.timeout,
        technicalDetails: error.message,
      );
    }

    // Handle HTTP response errors
    if (error.response != null) {
      final statusCode = error.response!.statusCode ?? 0;
      final data = error.response!.data;
      final serverMessage = _extractServerMessage(data);

      switch (statusCode) {
        case 400:
          throw ApiError(
            userMessage: serverMessage ?? 'Invalid request.',
            suggestion: 'Please check your input and try again.',
            statusCode: statusCode,
            type: ApiErrorType.unknown,
            technicalDetails: data?.toString(),
          );

        case 401:
          throw ApiError(
            userMessage: 'Your session has expired.',
            suggestion: 'Please sign in again to continue.',
            statusCode: statusCode,
            type: ApiErrorType.unauthorized,
            technicalDetails: serverMessage,
          );

        case 403:
          throw ApiError(
            userMessage: serverMessage ?? 'Access denied.',
            suggestion: 'You may need to upgrade your subscription.',
            statusCode: statusCode,
            type: ApiErrorType.forbidden,
            technicalDetails: data?.toString(),
          );

        case 404:
          throw ApiError(
            userMessage: serverMessage ?? 'The requested resource was not found.',
            suggestion: 'It may have been deleted or moved.',
            statusCode: statusCode,
            type: ApiErrorType.notFound,
            technicalDetails: data?.toString(),
          );

        case 409:
          throw ApiError(
            userMessage: serverMessage ?? 'A conflict occurred.',
            suggestion: 'Please refresh and try again.',
            statusCode: statusCode,
            type: ApiErrorType.conflict,
            technicalDetails: data?.toString(),
          );

        case 429:
          final retryAfter = _parseRetryAfter(error.response!);
          throw RateLimitExceededException(
            'Too many requests. Please wait before trying again.',
            retryAfter: retryAfter,
          );

        case 500:
          throw ApiError(
            userMessage: 'Something went wrong on our end.',
            suggestion: 'Please try again later. If the problem persists, contact support.',
            statusCode: statusCode,
            type: ApiErrorType.serverError,
            technicalDetails: serverMessage ?? data?.toString(),
          );

        case 502:
        case 503:
        case 504:
          throw ApiError(
            userMessage: 'Server is temporarily unavailable.',
            suggestion: 'Please try again in a few minutes.',
            statusCode: statusCode,
            type: ApiErrorType.maintenance,
            technicalDetails: serverMessage ?? 'Status: $statusCode',
          );

        default:
          throw ApiError(
            userMessage: serverMessage ?? 'An error occurred.',
            suggestion: 'Please try again.',
            statusCode: statusCode,
            type: ApiErrorType.unknown,
            technicalDetails: data?.toString(),
          );
      }
    }

    // Fallback for unknown errors
    throw ApiError(
      userMessage: 'An unexpected error occurred.',
      suggestion: 'Please try again later.',
      type: ApiErrorType.unknown,
      technicalDetails: error.message,
    );
  }

  /// Extract user-friendly message from server response
  String? _extractServerMessage(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      // Common error message fields in order of preference
      if (data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          // FastAPI validation errors
          final firstError = detail.first;
          if (firstError is Map && firstError.containsKey('msg')) {
            return firstError['msg'].toString();
          }
        }
      }
      if (data.containsKey('message')) return data['message'].toString();
      if (data.containsKey('error')) return data['error'].toString();
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return null;
  }

  /// Parse the Retry-After header from a 429 response
  Duration? _parseRetryAfter(Response response) {
    final retryAfterHeader = response.headers.value('retry-after');
    if (retryAfterHeader == null) return null;

    // Retry-After can be either seconds (integer) or HTTP-date
    final seconds = int.tryParse(retryAfterHeader);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }

    // Try to parse as HTTP-date (rare, but possible)
    try {
      final retryDate = HttpDate.parse(retryAfterHeader);
      final now = DateTime.now();
      if (retryDate.isAfter(now)) {
        return retryDate.difference(now);
      }
    } catch (_) {
      // Ignore parsing errors
    }

    // Default to 60 seconds if we can't parse the header
    return const Duration(seconds: 60);
  }

  /// Check if an error is a rate limit error
  static bool isRateLimitError(Object error) {
    return error is RateLimitExceededException ||
        (error is DioException && error.response?.statusCode == 429);
  }

  /// Check if an error is a network error (offline, timeout, etc.)
  static bool isNetworkError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError;
    }
    return false;
  }
}
