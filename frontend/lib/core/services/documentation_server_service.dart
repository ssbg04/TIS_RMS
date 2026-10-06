import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lightweight localhost loopback server for offline in-app documentation viewing.
/// Serves HTML, CSS, JavaScript, and images from Flutter bundled assets.
class DocumentationServerService {
  DocumentationServerService._();
  static final DocumentationServerService instance =
      DocumentationServerService._();

  HttpServer? _server;
  int? _port;

  int? get port => _port;
  String? get baseUrl => _port != null ? 'http://127.0.0.1:$_port' : null;

  /// Starts the loopback server if not already running and returns the entry point URL.
  Future<String> start() async {
    if (_server != null && _port != null) {
      return '$baseUrl/index.html';
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('[DocumentationServerService] Server error: $e');
      });
      debugPrint('[DocumentationServerService] Running on $baseUrl');
      return '$baseUrl/index.html';
    } catch (e) {
      debugPrint('[DocumentationServerService] Failed to bind server: $e');
      rethrow;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      var path = request.uri.path;
      if (path.isEmpty || path == '/') {
        path = '/index.html';
      }

      // Security: Strip directory traversal tokens
      final cleanPath = path.replaceAll('..', '');
      final assetPath = 'assets/documentation$cleanPath';

      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      final response = request.response;
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = _getContentType(cleanPath);
      response.headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');
      response.headers.add('Access-Control-Allow-Origin', '*');
      response.add(bytes);
      await response.close();
    } catch (_) {
      final response = request.response;
      response.statusCode = HttpStatus.notFound;
      response.headers.contentType = ContentType.text;
      response.write('Document asset not found');
      await response.close();
    }
  }

  ContentType _getContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html')) return ContentType.html;
    if (lower.endsWith('.css')) return ContentType('text', 'css', charset: 'utf-8');
    if (lower.endsWith('.js')) return ContentType('application', 'javascript', charset: 'utf-8');
    if (lower.endsWith('.png')) return ContentType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return ContentType('image', 'jpeg');
    if (lower.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (lower.endsWith('.ico')) return ContentType('image', 'x-icon');
    if (lower.endsWith('.woff2')) return ContentType('font', 'woff2');
    if (lower.endsWith('.woff')) return ContentType('font', 'woff');
    if (lower.endsWith('.ttf')) return ContentType('font', 'ttf');
    if (lower.endsWith('.json')) return ContentType('application', 'json', charset: 'utf-8');
    return ContentType.binary;
  }

  /// Stops the loopback server when closing app or releasing resources.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }
}
