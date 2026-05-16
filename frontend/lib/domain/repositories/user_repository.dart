import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/system_user.dart';

class UserRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<SystemUser>> getUsers() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/users', options: options);
      return (response.data as List).map((u) => SystemUser.fromJson(u)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch users.');
    }
  }

  /// Creates a user and returns the temporary plaintext password (shown once only).
  Future<String> createUser({
    required String username,
    String? password, // optional — backend auto-generates if omitted
    required String firstName,
    String? middleName,
    required String lastName,
    String? extension,
    required String role,
    String? email,
    String? phone,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post('/users', options: options, data: {
        'username': username,
        if (password != null && password.isNotEmpty) 'password': password,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'extension': extension,
        'role': role,
        'email': email,
        'phone': phone,
      });
      final tempPass = response.data['temporaryPassword'];
      if (tempPass == null) throw Exception('No temporary password in response.');
      return tempPass as String;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to create user.');
    }
  }

  Future<void> updateUser({
    required int id,
    required String firstName,
    String? middleName,
    required String lastName,
    String? extension,
    required String role,
    String? email,
    String? phone,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/users/$id', options: options, data: {
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'extension': extension,
        'role': role,
        'email': email,
        'phone': phone,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to update user.');
    }
  }

  Future<void> resetPassword(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/users/$id/reset-password', options: options);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to reset password.');
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/users/$id', options: options);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to delete user.');
    }
  }
}
