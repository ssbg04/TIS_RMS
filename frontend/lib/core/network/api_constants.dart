class ApiConstants {
  static const int port = 18484;

  // Runtime-mutable base URL — set by ServerDiscoveryService before first use.
  // Default: localhost for Windows desktop, Android will discover via LAN scan.
  static String _baseUrl = 'http://127.0.0.1:$port/api';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    // Strip trailing slash then append /api
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    _baseUrl = clean.endsWith('/api') ? clean : '$clean/api';
  }
}