import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/archive_model.dart';
import '../entities/folder_model.dart';
import 'document_repository.dart';

class ArchivePage {
  final List<ArchiveModel> archives;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ArchivePage({
    required this.archives,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory ArchivePage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return ArchivePage(
      archives: (json['archives'] as List)
          .map((a) => ArchiveModel.fromJson(a as Map<String, dynamic>))
          .toList(),
      total: (pagination['total'] as num).toInt(),
      page: (pagination['page'] as num).toInt(),
      limit: (pagination['limit'] as num).toInt(),
      totalPages: (pagination['totalPages'] as num).toInt(),
    );
  }
}

class ArchiveRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<ArchivePage> getArchives({
    String search = '',
    int page = 1,
    int limit = 10,
    String status = 'All Statuses',
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/archives',
        queryParameters: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status.trim().isNotEmpty) 'status': status.trim(),
          'page': page,
          'limit': limit,
        },
        options: options,
      );
      return ArchivePage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch archives.';
      throw Exception(msg);
    }
  }

  Future<void> restoreArchive(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/archives/$id/restore', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to restore archive.';
      throw Exception(msg);
    }
  }

  Future<void> purgeArchive(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/archives/$id', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to purge archive.';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------------------
  // New document-centric endpoints (for redesigned Archive screen)
  // ----------------------------------------------------------------

  Future<DocumentPage> getArchivedDocuments({
    String search = '',
    int page = 1,
    int limit = 20,
    String status = 'All Statuses',
    String documentType = 'All Types',
    String gradeLevel = '',
    String schoolYear = '',
    int? studentId,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/archives/documents',
        queryParameters: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status.trim().isNotEmpty && status != 'All Statuses') 'status': status.trim(),
          if (documentType.trim().isNotEmpty && documentType != 'All Types') 'documentType': documentType.trim(),
          if (gradeLevel.trim().isNotEmpty) 'gradeLevel': gradeLevel.trim(),
          if (schoolYear.trim().isNotEmpty) 'schoolYear': schoolYear.trim(),
          'studentId': ?studentId,
          'page': page,
          'limit': limit,
        },
        options: options,
      );
      return DocumentPage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch archived documents.';
      throw Exception(msg);
    }
  }

  Future<List<FolderModel>> getArchivedStudentFolders({
    String search = '',
    String status = 'All Statuses',
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/archives/student-folders',
        queryParameters: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status.trim().isNotEmpty && status != 'All Statuses') 'status': status.trim(),
        },
        options: options,
      );
      return (response.data as List)
          .map((f) => FolderModel.fromJson(f as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch archived student folders.';
      throw Exception(msg);
    }
  }
}
