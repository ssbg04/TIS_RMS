import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../entities/ocr_result_model.dart';

class OcrRepository {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 60), // OCR takes time
    receiveTimeout: const Duration(seconds: 60),
  ));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Sends the image to Node.js and returns the parsed OCR Model
  Future<OcrResultModel> extractOcrData({
    required File file,
    required String fileName,
    required String docType,
  }) async {
    try {
      final options = await _getAuthOptions();

      final formData = FormData.fromMap({
        'docType': docType,
        'document': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post(
        '/ocr/extract',
        data: formData,
        options: options,
      );

      return OcrResultModel.fromJson(response.data as Map<String, dynamic>);
      
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Failed to connect to OCR Server.';
      throw Exception(msg);
    } catch (e) {
      throw Exception('An unexpected error occurred during OCR extraction.');
    }
  }
}