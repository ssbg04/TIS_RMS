import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';

class SettingsRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, String>> getSettings() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/settings', options: options);
      final data = response.data;
      if (data != null && data['data'] != null) {
        final map = data['data'] as Map<String, dynamic>;
        return map.map((key, value) => MapEntry(key, value.toString()));
      }
      return {'auto_update_enrollment_from_sf': 'true'};
    } catch (e) {
      return {'auto_update_enrollment_from_sf': 'true'};
    }
  }

  Future<Map<String, String>> updateSettings(Map<String, String> updates) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.put(
        '/settings',
        data: {'settings': updates},
        options: options,
      );
      final data = response.data;
      if (data != null && data['data'] != null) {
        final map = data['data'] as Map<String, dynamic>;
        return map.map((key, value) => MapEntry(key, value.toString()));
      }
      return updates;
    } catch (e) {
      rethrow;
    }
  }
}
