import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/report_models.dart';

class ReportRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<AcademicYear>> getAcademicYears() async {
    try {
      final res = await _dio.get('/reports/academic-years', options: await _authOptions());
      return (res.data as List).map((e) => AcademicYear.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch academic years.');
    }
  }

  Future<ReportStats> getStats({
    int? academicYearId,
    int? gradeLevel,
    int? sectionId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) queryParams['academicYearId'] = academicYearId;
      if (gradeLevel != null) queryParams['gradeLevel'] = gradeLevel;
      if (sectionId != null) queryParams['sectionId'] = sectionId;
      if (status != null) queryParams['status'] = status;

      final res = await _dio.get(
        '/reports/stats',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: await _authOptions(),
      );
      return ReportStats.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch stats.');
    }
  }

  Future<List<Map<String, dynamic>>> getSections(int academicYearId) async {
    try {
      final res = await _dio.get(
        '/setup/academic-years/$academicYearId/sections',
        options: await _authOptions(),
      );
      return (res.data as List).map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch sections.');
    }
  }
  Future<List<YearlyComparisonData>> getYearlyComparison() async {
    try {
      final res = await _dio.get('/reports/yearly-comparison', options: await _authOptions());
      return (res.data as List).map((e) => YearlyComparisonData.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch yearly comparison.');
    }
  }
}
