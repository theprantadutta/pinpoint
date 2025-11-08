import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

class ApiService {
  // Backend API configuration
  static const String baseUrl = 'http://localhost:8000'; // Change to your production URL
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
  Future<Map<String, dynamic>> getSubscriptionStatusByDevice(String deviceId) async {
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
