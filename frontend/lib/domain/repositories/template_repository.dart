import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/template_model.dart';

class TemplateRepository {
  final Dio _dio = ApiConstants.createDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── Fetch all templates (optionally filtered by requirementId) ───────────
  Future<List<DocumentTemplateModel>> getTemplates({
    int? requirementId,
    bool? isActive,
  }) async {
    final options = await _authOptions();
    final queryParams = <String, dynamic>{};
    if (requirementId != null) queryParams['requirementId'] = requirementId;
    if (isActive != null) queryParams['isActive'] = isActive.toString();

    final response = await _dio.get(
      '/templates',
      queryParameters: queryParams,
      options: options,
    );
    return (response.data as List)
        .map((j) => DocumentTemplateModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── Fetch single template with versions ──────────────────────────────────
  Future<DocumentTemplateModel> getTemplateById(int id) async {
    final options = await _authOptions();
    final response = await _dio.get('/templates/$id', options: options);
    return DocumentTemplateModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Fetch template versions ───────────────────────────────────────────────
  Future<List<TemplateVersionModel>> getTemplateVersions(int templateId) async {
    final options = await _authOptions();
    final response = await _dio.get('/templates/$templateId/versions', options: options);
    return (response.data as List)
        .map((j) => TemplateVersionModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── Create template (with optional file) ─────────────────────────────────
  Future<int> createTemplate({
    required String name,
    String? description,
    int? requirementId,
    bool isActive = true,
    File? file,
  }) async {
    final options = await _authOptions();
    final formData = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      if (requirementId != null) 'requirementId': requirementId.toString(),
      'isActive': isActive.toString(),
      if (file != null)
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
    });
    final response = await _dio.post(
      '/templates',
      data: formData,
      options: options,
    );
    return (response.data['id'] as num).toInt();
  }

  // ── Update template ───────────────────────────────────────────────────────
  Future<void> updateTemplate(
    int id, {
    String? name,
    String? description,
    int? requirementId,
    bool? isActive,
  }) async {
    final options = await _authOptions();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (requirementId != null) body['requirementId'] = requirementId;
    if (isActive != null) body['isActive'] = isActive;
    await _dio.patch('/templates/$id', data: body, options: options);
  }

  // ── Upload new template version ───────────────────────────────────────────
  Future<int> uploadTemplateVersion(int templateId, File file) async {
    final options = await _authOptions();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
    });
    final response = await _dio.post(
      '/templates/$templateId/upload-version',
      data: formData,
      options: options,
    );
    return (response.data['version_number'] as num).toInt();
  }

  // ── Download template (current version) to a local path ──────────────────
  Future<String> downloadTemplate(
    int templateId,
    String savePath, {
    void Function(int, int)? onReceiveProgress,
  }) async {
    final options = await _authOptions();
    await _dio.download(
      '/templates/$templateId/download',
      savePath,
      options: options,
      onReceiveProgress: onReceiveProgress,
    );
    return savePath;
  }

  // ── Delete template ───────────────────────────────────────────────────────
  Future<void> deleteTemplate(int id) async {
    final options = await _authOptions();
    await _dio.delete('/templates/$id', options: options);
  }
}
