import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/dashboard_models.dart';

class DashboardRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<DashboardStats> getStats() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/dashboard/stats', options: options);
      return DashboardStats.fromJson(response.data);
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to fetch stats.';
      throw Exception(errorMessage);
    }
  }

  Future<List<PendingTask>> getPendingTasks() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/dashboard/pending-tasks', options: options);
      
      if (response.data is List) {
        return (response.data as List).map((task) => PendingTask.fromJson(task)).toList();
      }
      return [];
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Failed to fetch pending tasks.';
      throw Exception(errorMessage);
    }
  }
}
