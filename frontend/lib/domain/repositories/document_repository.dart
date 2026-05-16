import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/document_model.dart';
import '../entities/document_requirement_model.dart';
import '../entities/folder_model.dart';

class DocumentPage {
  final List<DocumentModel> documents;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const DocumentPage({
    required this.documents,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return DocumentPage(
      documents: (json['documents'] as List)
          .map((d) => DocumentModel.fromJson(d as Map<String, dynamic>))
          .toList(),
      total: (pagination['total'] as num).toInt(),
      page: (pagination['page'] as num).toInt(),
      limit: (pagination['limit'] as num).toInt(),
      totalPages: (pagination['totalPages'] as num).toInt(),
    );
  }
}

class PrintQueueItem {
  final int queueId;
  final int documentId;
  final String fileName;
  final String filePath;
  final String? documentType;
  final String status;
  final String? studentName;
  final String? studentLrn;
  final DateTime addedAt;

  const PrintQueueItem({
    required this.queueId,
    required this.documentId,
    required this.fileName,
    required this.filePath,
    this.documentType,
    required this.status,
    this.studentName,
    this.studentLrn,
    required this.addedAt,
  });

  factory PrintQueueItem.fromJson(Map<String, dynamic> json) {
    return PrintQueueItem(
      queueId: json['queue_id'] as int,
      documentId: json['document_id'] as int,
      fileName: json['file_name'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      documentType: json['document_type'] as String?,
      status: json['status'] as String? ?? 'Pending',
      studentName: json['student_name'] as String?,
      studentLrn: json['student_lrn'] as String?,
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'] as String)
          : DateTime.now(),
    );
  }
}



class RequirementsSettings {
  final List<DocumentRequirementModel> jhs;
  final List<DocumentRequirementModel> shs;
  final List<String> documentTypes;

  RequirementsSettings({
    required this.jhs,
    required this.shs,
    required this.documentTypes,
  });

  factory RequirementsSettings.fromJson(Map<String, dynamic> json) {
    return RequirementsSettings(
      jhs: (json['jhs'] as List)
          .map((r) => DocumentRequirementModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      shs: (json['shs'] as List)
          .map((r) => DocumentRequirementModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      documentTypes: (json['documentTypes'] as List)
          .map((t) => t as String)
          .toList(),
    );
  }
}

class MissingRequirements {
  final String category;
  final int gradeLevel;
  final List<DocumentRequirementModel> missing;
  final List<DocumentRequirementModel> pending;
  final List<DocumentRequirementModel> verified;
  final int totalRequired;
  final int totalVerified;

  MissingRequirements({
    required this.category,
    required this.gradeLevel,
    required this.missing,
    required this.pending,
    required this.verified,
    required this.totalRequired,
    required this.totalVerified,
  });

  factory MissingRequirements.fromJson(Map<String, dynamic> json) {
    return MissingRequirements(
      category: json['category'] as String,
      gradeLevel: json['gradeLevel'] as int,
      missing: (json['missing'] as List)
          .map((r) => DocumentRequirementModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      pending: (json['pending'] as List)
          .map((r) => DocumentRequirementModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      verified: (json['verified'] as List)
          .map((r) => DocumentRequirementModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalRequired: json['totalRequired'] as int,
      totalVerified: json['totalVerified'] as int,
    );
  }
}

class DocumentRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // Documents
  Future<DocumentPage> getDocuments({
    String search = '',
    int page = 1,
    int limit = 20,
    String status = 'All Statuses',
    String documentType = 'All Types',
    String gradeLevel = '',
    String schoolYear = '',
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/documents',
        queryParameters: {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (status.trim().isNotEmpty && status != 'All Statuses') 'status': status.trim(),
          if (documentType.trim().isNotEmpty && documentType != 'All Types') 'documentType': documentType.trim(),
          if (gradeLevel.trim().isNotEmpty) 'gradeLevel': gradeLevel.trim(),
          if (schoolYear.trim().isNotEmpty) 'schoolYear': schoolYear.trim(),
          'page': page,
          'limit': limit,
        },
        options: options,
      );
      return DocumentPage.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch documents.';
      throw Exception(msg);
    }
  }

  Future<void> updateDocumentStatus(int id, String status) async {
    try {
      final options = await _getAuthOptions();
      await _dio.patch('/documents/$id/status', data: {'status': status}, options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update status.';
      throw Exception(msg);
    }
  }

  Future<void> deleteDocument(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/documents/$id', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to delete document.';
      throw Exception(msg);
    }
  }

  Future<List<DocumentModel>> getDocumentsByStudent(int studentId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/documents/student/$studentId',
        options: options,
      );
      return (response.data as List)
          .map((d) => DocumentModel.fromJson(d as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch student documents.';
      throw Exception(msg);
    }
  }

  // Requirements
  Future<List<DocumentRequirementModel>> getRequirements({
    String? category,
    bool? isEnabled,
    String search = '',
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/requirements',
        queryParameters: {
          if (category != null) 'category': category,
          if (isEnabled != null) 'isEnabled': isEnabled.toString(),
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
        options: options,
      );
      return (response.data as List)
          .map((r) => DocumentRequirementModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch requirements.';
      throw Exception(msg);
    }
  }

  Future<RequirementsSettings> getRequirementsSettings() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/requirements/settings', options: options);
      return RequirementsSettings.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch requirements settings.';
      throw Exception(msg);
    }
  }

  Future<MissingRequirements> getMissingRequirements(int studentId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/requirements/missing/$studentId', options: options);
      return MissingRequirements.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch missing requirements.';
      throw Exception(msg);
    }
  }

  Future<void> createRequirement(DocumentRequirementModel requirement) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/requirements', data: requirement.toJson(), options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to create requirement.';
      throw Exception(msg);
    }
  }

  Future<void> updateRequirement(DocumentRequirementModel requirement) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/requirements/${requirement.id}', data: requirement.toJson(), options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to update requirement.';
      throw Exception(msg);
    }
  }

  Future<void> deleteRequirement(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/requirements/$id', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to delete requirement.';
      throw Exception(msg);
    }
  }

  Future<void> bulkUpdateRequirements(List<Map<String, dynamic>> requirements) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/requirements/bulk', data: {'requirements': requirements}, options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to bulk update requirements.';
      throw Exception(msg);
    }
  }

  // Folders
  Future<List<FolderModel>> getFolders({int? studentId, int? parentId, String search = ''}) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '/folders',
        queryParameters: {
          if (studentId != null) 'studentId': studentId,
          if (parentId != null) 'parentId': parentId.toString(),
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
        options: options,
      );
      return (response.data as List)
          .map((f) => FolderModel.fromJson(f as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch folders.';
      throw Exception(msg);
    }
  }

  Future<FolderModel> getStudentFolder(int studentId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/folders/student/$studentId', options: options);
      return FolderModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch student folder.';
      throw Exception(msg);
    }
  }

  Future<int> createFolder({required String name, int? parentId, int? studentId, String? category}) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/folders',
        data: {
          'name': name,
          if (parentId != null) 'parentId': parentId,
          if (studentId != null) 'studentId': studentId,
          if (category != null) 'category': category,
        },
        options: options,
      );
      return response.data['id'] as int;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to create folder.';
      throw Exception(msg);
    }
  }

  Future<void> renameFolder(int id, String name) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/folders/$id', data: {'name': name}, options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to rename folder.';
      throw Exception(msg);
    }
  }

  Future<void> deleteFolder(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/folders/$id', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to delete folder.';
      throw Exception(msg);
    }
  }

  Future<void> syncFolders(int studentId) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/folders/sync', data: {'studentId': studentId}, options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to sync folders.';
      throw Exception(msg);
    }
  }

  // Print Queue
  Future<List<PrintQueueItem>> getPrintQueue() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/documents/print-queue', options: options);
      return (response.data as List)
          .map((i) => PrintQueueItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to fetch print queue.';
      throw Exception(msg);
    }
  }

  Future<void> addToPrintQueue(int documentId) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/documents/print-queue', data: {'documentId': documentId}, options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to add to print queue.';
      throw Exception(msg);
    }
  }

  Future<void> removeFromPrintQueue(int queueId) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/documents/print-queue/$queueId', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to remove from print queue.';
      throw Exception(msg);
    }
  }

  Future<void> clearPrintQueue() async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/documents/print-queue/clear', options: options);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to clear print queue.';
      throw Exception(msg);
    }
  }
}

