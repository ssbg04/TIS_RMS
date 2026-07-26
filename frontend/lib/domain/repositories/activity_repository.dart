import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/dashboard_models.dart';

/// Repository for paginated user history (admin-only).
class ActivityRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<PaginatedUserHistory> getUserHistory({
    int page = 1,
    int limit = 20,
    String? dateFrom,
    String? dateTo,
    String? action,
    String? role,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/users/history',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
          if (action != null && action.isNotEmpty) 'action': action,
          if (role != null && role.isNotEmpty) 'role': role,
        },
        options: options,
      );
      return PaginatedUserHistory.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch user history.',
      );
    }
  }
}
