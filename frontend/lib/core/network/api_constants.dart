class ApiConstants {
  static const int port = 18484;

  // Runtime-mutable base URL — set by ServerDiscoveryService before first use.
  // Default: remote internet/configured server IP or domain.
  static String _baseUrl = 'http://198.252.107.197:$port/api';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    // Strip trailing slash then append /api
    final clean = url.replaceAll(RegExp(r'/+$'), '');
    _baseUrl = clean.endsWith('/api') ? clean : '$clean/api';
  }
}
