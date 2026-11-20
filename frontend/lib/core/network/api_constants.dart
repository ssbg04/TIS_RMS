import 'dart:io' show Platform, HttpClient;
import 'dart:math' show Random;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ui/shared/dialogs/session_expired_dialog.dart';

class ApiConstants {
  static const int port = 18484;
  static const String tunnelUrl = 'https://tis-rms.cc.cd/api';
  static const String legacyTunnelUrl = 'https://api.tisrms.de5.net/api';
  static const String localhostUrl = 'http://127.0.0.1:$port/api';

  // Runtime-mutable base URL — set by ServerDiscoveryService before first use.
  // Default: tunnel domain or discovered local server.
  static String _baseUrl = tunnelUrl;
  static String _deviceId = '';
  static String _deviceName = '';

  static String get baseUrl => _baseUrl;
  static String get clientDeviceId => _deviceId;

  /// Initializes a persistent per-install device ID and a human-readable device
  /// model name so multiple Android/Desktop devices under one user never collide.
  static Future<void> initDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var savedId = prefs.getString('client_device_id');
      if (savedId == null || savedId.isEmpty) {
        final rng = Random.secure();
        savedId = List.generate(
          32,
          (_) => rng.nextInt(16).toRadixString(16),
        ).join();
        await prefs.setString('client_device_id', savedId);
      }
      _deviceId = savedId;
    } catch (_) {}

    if (kIsWeb) {
      _deviceName = 'Web Browser';
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        final brand = info.manufacturer.trim();
        final model = info.model.trim();
        final combined = [brand, model]
            .where((s) => s.isNotEmpty)
            .join(' ')
            .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
            .trim();
        if (combined.isNotEmpty) {
          _deviceName = combined;
        }
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        final name = info.computerName
            .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
            .trim();
        if (name.isNotEmpty) {
          _deviceName = name;
        }
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        final name = info.utsname.machine.trim();
        if (name.isNotEmpty) {
          _deviceName = name;
        }
      }
    } catch (_) {}
  }

  static String get clientPlatform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isWindows) return 'windows';
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'windows';
  }

  static String get clientDeviceName {
    if (_deviceName.isNotEmpty) return _deviceName;
    if (kIsWeb) return 'Web Browser';
    try {
      if (Platform.isWindows) {
        final hostname = Platform.localHostname.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
        return hostname.isNotEmpty ? hostname : 'Windows PC';
      }
      if (Platform.isAndroid) return 'Android Device';
      if (Platform.isIOS) return 'iPhone';
      if (Platform.isMacOS) return 'Mac';
      if (Platform.isLinux) return 'Linux Device';
    } catch (_) {}
    return 'Windows PC';
  }

  /// Safely extracts user-friendly error message from any error/DioException.
  /// Never throws NoSuchMethodError and prevents raw FormatException / HTML dumps.
  static String extractErrorMessage(
    dynamic error, [
    String defaultMessage = 'Failed to connect to the server.',
  ]) {
    if (error == null) return defaultMessage;
    if (error is DioException) {
      final res = error.response;
      final data = res?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      if (data is String && data.isNotEmpty && !data.trimLeft().startsWith('<')) {
        return data.length > 200 ? '${data.substring(0, 200)}…' : data;
      }
      final statusCode = res?.statusCode;
      if (statusCode == 400) return 'Invalid request. Please check credentials or server URL.';
      if (statusCode == 401) return 'Invalid username or password.';
      if (statusCode == 403) return 'Access denied. Account may be inactive or lack permissions.';
      if (statusCode == 404) return 'The requested API route was not found on this server (404).';
      if (statusCode == 500) return 'Internal server error (500). Please try again later.';
      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return 'Server is temporarily unavailable (Gateway Error $statusCode).';
      }
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check your internet or server connection.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Could not connect to server. Please check your network connection.';
      }
      if (error.error is FormatException) {
        return 'Server returned an invalid response (non-JSON). Check that server URL points to TIS RMS.';
      }
      if (error.message != null && error.message!.isNotEmpty && !error.message!.contains('Exception')) {
        return error.message!;
      }
    }
    if (error is FormatException) {
      return 'Server returned an invalid response. Check that server URL points to TIS RMS.';
    }
    final raw = error.toString().replaceAll('Exception: ', '').replaceAll('FormatException: ', '').trim();
    if (raw.contains('Unexpected character') || raw.startsWith('FormatUnexpected')) {
      return 'Server returned an invalid response. Check that server URL points to TIS RMS.';
    }
    return raw.isNotEmpty ? raw : defaultMessage;
  }

  /// Checks if a given URL is a local or private network address
  static bool isLanUrl(String url) {
    return url.contains('192.168.') ||
        url.contains('10.') ||
        url.contains('127.0.0.1') ||
        url.contains('localhost') ||
        url.contains('172.16.') ||
        url.contains('172.17.') ||
        url.contains('172.18.') ||
        url.contains('172.19.') ||
        url.contains('172.20.') ||
        url.contains('172.21.') ||
        url.contains('172.22.') ||
        url.contains('172.23.') ||
        url.contains('172.24.') ||
        url.contains('172.25.') ||
        url.contains('172.26.') ||
        url.contains('172.27.') ||
        url.contains('172.28.') ||
        url.contains('172.29.') ||
        url.contains('172.30.') ||
        url.contains('172.31.');
  }

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

  /// Creates a Dio client that dynamically uses the active [baseUrl] on every request
  /// with resilient timeouts and SSL certificate handling for Windows 10 and LAN.
  static Dio createDio([BaseOptions? options]) {
    final effectiveOptions = options ??
        BaseOptions(
          baseUrl: _baseUrl,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        );

    // Ensure sensible timeouts and headers are set if custom options omitted them
    effectiveOptions.connectTimeout ??= const Duration(seconds: 8);
    effectiveOptions.receiveTimeout ??= const Duration(seconds: 15);
    effectiveOptions.sendTimeout ??= const Duration(seconds: 10);
    effectiveOptions.contentType ??= Headers.jsonContentType;

    final dio = Dio(effectiveOptions);

    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 8);
          client.badCertificateCallback = (cert, host, port) {
            // Allow tis-rms domain and private/local network ranges on desktop/LAN
            if (host.contains('tis-rms') ||
                host == '127.0.0.1' ||
                host == 'localhost' ||
                host.startsWith('192.168.') ||
                host.startsWith('10.') ||
                host.startsWith('172.')) {
              return true;
            }
            return false;
          };
          return client;
        },
      );
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!options.path.startsWith('http://') &&
              !options.path.startsWith('https://')) {
            options.baseUrl = _baseUrl;
          }
          options.headers['X-Platform'] ??= clientPlatform;
          options.headers['X-Device-Name'] ??= clientDeviceName;
          if (_deviceId.isNotEmpty) {
            options.headers['X-Device-Id'] ??= _deviceId;
          }
          options.headers['Accept'] ??= 'application/json, text/plain, */*';
          options.headers['User-Agent'] ??= 'TIS-RMS-Client/1.0 ($clientPlatform)';

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
        onError: (DioException err, handler) async {
          // Transparent LAN -> Cloud Tunnel failover on network drops or gateway errors
          final isConnError = err.type == DioExceptionType.connectionError ||
              err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.sendTimeout;
          final errStatusCode = err.response?.statusCode;
          final isGatewayDown = errStatusCode == 502 || errStatusCode == 503 || errStatusCode == 504;
          final alreadyRetried = err.requestOptions.extra['_failover_retried'] == true;

          if (!alreadyRetried && (isConnError || isGatewayDown) && isLanUrl(_baseUrl)) {
            debugPrint('[ApiConstants] LAN connection failed. Transparently falling back to Cloud Tunnel ($tunnelUrl)...');
            err.requestOptions.extra['_failover_retried'] = true;
            setBaseUrl(tunnelUrl);
            err.requestOptions.baseUrl = _baseUrl;
            try {
              final response = await dio.fetch(err.requestOptions);
              return handler.resolve(response);
            } catch (retryErr) {
              if (retryErr is DioException) {
                return handler.next(retryErr);
              }
            }
          }

          final statusCode = err.response?.statusCode;
          final data = err.response?.data;
          final isDeactivated = data is Map && data['isDeactivated'] == true;
          final isExpired = data is Map &&
              data['message']?.toString().toLowerCase().contains('expired') == true;

          // Only trigger re-login for authenticated requests, ignoring unauthenticated endpoints
          final authHeader = err.requestOptions.headers['Authorization']?.toString() ?? '';
          final hasAuth = authHeader.startsWith('Bearer ') &&
              authHeader != 'Bearer null' &&
              authHeader != 'Bearer undefined';

          if (hasAuth && (statusCode == 401 || (statusCode == 403 && (isDeactivated || isExpired)))) {
            // Expire / wipe stored JWT token immediately on deactivation or expiration
            try {
              const storage = FlutterSecureStorage();
              await storage.delete(key: 'jwt_token');
              await storage.delete(key: 'remember_me');
            } catch (_) {}
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              await prefs.remove('rememberMe');
            } catch (_) {}

            // Trigger non-technical re-login modal and navigate to LoginScreen
            Future.microtask(() {
              SessionExpiredDialog.show();
            });
          }

          return handler.next(err);
        },
      ),
    );
    return dio;
  }
}
