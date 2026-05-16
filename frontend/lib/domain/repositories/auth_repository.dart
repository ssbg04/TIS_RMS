import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user_model.dart';
import '../../core/network/api_constants.dart';

class AuthRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'jwt_token';
  static const _rememberMeKey = 'remember_me';

  Future<UserModel> login(String username, String password, {bool rememberMe = false}) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      final token = response.data['token'] as String;
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _rememberMeKey, value: rememberMe ? 'true' : 'false');

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
    final rememberMe = await _storage.read(key: _rememberMeKey);
    if (rememberMe != 'true') return null;

    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;

    try {
      final options = Options(headers: {'Authorization': 'Bearer $token'});
      final response = await _dio.get('/auth/profile', options: options);
      return UserModel.fromJson(response.data);
    } on DioException {
      // Token is invalid/expired — clear stored session
      await logout();
      return null;
    }
  }

  Future<String?> getToken() async => await _storage.read(key: _tokenKey);

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _rememberMeKey);
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
}