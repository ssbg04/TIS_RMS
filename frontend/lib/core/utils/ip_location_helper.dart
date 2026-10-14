import 'dart:convert';
import 'dart:io';

/// Helper utility to determine or resolve location for IP addresses.
class IpLocationHelper {
  // In-memory cache to avoid repeated network calls for the same public IP
  static final Map<String, String> _cache = {};

  /// Fast synchronous resolution for local/private network addresses
  static String? getFastLocation(String? ip) {
    if (ip == null || ip.trim().isEmpty) return null;
    final cleanIp = ip.trim().replaceAll('::ffff:', '');

    if (cleanIp == '127.0.0.1' || cleanIp == '::1' || cleanIp.toLowerCase() == 'localhost') {
      return 'Local Machine';
    }

    final lowerIp = cleanIp.toLowerCase();

    // Check private RFC1918, RFC4193, & link-local ranges (both IPv4 and IPv6)
    if (lowerIp.startsWith('192.168.') ||
        lowerIp.startsWith('10.') ||
        lowerIp.startsWith('169.254.') ||
        lowerIp.startsWith('fe80:') ||
        lowerIp.startsWith('fc') ||
        lowerIp.startsWith('fd')) {
      return 'Local Network (LAN)';
    }

    if (lowerIp.startsWith('172.')) {
      final parts = lowerIp.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) {
          return 'Local Network (LAN)';
        }
      }
    }

    return _cache[cleanIp];
  }

  /// Resolve location asynchronously. If private/local, returns immediately.
  /// If public IP, queries free ip-api.com and caches the result.
  static Future<String> resolveLocation(String? ip) async {
    if (ip == null || ip.trim().isEmpty) return 'Unknown Location';
    final cleanIp = ip.trim().replaceAll('::ffff:', '');

    final fast = getFastLocation(cleanIp);
    if (fast != null) return fast;

    if (_cache.containsKey(cleanIp)) {
      return _cache[cleanIp]!;
    }

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(
        Uri.parse('http://ip-api.com/json/$cleanIp?fields=status,city,regionName,country'),
      );
      final response = await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          final city = data['city']?.toString() ?? '';
          final country = data['country']?.toString() ?? '';
          final parts = [city, country].where((s) => s.isNotEmpty).toList();
          if (parts.isNotEmpty) {
            final loc = parts.join(', ');
            _cache[cleanIp] = loc;
            return loc;
          }
        }
      }
    } catch (_) {
      // Offline, network failure or timeout
    }

    _cache[cleanIp] = 'Public Network';
    return 'Public Network';
  }
}
