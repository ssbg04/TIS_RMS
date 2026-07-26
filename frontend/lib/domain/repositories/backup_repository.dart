import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import 'dart:io';

class BackupRepository {
  final Dio _dio = ApiConstants.createDio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(hours: 2), // Allow up to 2 hours for multi-gigabyte uploads over WAN
      receiveTimeout: const Duration(hours: 2), // Allow up to 2 hours for extracting large zips
    ),
  );
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Downloads the backup ZIP and saves it to the specified path
  Future<void> downloadBackup(
    String savePath, {
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final options = await _getAuthOptions();
      await _dio.download(
        '/backup/download',
        savePath,
        options: options,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        final partialFile = File(savePath);
        if (await partialFile.exists()) {
          try {
            await partialFile.delete();
          } catch (_) {}
        }
        throw Exception('Backup download cancelled.');
      }
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message']
          : 'Failed to download backup.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Uploads a ZIP file to restore the database and uploads directory
  Future<void> restoreBackup(
    File file, {
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final options = await _getAuthOptions();

      final formData = FormData.fromMap({
        'backup': await MultipartFile.fromFile(
          file.path,
          filename: file.path.replaceAll('\\', '/').split('/').last,
        ),
      });

      await _dio.post(
        '/backup/restore',
        data: formData,
        options: options,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw Exception('Restore upload cancelled.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Upload timed out (${e.type.name}): The backup file upload took too long over your network/VPS.',
        );
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 413) {
        throw Exception(
          'Upload failed (HTTP 413): Backup file is too large for your VPS server. Please increase "client_max_body_size" in your Nginx config.',
        );
      }
      if (statusCode == 504 || statusCode == 502 || statusCode == 503) {
        throw Exception(
          'Upload failed (HTTP $statusCode): Your VPS reverse proxy timed out or is unavailable.',
        );
      }
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message']);
      }
      final statusText = statusCode != null ? ' (HTTP $statusCode)' : '';
      throw Exception(
        'Failed to restore backup$statusText: ${e.message ?? "Unknown error"}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred during restore: $e');
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
