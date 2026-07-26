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
    _baseUrl = clean.endsWith('/api') ? clean : '$clean/api';
  }
}
