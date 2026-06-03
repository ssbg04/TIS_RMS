import 'package:dio/dio.dart';
import 'dart:async';  
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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

  IO.Socket? _socket;
  final StreamController<void> _studentUpdateController = StreamController.broadcast();

  Stream<void> get onStudentChanged => _studentUpdateController.stream;

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ----------------------------------------------------------------
  // Initialize WebSocket for Real-Time LAN Sync
  // ----------------------------------------------------------------
  void _initRealTimeSocket() async {
    final token = await _storage.read(key: 'jwt_token');

    // Assumes your ApiConstants.baseUrl looks like 'http://192.168.1.10:3000/api'
    // Sockets usually connect to the root domain 'http://192.168.1.10:3000'
    final socketUrl = ApiConstants.baseUrl.replaceAll('/api', '');

    _socket = IO.io(socketUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token}) // Pass token for secure backend verification
        .disableAutoConnect()
        .build()
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      print('Real-time sync connected to LAN server');
    });

    // Listen for database changes broadcasted by the Node.js server
    _socket?.on('student_added', (_) => _studentUpdateController.add(null));
    _socket?.on('student_updated', (_) => _studentUpdateController.add(null));
    _socket?.on('student_deleted', (_) => _studentUpdateController.add(null));
  }

  void dispose() {  
    _socket?.dispose();
    _studentUpdateController.close();
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
    String section    = '',
    String schoolYear = '',
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/students',
        queryParameters: {
          if (search.trim().isNotEmpty)     'search':     search.trim(),
          if (gradeLevel.trim().isNotEmpty) 'gradeLevel': gradeLevel.trim(),
          if (status.trim().isNotEmpty)     'status':     status.trim(),
          if (section.trim().isNotEmpty)    'section':    section.trim(),
          if (schoolYear.trim().isNotEmpty) 'schoolYear': schoolYear.trim(),
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
    required int academicYearId,
    required int gradeLevel,
    required int sectionId,
    String? trackStrand,
  }) async {
    try {
      final options  = await _getAuthOptions();
      final response = await _dio.post(
        '/students',
        data: {
          'lrn':            lrn.trim(),
          'firstName':      firstName.trim(),
          'middleName':     middleName?.trim(),
          'lastName':       lastName.trim(),
          'extension':      extension?.trim(),
          'sex':            sex,
          'birthDate':      '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
          'academicYearId': academicYearId,
          'gradeLevel':     gradeLevel,
          'sectionId':      sectionId,
          'trackStrand':    trackStrand,
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
    required int academicYearId,
    required int gradeLevel,
    required int sectionId,
    String? trackStrand,
    String          status = 'Enrolled',
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/students/$id',
        data: {
          'lrn':            lrn.trim(),
          'firstName':      firstName.trim(),
          'middleName':     middleName?.trim(),
          'lastName':       lastName.trim(),
          'extension':      extension?.trim(),
          'sex':            sex,
          'birthDate':      '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
          'status':         status,
          'academicYearId': academicYearId,
          'gradeLevel':     gradeLevel,
          'sectionId':      sectionId,
          'trackStrand':    trackStrand,
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

  // ----------------------------------------------------------------
  // Bulk Enroll Students
  // ----------------------------------------------------------------
  Future<void> bulkEnroll({
    required List<int> studentIds,
    required int academicYearId,
    required int gradeLevel,
    required int sectionId,
    String? trackStrand,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/students/bulk-enroll',
        data: {
          'studentIds':     studentIds,
          'academicYearId': academicYearId,
          'gradeLevel':     gradeLevel,
          'sectionId':      sectionId,
          'trackStrand':    trackStrand,
        },
        options: options,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to bulk enroll students.';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------------------
  // Bulk Graduate Students
  // ----------------------------------------------------------------
  Future<void> bulkGraduate(List<int> studentIds) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/students/bulk-graduate',
        data: {'studentIds': studentIds},
        options: options,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to bulk graduate students.';
      throw Exception(msg);
    }
  }
}
