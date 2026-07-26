import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConstants {
  static const int port = 18484;
  static const String vpsUrl = 'http://198.252.107.197:$port/api';
  static const String localhostUrl = 'http://127.0.0.1:$port/api';

  // Runtime-mutable base URL — set by ServerDiscoveryService before first use.
  // Default: remote internet/configured VPS server IP or domain.
  static String _baseUrl = vpsUrl;

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    // Strip trailing slash then append /api
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    final newUrl = clean.endsWith('/api') ? clean : '$clean/api';
    if (_baseUrl != newUrl) {
      _baseUrl = newUrl;
      // Clear stored JWT token whenever server URL changes to prevent "token expired" on different server
      const FlutterSecureStorage().delete(key: 'jwt_token');
      const FlutterSecureStorage().delete(key: 'remember_me');
    }
  }

  /// Creates a Dio client that dynamically uses the active [baseUrl] on every request.
  static Dio createDio([BaseOptions? options]) {
    final dio = Dio(options ?? BaseOptions(baseUrl: _baseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = _baseUrl;
          return handler.next(options);
        },
      ),
    );
    return dio;
  }
}
