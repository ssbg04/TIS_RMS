import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/setup_models.dart';

class SetupRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  String _extractErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      final cleaned = data
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty && cleaned.length < 200) {
        return cleaned;
      }
    }
    return fallback;
  }

  // ==========================================
  // ACADEMIC YEARS
  // ==========================================
  Future<List<AcademicYearModel>> getAcademicYears() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/setup/academic-years',
        options: options,
      );
      return (response.data as List)
          .map(
            (item) => AcademicYearModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to fetch academic years.'));
    }
  }

  Future<void> createAcademicYear({
    required String yearRange,
    required String status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/setup/academic-years',
        options: options,
        data: {
          'yearRange': yearRange,
          'status': status,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to create academic year.'));
    }
  }

  Future<void> updateAcademicYear({
    required int id,
    required String yearRange,
    required String status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/setup/academic-years/$id',
        options: options,
        data: {
          'yearRange': yearRange,
          'status': status,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to update academic year.'));
    }
  }

  Future<Map<String, dynamic>> checkAutoGraduation() async {
    try {
      final options = await _getAuthOptions();
      final res = await _dio.post(
        '/setup/academic-years/check-auto-graduation',
        options: options,
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to check auto-graduation.'));
    }
  }

  Future<Map<String, dynamic>> checkAutoArchive() async {
    try {
      final options = await _getAuthOptions();
      final res = await _dio.post(
        '/setup/academic-years/check-auto-archive',
        options: options,
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to check auto-archive.'));
    }
  }

  Future<void> deleteAcademicYear(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/setup/academic-years/$id', options: options);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to delete academic year.'));
    }
  }

  // ==========================================
  // SECTIONS
  // ==========================================
  Future<List<SectionModel>> getAllSections() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/setup/sections', options: options);
      return (response.data as List)
          .map((item) => SectionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to fetch sections.'));
    }
  }

  Future<List<SectionModel>> getSectionsByYear(int yearId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/setup/academic-years/$yearId/sections',
        options: options,
      );
      return (response.data as List)
          .map((item) => SectionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        _extractErrorMessage(e, 'Failed to fetch sections for academic year.'),
      );
    }
  }

  Future<void> createSection({
    required String name,
    required int gradeLevel,
    required int academicYearId,
    int? teacherId,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/setup/sections',
        options: options,
        data: {
          'name': name,
          'gradeLevel': gradeLevel,
          'academicYearId': academicYearId,
          if (teacherId != null) 'teacherId': teacherId,
        },
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to create section.'));
    }
  }

  Future<Map<String, dynamic>> bulkCreateAcademicStructure(
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/setup/bulk-academic-structure',
        options: options,
        data: {'rows': rows},
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'message': response.data?.toString() ?? 'Bulk setup completed.'};
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to import academic structure.'));
    }
  }

  Future<void> updateSection({
    required int id,
    required String name,
    required int gradeLevel,
    required int academicYearId,
    int? teacherId,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/setup/sections/$id',
        options: options,
        data: {
          'name': name,
          'gradeLevel': gradeLevel,
          'academicYearId': academicYearId,
          'teacherId': teacherId,
        },
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to update section.'));
    }
  }

  Future<void> setSectionAdviser({
    required int sectionId,
    int? teacherId,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/setup/sections/$sectionId/adviser',
        options: options,
        data: {'teacherId': teacherId},
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to update section adviser.'));
    }
  }

  Future<void> deleteSection(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/setup/sections/$id', options: options);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to delete section.'));
    }
  }

  // ==========================================
  // GRADE LEVELS
  // ==========================================
  Future<List<GradeLevelModel>> getGradeLevels() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/setup/grade-levels', options: options);
      return (response.data as List)
          .map((item) => GradeLevelModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to fetch grade levels.'));
    }
  }

  Future<void> createGradeLevel({
    required int level,
    required String name,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/setup/grade-levels',
        options: options,
        data: {'level': level, 'name': name},
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to create grade level.'));
    }
  }

  Future<void> updateGradeLevel({
    required int id,
    required int level,
    required String name,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/setup/grade-levels/$id',
        options: options,
        data: {'level': level, 'name': name},
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to update grade level.'));
    }
  }

  Future<void> deleteGradeLevel(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/setup/grade-levels/$id', options: options);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to delete grade level.'));
    }
  }

  // ==========================================
  // TEACHER SECTIONS
  // ==========================================
  Future<List<SectionModel>> getTeacherSections(int teacherId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/users/$teacherId/sections',
        options: options,
      );
      return (response.data as List)
          .map((item) => SectionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to fetch teacher sections.'));
    }
  }

  Future<void> updateTeacherSections({
    required int teacherId,
    required List<int> sectionIds,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/users/$teacherId/sections',
        options: options,
        data: {'sectionIds': sectionIds},
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Failed to update teacher sections.'));
    }
  }
}
