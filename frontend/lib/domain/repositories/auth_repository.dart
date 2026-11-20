import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_model.dart';
import '../../core/network/api_constants.dart';

class TwoFactorChallenge {
  final String challengeToken;
  final String method; // 'totp' | 'email'
  final String? maskedEmail;
  final String username;
  final bool rememberMe;

  const TwoFactorChallenge({
    required this.challengeToken,
    required this.method,
    this.maskedEmail,
    required this.username,
    this.rememberMe = false,
  });
}

class LoginOutcome {
  final UserModel? user;
  final TwoFactorChallenge? twoFactorChallenge;

  const LoginOutcome({this.user, this.twoFactorChallenge});

  bool get requiresTwoFactor => twoFactorChallenge != null;
}

class AuthRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'jwt_token';
  static const _rememberMeKey = 'remember_me';

  Future<UserModel> _persistAuthResponse(
    Map data, {
    required bool rememberMe,
  }) async {
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Server did not return an authentication token.');
    }

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _rememberMeKey,
      value: rememberMe ? 'true' : 'false',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    final userData = data['user'] as Map?;
    if (userData == null) {
      throw Exception('Server did not return user details.');
    }

    return UserModel(
      id: userData['id'],
      username: userData['username'],
      firstName: userData['firstName'],
      lastName: userData['lastName'],
      role: userData['role'],
    );
  }

  Future<LoginOutcome> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'platform': ApiConstants.clientPlatform,
          'device_name': ApiConstants.clientDeviceName,
          'remember_me': rememberMe,
        },
      );

      if (response.data is! Map) {
        throw Exception(
          'Server at ${ApiConstants.baseUrl} returned an unexpected response format. Please verify the server URL.',
        );
      }

      final data = response.data as Map;
      if (data['requiresTwoFactor'] == true) {
        final challengeToken = data['challengeToken'] as String? ?? '';
        if (challengeToken.isEmpty) {
          throw Exception('Server did not return a 2FA challenge token.');
        }
        return LoginOutcome(
          twoFactorChallenge: TwoFactorChallenge(
            challengeToken: challengeToken,
            method: (data['method'] as String?) ?? 'totp',
            maskedEmail: data['maskedEmail'] as String?,
            username: (data['username'] as String?) ?? username,
            rememberMe: rememberMe,
          ),
        );
      }

      final user = await _persistAuthResponse(data, rememberMe: rememberMe);
      return LoginOutcome(user: user);
    } on DioException catch (e) {
      final errorMessage = ApiConstants.extractErrorMessage(
        e,
        'Failed to connect to the server at ${ApiConstants.baseUrl}.',
      );
      throw Exception(errorMessage);
    } catch (e) {
      if (e is FormatException) {
        throw Exception(
          'Server at ${ApiConstants.baseUrl} returned non-JSON response. Please verify the server URL.',
        );
      }
      throw Exception(ApiConstants.extractErrorMessage(e));
    }
  }

  /// Sign in using token-based biometrics (no username/password needed)
  Future<UserModel> loginWithBiometrics(String biometricToken) async {
    try {
      final response = await _dio.post(
        '/auth/biometric/login',
        data: {
          'token': biometricToken,
          'platform': ApiConstants.clientPlatform,
          'device_name': ApiConstants.clientDeviceName,
          'device_id': ApiConstants.clientDeviceId,
        },
      );

      if (response.data is! Map) {
        throw Exception('Server returned an unexpected response format.');
      }

      final data = response.data as Map;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Server did not return an authentication token.');
      }

      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _rememberMeKey, value: 'true');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      final userData = data['user'] as Map?;
      if (userData == null) {
        throw Exception('Server did not return user details.');
      }

      return UserModel(
        id: userData['id'],
        username: userData['username'],
        firstName: userData['firstName'],
        lastName: userData['lastName'],
        role: userData['role'],
      );
    } on DioException catch (e) {
      final errorMessage = ApiConstants.extractErrorMessage(
        e,
        'Biometric sign-in failed. Please try again or use your password.',
      );
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(ApiConstants.extractErrorMessage(e));
    }
  }

  /// Registers this device for token-based biometric sign-in
  Future<String> registerBiometrics() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final response = await _dio.post(
        '/auth/biometric/register',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'platform': ApiConstants.clientPlatform,
          'device_name': ApiConstants.clientDeviceName,
          'device_id': ApiConstants.clientDeviceId,
        },
      );
      final data = response.data as Map;
      final bioToken = data['token'] as String?;
      if (bioToken == null || bioToken.isEmpty) {
        throw Exception('Server failed to issue biometric token.');
      }
      return bioToken;
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Failed to register biometric sign-in.'),
      );
    } catch (e) {
      throw Exception(ApiConstants.extractErrorMessage(e));
    }
  }

  /// Disables biometric sign-in on server for this device
  Future<void> disableBiometrics({String? token}) async {
    try {
      final jwt = await _storage.read(key: _tokenKey);
      await _dio.post(
        '/auth/biometric/disable',
        options: Options(headers: {'Authorization': 'Bearer $jwt'}),
        data: {
          'token': ?token,
          'platform': ApiConstants.clientPlatform,
          'device_name': ApiConstants.clientDeviceName,
          'device_id': ApiConstants.clientDeviceId,
        },
      );
    } catch (_) {}
  }

  /// Auto-login: returns user if a valid Remember Me token is stored, otherwise null.
  Future<UserModel?> tryAutoLogin() async {
    String? rememberMe;
    try {
      rememberMe = await _storage
          .read(key: _rememberMeKey)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (_) {}

    if (rememberMe != 'true') {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('rememberMe') == true) {
          rememberMe = 'true';
        }
      } catch (_) {}
    }
    if (rememberMe != 'true') return null;

    String? token;
    try {
      token = await _storage
          .read(key: _tokenKey)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (_) {}

    if (token == null || token.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(_tokenKey);
      } catch (_) {}
    }
    if (token == null || token.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      final options = Options(
        headers: {'Authorization': 'Bearer $token'},
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      );
      final response = await _dio
          .get('/auth/profile', options: options)
          .timeout(const Duration(seconds: 6));
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        // Token is actually invalid/expired — clear stored session
        await logout();
      }
      // For network errors (no internet on startup), return null without wiping token
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getToken() async {
    try {
      final token = await _storage
          .read(key: _tokenKey)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
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
          ApiConstants.extractErrorMessage(e, 'Failed to fetch profile.');
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
          ApiConstants.extractErrorMessage(e, 'Failed to update profile.');
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
          ApiConstants.extractErrorMessage(e, 'Failed to change password.');
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
          ApiConstants.extractErrorMessage(e, 'Failed to submit request.');
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
          ApiConstants.extractErrorMessage(e, 'Failed to lookup account.');
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
          ApiConstants.extractErrorMessage(e, 'Failed to send email verification code.');
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
          ApiConstants.extractErrorMessage(e, 'Failed to reset password.');
      throw Exception(errorMessage);
    }
  }

  /// Request account self-deletion email link
  Future<String> requestAccountDeletion() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/auth/request-delete-account',
        options: options,
      );
      return response.data['message'] as String? ??
          'Verification email sent. Please check your inbox.';
    } on DioException catch (e) {
      final errorMessage =
          ApiConstants.extractErrorMessage(e, 'Failed to request account deletion.');
      throw Exception(errorMessage);
    }
  }

  /// Immediately deactivate own account (no email required — 2-step client confirmation)
  Future<String> requestSelfDeactivation() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/auth/self-deactivate',
        options: options,
      );
      return response.data['message'] as String? ??
          'Your account has been deactivated.';
    } on DioException catch (e) {
      final errorMessage =
          ApiConstants.extractErrorMessage(e, 'Failed to deactivate account.');
      throw Exception(errorMessage);
    }
  }

  /// Notify server of logout (stamps logout_at + removes session), then clears local token.
  Future<void> logoutWithServer() async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/auth/logout', options: options);
    } catch (_) {
      // Fire-and-forget: always clear local token regardless
    }
    await logout();
  }

  // ── Session Management ──────────────────────────────────────────────────────

  /// List all active sessions for the current user (logged-in devices).
  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/auth/sessions', options: options);
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (e) {
      throw Exception(ApiConstants.extractErrorMessage(e, 'Failed to fetch sessions.'));
    }
  }

  /// Revoke a specific session by ID.
  Future<void> revokeSession(int sessionId) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/auth/sessions/$sessionId', options: options);
    } on DioException catch (e) {
      throw Exception(ApiConstants.extractErrorMessage(e, 'Failed to revoke session.'));
    }
  }

  /// Revoke all other sessions (keep current).
  Future<void> revokeAllOtherSessions() async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/auth/sessions', options: options);
    } on DioException catch (e) {
      throw Exception(ApiConstants.extractErrorMessage(e, 'Failed to revoke sessions.'));
    }
  }

  // ── Login / Logout Log ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLoginLogs({
    int page = 1,
    int limit = 20,
    String? search,
    String? dateFrom,
    String? dateTo,
    int? userId,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/auth/login-logs',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
          if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
          'user_id': ?userId,
        },
        options: options,
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(ApiConstants.extractErrorMessage(e, 'Failed to fetch login logs.'));
    }
  }

  // ── Two-Factor Authentication (2FA) ─────────────────────────────────────────

  Future<UserModel> verifyTwoFactorLogin({
    required String challengeToken,
    required String code,
    bool isBackupCode = false,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/2fa/verify-login',
        data: {
          'challengeToken': challengeToken,
          'code': code,
          'isBackupCode': isBackupCode,
          'platform': ApiConstants.clientPlatform,
          'device_name': ApiConstants.clientDeviceName,
        },
      );
      if (response.data is! Map) {
        throw Exception('Server returned an unexpected response format.');
      }
      return await _persistAuthResponse(
        response.data as Map,
        rememberMe: rememberMe,
      );
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Two-factor verification failed.'),
      );
    }
  }

  Future<String> resendTwoFactorLoginOtp(String challengeToken) async {
    try {
      final response = await _dio.post(
        '/auth/2fa/resend-login-otp',
        data: {'challengeToken': challengeToken},
      );
      return (response.data?['message'] as String?) ??
          'Verification code resent.';
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Failed to resend verification code.'),
      );
    }
  }

  Future<Map<String, dynamic>> getTwoFactorStatus() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/auth/2fa/status', options: options);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Failed to fetch 2FA status.'),
      );
    }
  }

  Future<Map<String, dynamic>> setupTotp() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post('/auth/2fa/totp/setup', options: options);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Failed to start authenticator setup.'),
      );
    }
  }

  Future<List<String>> confirmTotp(String code) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/auth/2fa/totp/confirm',
        data: {'code': code},
        options: options,
      );
      return List<String>.from(response.data['backupCodes'] as List);
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Invalid verification code.'),
      );
    }
  }

  Future<String?> setupEmailTwoFactor() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/auth/2fa/email/setup',
        options: options,
      );
      return response.data['maskedEmail'] as String?;
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Failed to send verification code.'),
      );
    }
  }

  Future<List<String>> confirmEmailTwoFactor(String code) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/auth/2fa/email/confirm',
        data: {'code': code},
        options: options,
      );
      return List<String>.from(response.data['backupCodes'] as List);
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Invalid verification code.'),
      );
    }
  }

  Future<List<String>> regenerateTwoFactorBackupCodes(String password) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/auth/2fa/backup-codes/regenerate',
        data: {'password': password},
        options: options,
      );
      return List<String>.from(response.data['backupCodes'] as List);
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Failed to regenerate backup codes.'),
      );
    }
  }

  Future<void> disableTwoFactor(String password) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/auth/2fa/disable',
        data: {'password': password},
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(
        ApiConstants.extractErrorMessage(e, 'Failed to disable 2FA.'),
      );
    }
  }
}
