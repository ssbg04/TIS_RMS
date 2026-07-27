import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/connected_user_model.dart';

class ConnectedUsersRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> sendHeartbeat({
    required String username,
    required String role,
    required String platform,
    String? ip,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/server/heartbeat',
        options: options,
        data: {
          'username': username,
          'role': role,
          'platform': platform,
          'ip': ip,
        },
      );
    } catch (_) {
      // Ignore heartbeat network errors silently so UI is undisturbed
    }
  }

  Future<void> sendLogout({required String username}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/server/logout',
        options: options,
        data: {'username': username},
      );
    } catch (_) {
      // Ignore logout network errors silently
    }
  }

  Future<List<ConnectedUserModel>> getConnectedUsers() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/server/connected-users',
        options: options,
      );
      return (response.data as List)
          .map((u) => ConnectedUserModel.fromJson(u))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch connected users.',
      );
    }
  }
}
