import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/dashboard_models.dart';

class DashboardRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<DashboardStats> getStats() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/dashboard/stats', options: options);
      return DashboardStats.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch stats.');
    }
  }

  Future<PaginatedActivities> getRecentActivities({
    int page = 1,
    int limit = 10,
    String? dateFrom,
    String? dateTo,
    String? entityTypes, // Comma-separated, e.g. "student,document" for teacher view
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/dashboard/recent-activities',
        queryParameters: {
          'page':  page,
          'limit': limit,
          if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo   != null && dateTo.isNotEmpty)   'date_to':   dateTo,
          if (entityTypes != null && entityTypes.isNotEmpty) 'entity_types': entityTypes,
        },
        options: options,
      );
      return PaginatedActivities.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch activities.');
    }
  }
}
