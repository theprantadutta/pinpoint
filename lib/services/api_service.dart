import 'package:dio/dio.dart';
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

class ApiService {
  // Backend API configuration
  static final String baseUrl = dotenv.env['API_BASE_URL']!;
  static const String apiV1 = '/api/v1';

  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

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
        onError: (error, handler) {
          _logger.e('ERROR[${error.response?.statusCode}] => ${error.message}');
          if (error.response != null) {
            _logger.e('ERROR Response Data: ${error.response?.data}');
            _logger.e('ERROR Response Headers: ${error.response?.headers}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  // ============================================================================
  // Token Management
  // ============================================================================

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
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

      // Save token
      final token = response.data['access_token'];
      await saveToken(token);

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

      // Save token
      final token = response.data['access_token'];
      await saveToken(token);

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
      await deleteToken();
    }
  }

  /// Authenticate with Firebase token (Google Sign-In)
  Future<Map<String, dynamic>> authenticateWithFirebase(
      String firebaseToken) async {
    try {
      _logger.i('🔐 Authenticating with Firebase token...');
      _logger.d('Firebase token (first 50 chars): ${firebaseToken.substring(0, firebaseToken.length > 50 ? 50 : firebaseToken.length)}...');

      final response = await _dio.post(
        '/auth/firebase',
        data: {
          'firebase_token': firebaseToken,
        },
      );

      _logger.i('✅ Firebase authentication successful');

      // Save token
      final token = response.data['access_token'];
      await saveToken(token);

      return response.data;
    } on DioException catch (e) {
      _logger.e('❌ Firebase authentication failed with status: ${e.response?.statusCode}');
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
    required List<int> clientNoteIds,
    bool hardDelete = false,
  }) async {
    try {
      final response = await _dio.delete(
        '/notes/notes',
        queryParameters: {'hard_delete': hardDelete},
        data: {'client_note_ids': clientNoteIds},
      );

      return response.data;
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
  Future<Map<String, dynamic>> verifyPurchaseWithDevice({
    required String deviceId,
    required String purchaseToken,
    required String productId,
  }) async {
    try {
      final response = await _dio.post(
        '/subscription/verify-device',
        data: {
          'device_id': deviceId,
          'purchase_token': purchaseToken,
          'product_id': productId,
        },
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

  // ============================================================================
  // Error Handling
  // ============================================================================

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'Error: ${error.response!.statusMessage}';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Please check your internet connection.';
    }

    return 'An unexpected error occurred: ${error.message}';
  }
}
