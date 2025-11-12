import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Admin API Service for accessing admin panel endpoints
///
/// SECURITY: This service uses separate authentication from regular API
/// - Admin JWT tokens are stored in memory only (not persisted)
/// - Tokens expire after 1 hour
/// - All requests require admin JWT token
class AdminApiService {
  // Use same base URL as regular API
  static final String baseUrl = dotenv.env['API_BASE_URL']!;
  static const String apiV1 = '/api/v1';

  final Dio _dio = Dio();

  static final AdminApiService _instance = AdminApiService._internal();
  factory AdminApiService() => _instance;

  AdminApiService._internal() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl + apiV1,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Add logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('[AdminAPI] REQUEST[${options.method}] => ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('[AdminAPI] RESPONSE[${response.statusCode}]');
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint('[AdminAPI] ERROR[${error.response?.statusCode}] => ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }

  // Admin JWT token (stored in memory only, not persisted)
  String? _adminToken;

  /// Admin Authentication
  ///
  /// Verifies admin password and returns JWT token
  /// Rate limited to 5 attempts per minute
  Future<Map<String, dynamic>> adminLogin(String email, String password) async {
    try {
      // DEBUG: Log password details
      debugPrint('[AdminAPI] Login attempt with email: $email');
      debugPrint('[AdminAPI] Password length: ${password.length}');
      debugPrint('[AdminAPI] Password (first 3 chars): ${password.substring(0, password.length > 3 ? 3 : password.length)}...');
      debugPrint('[AdminAPI] Password (last 3 chars): ...${password.substring(password.length > 3 ? password.length - 3 : 0)}');

      final response = await _dio.post(
        '/admin/auth',
        data: {
          'email': email,
          'password': password,
        },
      );

      _adminToken = response.data['access_token'];
      debugPrint('[AdminAPI] Login successful, token expires in ${response.data['expires_in']}s');

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception('Too many login attempts. Please try again later.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Invalid admin credentials');
      }
      throw Exception(e.response?.data['detail'] ?? 'Admin login failed');
    }
  }

  /// Get all users with pagination
  ///
  /// Returns paginated list of users with basic information
  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await _dio.get(
        '/admin/users',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Get detailed information about a specific user
  ///
  /// Returns comprehensive user details including stats
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final response = await _dio.get(
        '/admin/users/$userId',
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Get user's notes with pagination
  ///
  /// WARNING: Returns encrypted note data
  Future<Map<String, dynamic>> getUserNotes(
    String userId, {
    int page = 1,
    int pageSize = 50,
    bool includeDeleted = false,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/users/$userId/notes',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          'include_deleted': includeDeleted,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Get user's encryption key
  ///
  /// CRITICAL: This is EXTREMELY SENSITIVE data
  Future<Map<String, dynamic>> getUserEncryptionKey(String userId) async {
    try {
      final response = await _dio.get(
        '/admin/users/$userId/encryption-key',
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Get user's sync event history
  ///
  /// Useful for debugging sync issues
  Future<Map<String, dynamic>> getUserSyncEvents(String userId, {int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/admin/users/$userId/sync-events',
        queryParameters: {'limit': limit},
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Get user's subscription event history
  Future<Map<String, dynamic>> getUserSubscriptionEvents(String userId, {int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/admin/users/$userId/subscription-events',
        queryParameters: {'limit': limit},
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Check if admin is authenticated
  bool get isAuthenticated => _adminToken != null;

  /// Logout (clear admin token from memory)
  void logout() {
    _adminToken = null;
    debugPrint('[AdminAPI] Logged out');
  }

  /// Handle DioException errors
  Never _handleError(DioException e) {
    if (e.response?.statusCode == 401) {
      _adminToken = null; // Clear invalid token
      throw Exception('Admin session expired. Please login again.');
    } else if (e.response?.statusCode == 403) {
      throw Exception('Access denied');
    } else if (e.response?.statusCode == 404) {
      throw Exception('Resource not found');
    }
    throw Exception(e.response?.data['detail'] ?? 'Request failed: ${e.message}');
  }
}
