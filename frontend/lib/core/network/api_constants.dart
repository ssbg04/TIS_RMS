import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const int port = 18484;
  static const String tunnelUrl = 'https://tis-rms.cc.cd/api';
  static const String vpsUrl = 'http://198.252.107.197:$port/api';
  static const String localhostUrl = 'http://127.0.0.1:$port/api';

  // Runtime-mutable base URL — set by ServerDiscoveryService before first use.
  // Default: tunnel domain or discovered local server.
  static String _baseUrl = tunnelUrl;

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url, {bool clearAuth = false}) {
    // Strip trailing slash then append /api
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    final newUrl = clean.endsWith('/api') ? clean : '$clean/api';
    if (_baseUrl != newUrl) {
      _baseUrl = newUrl;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('server_url', newUrl);
      }).catchError((_) {});

      if (clearAuth) {
        // Clear stored JWT token whenever user explicitly switches to a different server
        const FlutterSecureStorage().delete(key: 'jwt_token');
        const FlutterSecureStorage().delete(key: 'remember_me');
      }
    }
  }

  /// Creates a Dio client that dynamically uses the active [baseUrl] on every request.
  static Dio createDio([BaseOptions? options]) {
    final dio = Dio(options ?? BaseOptions(baseUrl: _baseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = _baseUrl;

          // Prevent unauthenticated or malformed token requests from hitting the server
          final authHeader = options.headers['Authorization']?.toString() ?? '';
          if (authHeader == 'Bearer null' ||
              authHeader == 'Bearer ' ||
              authHeader == 'Bearer undefined') {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'Unauthenticated request cancelled: Invalid Authorization header ($authHeader)',
              ),
            );
          }

          return handler.next(options);
        },
      ),
    );
    return dio;
  }
}
