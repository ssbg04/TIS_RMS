import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/report_models.dart';

class ReportRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<AcademicYear>> getAcademicYears() async {
    try {
      final res = await _dio.get(
        '/reports/academic-years',
        options: await _authOptions(),
      );
      return (res.data as List)
          .map((e) => AcademicYear.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch academic years.',
      );
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
      if (academicYearId != null) {
        queryParams['academicYearId'] = academicYearId;
      }
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
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch sections.',
      );
    }
  }

  Future<List<YearlyComparisonData>> getYearlyComparison() async {
    try {
      final res = await _dio.get(
        '/reports/yearly-comparison',
        options: await _authOptions(),
      );
      return (res.data as List)
          .map((e) => YearlyComparisonData.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch yearly comparison.',
      );
    }
  }

  Future<int> getStorageUsed() async {
    try {
      final res = await _dio.get(
        '/reports/storage',
        options: await _authOptions(),
      );
      return res.data['bytes'] as int;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch storage usage.',
      );
    }
  }

  Future<TransparencyBoardData> getTransparencyBoardData({
    int? academicYearId,
    List<int>? yearIds,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) queryParams['academicYearId'] = academicYearId;
      if (yearIds != null && yearIds.isNotEmpty) {
        queryParams['yearIds'] = yearIds.join(',');
      }

      final res = await _dio.get(
        '/reports/transparency-board',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: await _authOptions(),
      );
      return TransparencyBoardData.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ??
            'Failed to fetch transparency board data.',
      );
    }
  }

  Future<Uint8List> downloadTransparencyBoardPdf({
    int? academicYearId,
    List<int>? yearIds,
    String? schoolName,
    String? divisionName,
    String? regionName,
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) queryParams['academicYearId'] = academicYearId;
      if (yearIds != null && yearIds.isNotEmpty) {
        queryParams['yearIds'] = yearIds.join(',');
      }
      if (schoolName != null) queryParams['schoolName'] = schoolName;
      if (divisionName != null) queryParams['divisionName'] = divisionName;
      if (regionName != null) queryParams['regionName'] = regionName;
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }

      final options = await _authOptions();
      options.responseType = ResponseType.bytes;

      final res = await _dio.get<List<int>>(
        '/reports/transparency-board/pdf',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: options,
      );
      return Uint8List.fromList(res.data!);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ??
            'Failed to generate transparency board PDF.',
      );
    }
  }
}

