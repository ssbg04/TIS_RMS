import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_model.dart';
import '../../core/network/api_constants.dart';

class AuthRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  static const _tokenKey = 'jwt_token';
  static const _rememberMeKey = 'remember_me';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<UserModel> login(String username, String password, {bool rememberMe = false}) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      final token = response.data['token'] as String;
      final prefs = await _prefs;
      await prefs.setString(_tokenKey, token);
      await prefs.setBool(_rememberMeKey, rememberMe);

      final userData = response.data['user'];
      return UserModel(
        id: userData['id'],
        username: userData['username'],
        firstName: userData['firstName'],
        lastName: userData['lastName'],
        role: userData['role'],
      );
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to connect to the server.';
      throw Exception(errorMessage);
    }
  }

  /// Auto-login: returns user if a valid Remember Me token is stored, otherwise null.
  Future<UserModel?> tryAutoLogin() async {
    final prefs = await _prefs;
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    if (!rememberMe) return null;

    final token = prefs.getString(_tokenKey);
    if (token == null) return null;

    try {
      final options = Options(headers: {'Authorization': 'Bearer $token'});
      final response = await _dio.get('/auth/profile', options: options);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        // Token is actually invalid/expired — clear stored session
        await logout();
      }
      // For network errors (like no internet on startup), we just return null 
      // to fallback to login, but we DON'T wipe the token so it can work next time.
      return null;
    }
  }

  Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_rememberMeKey);
  }

  Future<Options> _getAuthOptions() async {
    final token = await getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<UserModel> getProfile() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/auth/profile', options: options);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to fetch profile.';
      throw Exception(errorMessage);
    }
  }

  Future<void> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    String? extension,
    String? phone,
    String? email,
    required String currentPassword,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/auth/profile', options: options, data: {
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'extension': extension,
        'phone': phone,
        'email': email,
        'currentPassword': currentPassword,
      });
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to update profile.';
      throw Exception(errorMessage);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/auth/change-password', options: options, data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      });
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to change password.';
      throw Exception(errorMessage);
    }
  }

  /// Submits a forgot-password request (Admin/Teacher only, no auth required).
  Future<void> requestPasswordReset({
    required String username,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _dio.post('/auth/forgot-password', data: {
        'username': username,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      });
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to submit request.';
      throw Exception(errorMessage);
    }
  }

  /// Super Admin: get pending password reset requests.
  Future<List<Map<String, dynamic>>> getResetRequests() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/auth/reset-requests', options: options);
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to fetch requests.';
      throw Exception(errorMessage);
    }
  }

  /// Super Admin: approve a password reset request.
  Future<void> approveResetRequest(int requestId) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/auth/reset-requests/$requestId/approve', options: options);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to approve.';
      throw Exception(errorMessage);
    }
  }

  /// Super Admin: reject a password reset request.
  Future<void> rejectResetRequest(int requestId) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/auth/reset-requests/$requestId/reject', options: options);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to reject.';
      throw Exception(errorMessage);
    }
  }

  /// Verify current user's password
  Future<bool> verifyPassword(String password) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/auth/verify-password', options: options, data: {
        'password': password,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}