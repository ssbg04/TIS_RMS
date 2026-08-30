import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_model.dart';
import '../../core/network/api_constants.dart';

class AuthRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'jwt_token';
  static const _rememberMeKey = 'remember_me';

  Future<UserModel> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );

      final token = response.data['token'] as String;
      // Write to FlutterSecureStorage — consistent with all other repositories
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(
        key: _rememberMeKey,
        value: rememberMe ? 'true' : 'false',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      final userData = response.data['user'];
      return UserModel(
        id: userData['id'],
        username: userData['username'],
        firstName: userData['firstName'],
        lastName: userData['lastName'],
        role: userData['role'],
      );
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to connect to the server.';
      throw Exception(errorMessage);
    }
  }

  /// Auto-login: returns user if a valid Remember Me token is stored, otherwise null.
  Future<UserModel?> tryAutoLogin() async {
    String? rememberMe = await _storage.read(key: _rememberMeKey);
    if (rememberMe != 'true') {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('rememberMe') == true) {
        rememberMe = 'true';
      }
    }
    if (rememberMe != 'true') return null;

    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      final options = Options(headers: {'Authorization': 'Bearer $token'});
      final response = await _dio.get('/auth/profile', options: options);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        // Token is actually invalid/expired — clear stored session
        await logout();
      }
      // For network errors (no internet on startup), return null without wiping token
      return null;
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _rememberMeKey);
    final prefs = await SharedPreferences.getInstance();
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
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to fetch profile.';
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
      await _dio.put(
        '/auth/profile',
        options: options,
        data: {
          'firstName': firstName,
          'middleName': middleName,
          'lastName': lastName,
          'extension': extension,
          'phone': phone,
          'email': email,
        },
      );
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to update profile.';
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
      await _dio.put(
        '/auth/change-password',
        options: options,
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to change password.';
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
      await _dio.post(
        '/auth/forgot-password',
        data: {
          'username': username,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to submit request.';
      throw Exception(errorMessage);
    }
  }

  /// Verify current user's password
  Future<bool> verifyPassword(String password) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/auth/verify-password',
        options: options,
        data: {'password': password},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Self-Service OTP Password Reset ────────────────────────────────────────

  /// Lookup user contact methods (masked email & phone) for password reset
  Future<Map<String, dynamic>> lookupResetOptions(String username) async {
    try {
      final response = await _dio.post(
        '/auth/lookup-reset-options',
        data: {'username': username},
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to lookup account.';
      throw Exception(errorMessage);
    }
  }

  /// Request 6-digit OTP sent to registered email
  Future<String> sendEmailOtp(String username) async {
    try {
      final response = await _dio.post(
        '/auth/send-email-otp',
        data: {'username': username},
      );
      return response.data['message'] as String? ??
          'Verification code sent to your email.';
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to send email verification code.';
      throw Exception(errorMessage);
    }
  }

  /// Reset password using 6-digit Email OTP
  Future<String> resetPasswordEmailOtp({
    required String username,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/reset-password-email-otp',
        data: {
          'username': username,
          'otp': otp,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
      return response.data['message'] as String? ??
          'Password reset successfully.';
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Failed to reset password.';
      throw Exception(errorMessage);
    }
  }
}

