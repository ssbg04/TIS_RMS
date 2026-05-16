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

  Future<ReportStats> getStats({int? academicYearId}) async {
    try {
      final res = await _dio.get(
        '/reports/stats',
        queryParameters: academicYearId != null ? {'academicYearId': academicYearId} : null,
        options: await _authOptions(),
      );
      return ReportStats.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch stats.');
    }
  }

  Future<List<GradeEnrollment>> getEnrollmentByGrade({int? academicYearId}) async {
    try {
      final res = await _dio.get(
        '/reports/enrollment-by-grade',
        queryParameters: academicYearId != null ? {'academicYearId': academicYearId} : null,
        options: await _authOptions(),
      );
      return (res.data as List).map((e) => GradeEnrollment.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch enrollment data.');
    }
  }

  Future<DocumentStatus> getDocumentStatus() async {
    try {
      final res = await _dio.get('/reports/document-status', options: await _authOptions());
      return DocumentStatus.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch document status.');
    }
  }

  Future<ReportExportData> getExportData({int? academicYearId}) async {
    try {
      final res = await _dio.get(
        '/reports/export-data',
        queryParameters: academicYearId != null ? {'academicYearId': academicYearId} : null,
        options: await _authOptions(),
      );
      return ReportExportData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch export data.');
    }
  }
}
