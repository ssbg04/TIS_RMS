import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/setup_models.dart';

class SetupRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ==========================================
  // ACADEMIC YEARS
  // ==========================================
  Future<List<AcademicYearModel>> getAcademicYears() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/setup/academic-years', options: options);
      return (response.data as List)
          .map((item) => AcademicYearModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch academic years.');
    }
  }

  Future<void> createAcademicYear({required String yearRange, required String status}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/setup/academic-years', options: options, data: {
        'yearRange': yearRange,
        'status': status,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create academic year.');
    }
  }

  Future<void> updateAcademicYear({required int id, required String yearRange, required String status}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/setup/academic-years/$id', options: options, data: {
        'yearRange': yearRange,
        'status': status,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update academic year.');
    }
  }

  Future<void> deleteAcademicYear(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/setup/academic-years/$id', options: options);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete academic year.');
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
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch sections.');
    }
  }

  Future<List<SectionModel>> getSectionsByYear(int yearId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/setup/academic-years/$yearId/sections', options: options);
      return (response.data as List)
          .map((item) => SectionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch sections for academic year.');
    }
  }

  Future<void> createSection({required String name, required int gradeLevel, required int academicYearId}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/setup/sections', options: options, data: {
        'name': name,
        'gradeLevel': gradeLevel,
        'academicYearId': academicYearId,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create section.');
    }
  }

  Future<void> updateSection({required int id, required String name, required int gradeLevel, required int academicYearId}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/setup/sections/$id', options: options, data: {
        'name': name,
        'gradeLevel': gradeLevel,
        'academicYearId': academicYearId,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update section.');
    }
  }

  Future<void> deleteSection(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/setup/sections/$id', options: options);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete section.');
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
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch grade levels.');
    }
  }

  Future<void> createGradeLevel({required int level, required String name}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/setup/grade-levels', options: options, data: {
        'level': level,
        'name': name,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create grade level.');
    }
  }

  Future<void> updateGradeLevel({required int id, required int level, required String name}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/setup/grade-levels/$id', options: options, data: {
        'level': level,
        'name': name,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update grade level.');
    }
  }

  Future<void> deleteGradeLevel(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/setup/grade-levels/$id', options: options);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete grade level.');
    }
  }

  // ==========================================
  // TEACHER SECTIONS
  // ==========================================
  Future<List<SectionModel>> getTeacherSections(int teacherId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/users/$teacherId/sections', options: options);
      return (response.data as List)
          .map((item) => SectionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to fetch teacher sections.');
    }
  }

  Future<void> updateTeacherSections({required int teacherId, required List<int> sectionIds}) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/users/$teacherId/sections', options: options, data: {
        'sectionIds': sectionIds,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update teacher sections.');
    }
  }
}
