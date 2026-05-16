import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/student_model.dart';

/// Paginated student list returned from the API.
class StudentPage {
  final List<StudentModel> students;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const StudentPage({
    required this.students,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory StudentPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return StudentPage(
      students: (json['students'] as List)
          .map((s) => StudentModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      total:      (pagination['total']      as num).toInt(),
      page:       (pagination['page']       as num).toInt(),
      limit:      (pagination['limit']      as num).toInt(),
      totalPages: (pagination['totalPages'] as num).toInt(),
    );
  }
}

class StudentRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ----------------------------------------------------------------
  // Fetch paginated students with optional search + filters
  // ----------------------------------------------------------------
  Future<StudentPage> getStudents({
    String search     = '',
    int    page       = 1,
    int    limit      = 10,
    String gradeLevel = '',
    String status     = '',
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/students',
        queryParameters: {
          if (search.trim().isNotEmpty)     'search':     search.trim(),
          if (gradeLevel.trim().isNotEmpty) 'gradeLevel': gradeLevel.trim(),
          if (status.trim().isNotEmpty)     'status':     status.trim(),
          'page':  page,
          'limit': limit,
        },
        options: options,
      );
      return StudentPage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch students.';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------------------
  // Get single student by ID
  // ----------------------------------------------------------------
  Future<StudentModel> getStudentById(int id) async {
    try {
      final options  = await _getAuthOptions();
      final response = await _dio.get('/students/$id', options: options);
      return StudentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch student.';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------------------
  // Create student — returns the newly created ID
  // ----------------------------------------------------------------
  Future<int> createStudent({
    required String lrn,
    required String firstName,
    String?         middleName,
    required String lastName,
    String?         extension,
    required String sex,
    required DateTime birthDate,
  }) async {
    try {
      final options  = await _getAuthOptions();
      final response = await _dio.post(
        '/students',
        data: {
          'lrn':        lrn.trim(),
          'firstName':  firstName.trim(),
          'middleName': middleName?.trim(),
          'lastName':   lastName.trim(),
          'extension':  extension?.trim(),
          'sex':        sex,
          'birthDate':  '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        },
        options: options,
      );
      return (response.data['id'] as num).toInt();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to create student.';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------------------
  // Update student
  // ----------------------------------------------------------------
  Future<void> updateStudent({
    required int    id,
    required String lrn,
    required String firstName,
    String?         middleName,
    required String lastName,
    String?         extension,
    required String sex,
    required DateTime birthDate,
    String          status = 'Enrolled',
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/students/$id',
        data: {
          'lrn':        lrn.trim(),
          'firstName':  firstName.trim(),
          'middleName': middleName?.trim(),
          'lastName':   lastName.trim(),
          'extension':  extension?.trim(),
          'sex':        sex,
          'birthDate':  '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
          'status':     status,
        },
        options: options,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update student.';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------------------
  // Delete student
  // ----------------------------------------------------------------
  Future<void> deleteStudent(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/students/$id', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to delete student.';
      throw Exception(msg);
    }
  }
}
