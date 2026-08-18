import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Discovers the TIS RMS server on the local network by:
/// 1. Reading the device's own LAN IP to derive the subnet prefix.
/// 2. Concurrently probing all 254 host addresses on that subnet.
/// 3. Verifying each candidate by checking the X-TIS-RMS response header.
class ServerDiscoveryService {
  static const int _port = 18484;
  static const String _prefsKey = 'server_url';
  static const Duration _probeTimeout = Duration(milliseconds: 800);
  static const Duration _pingTimeout = Duration(seconds: 3);

  // ─── Saved URL ────────────────────────────────────────────────────────────

  static Future<String?> getSaved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<void> save(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // ─── Ping (check if a saved URL is still reachable) ─────────────────────

  static Future<bool> ping(String baseUrl) async {
    try {
      final clean = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final dio = Dio(
        BaseOptions(
          connectTimeout: _pingTimeout,
          receiveTimeout: _pingTimeout,
          sendTimeout: _pingTimeout,
        ),
      );
      final response = await dio.get(clean);
      if (response.headers.value('x-tis-rms') == 'true' ||
          (response.statusCode == 200 &&
              response.data is Map &&
              response.data['message']?.toString().contains('TIS RMS') == true)) {
        return true;
      }
      final rootUrl = clean.replaceAll(RegExp(r'/api$'), '');
      if (rootUrl.isNotEmpty && rootUrl != clean) {
        final rootResponse = await dio.get(rootUrl);
        return rootResponse.headers.value('x-tis-rms') == 'true' ||
            (rootResponse.statusCode == 200 &&
                rootResponse.data is Map &&
                rootResponse.data['message']?.toString().contains('TIS RMS') == true);
      }
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Get device's own LAN IP addresses ───────────────────────────────────

  /// Returns a list of subnet prefixes like ["192.168.1.", "10.0.0."]
  /// derived from the device's active network interfaces (non-loopback IPv4).
  static Future<List<String>> getSubnetPrefixes() async {
    final prefixes = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            // Build the /24 subnet prefix (first 3 octets)
            prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}.');
          }
        }
      }
    } catch (_) {
      // If we cannot enumerate interfaces, fall back to nothing
    }
    return prefixes.toList();
  }

  // ─── Scan one subnet prefix ───────────────────────────────────────────────

  /// Probes all 254 hosts in a given subnet prefix concurrently.
  /// Returns the first URL that responds with X-TIS-RMS: true, or null.
  static Future<String?> _scanSubnet(
    String prefix, {
    void Function(int scanned, int total)? onProgress,
  }) async {
    const total = 254;
    int scanned = 0;
    String? found;

    final futures = List.generate(total, (i) async {
      if (found != null) return;
      final url = 'http://$prefix${i + 1}:$_port';
      try {
        final dio = Dio(
          BaseOptions(
            connectTimeout: _probeTimeout,
            receiveTimeout: _probeTimeout,
            sendTimeout: _probeTimeout,
          ),
        );
        final response = await dio.get('$url/');
        if (response.headers.value('x-tis-rms') == 'true') {
          found = url;
        }
      } catch (_) {
        // Not reachable — ignore
      } finally {
        scanned++;
        onProgress?.call(scanned, total);
      }
    });

    await Future.wait(futures);
    return found;
  }

  // ─── Main discovery entry point ───────────────────────────────────────────

  /// Scans all detected subnets. Returns the discovered server base URL
  /// (e.g. "http://192.168.1.50:18484") or null if nothing is found.
  static Future<String?> discover({
    void Function(String subnet, int scanned, int total)? onProgress,
  }) async {
    final prefixes = await getSubnetPrefixes();
    if (prefixes.isEmpty) return null;

    for (final prefix in prefixes) {
      final result = await _scanSubnet(
        prefix,
        onProgress: (s, t) => onProgress?.call(prefix, s, t),
      );
      if (result != null) return result;
    }
    return null;
  }
}
