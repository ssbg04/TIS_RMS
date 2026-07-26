import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import 'dart:io';

class BackupRepository {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120), // Zipping might take time
    ),
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Downloads the backup ZIP and saves it to the specified path
  Future<void> downloadBackup(String savePath) async {
    try {
      final options = await _getAuthOptions();
      options.responseType = ResponseType.bytes;

      final response = await _dio.get('/backup/download', options: options);

      final file = File(savePath);
      await file.writeAsBytes(response.data as List<int>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? e.response?.data['message']
          : 'Failed to download backup.';
      throw Exception(msg ?? 'Failed to download backup.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Uploads a ZIP file to restore the database and uploads directory
  Future<void> restoreBackup(File file) async {
    try {
      final options = await _getAuthOptions();

      final formData = FormData.fromMap({
        'backup': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      });

      await _dio.post('/backup/restore', data: formData, options: options);
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message']
          : 'Failed to restore backup.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('An unexpected error occurred during restore.');
    }
  }

  /// Fetches the last backup and restore timestamps
  Future<Map<String, String?>> getBackupInfo() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/backup/info', options: options);

      return {
        'lastBackup': response.data['lastBackup'],
        'lastRestore': response.data['lastRestore'],
      };
    } catch (e) {
      return {'lastBackup': null, 'lastRestore': null};
    }
  }
}
