import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/notification_model.dart';

class NotificationRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/notifications',
        options: options,
      );
      final list = response.data as List;
      return list.map((item) => NotificationModel.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch notifications.');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/notifications/mark-all-read',
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to mark all notifications as read.');
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/notifications/$id/read',
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to mark notification as read.');
    }
  }

  Future<void> clearNotifications() async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete(
        '/notifications/clear',
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to clear notifications.');
    }
  }
}
