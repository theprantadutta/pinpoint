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
  // Use same base URL as regular API - prod in release mode, dev otherwise
  static final String baseUrl = kReleaseMode
      ? dotenv.env['API_BASE_URL_PROD']!
      : dotenv.env['API_BASE_URL_DEV']!;
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
          debugPrint(
              '[AdminAPI] ERROR[${error.response?.statusCode}] => ${error.message}');
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
      debugPrint(
          '[AdminAPI] Password (first 3 chars): ${password.substring(0, password.length > 3 ? 3 : password.length)}...');
      debugPrint(
          '[AdminAPI] Password (last 3 chars): ...${password.substring(password.length > 3 ? password.length - 3 : 0)}');

      final response = await _dio.post(
        '/admin/auth',
        data: {
          'email': email,
          'password': password,
        },
      );

      _adminToken = response.data['access_token'];
      debugPrint(
          '[AdminAPI] Login successful, token expires in ${response.data['expires_in']}s');

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
  Future<Map<String, dynamic>> getUserSyncEvents(String userId,
      {int limit = 50}) async {
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
  Future<Map<String, dynamic>> getUserSubscriptionEvents(String userId,
      {int limit = 20}) async {
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

  // ========== Job Management API ==========

  /// Get all scheduled jobs
  ///
  /// Returns list of jobs with status and next run time
  Future<Map<String, dynamic>> getJobs() async {
    try {
      final response = await _dio.get(
        '/admin/jobs',
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Get detailed information about a specific job
  ///
  /// Returns job details with statistics
  Future<Map<String, dynamic>> getJobDetails(String jobId) async {
    try {
      final response = await _dio.get(
        '/admin/jobs/$jobId',
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Get job run history with pagination
  ///
  /// Returns paginated list of job runs
  Future<Map<String, dynamic>> getJobHistory(
    String jobId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/admin/jobs/$jobId/history',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
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

  /// Manually trigger a job
  ///
  /// Returns run ID and status
  Future<Map<String, dynamic>> triggerJob(String jobId) async {
    try {
      final response = await _dio.post(
        '/admin/jobs/$jobId/trigger',
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Pause a scheduled job
  Future<Map<String, dynamic>> pauseJob(String jobId) async {
    try {
      final response = await _dio.post(
        '/admin/jobs/$jobId/pause',
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  /// Resume a paused job
  Future<Map<String, dynamic>> resumeJob(String jobId) async {
    try {
      final response = await _dio.post(
        '/admin/jobs/$jobId/resume',
        options: Options(
          headers: {'Authorization': 'Bearer $_adminToken'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _handleError(e);
    }
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
    throw Exception(
        e.response?.data['detail'] ?? 'Request failed: ${e.message}');
  }
}
