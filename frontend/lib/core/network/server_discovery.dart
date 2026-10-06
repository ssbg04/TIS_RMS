import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_constants.dart';

/// Discovers the TIS RMS server on the local network (LAN) and manages seamless fallback to Cloud Tunnel.
/// 1. Verifies physical network interfaces, filtering out virtual/bridge/loopback adapters.
/// 2. Probes local subnet hosts with bounded concurrency (pools of 25) using lightweight raw TCP checks first.
/// 3. Confirms identity via HTTP X-TIS-RMS response header.
/// 4. Prioritizes LAN for speed and offline resilience, seamlessly falling back to Cloud Tunnel (https://tis-rms.cc.cd/api).
class ServerDiscoveryService {
  static const int _port = 18484;
  static const String _prefsKey = 'server_url';
  static const Duration _socketTimeout = Duration(milliseconds: 300);
  static const Duration _pingTimeout = Duration(seconds: 2);

  // ─── Saved URL ────────────────────────────────────────────────────────────

  static Future<String?> getSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, url);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  // ─── Ping (check if a server URL is reachable and authentic) ──────────────

  static Future<bool> ping(String baseUrl, {Duration timeout = _pingTimeout}) async {
    try {
      final clean = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final dio = ApiConstants.createDio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

      final response = await dio.get(clean);
      if (response.headers.value('x-tis-rms') == 'true' ||
          (response.statusCode == 200 &&
              response.data is Map &&
              response.data['message']?.toString().contains('TIS RMS') == true)) {
        return true;
      }

      // If URL ends in /api, probe root as fallback; if it doesn't end in /api, probe /api
      final alternateUrl = clean.endsWith('/api')
          ? clean.replaceAll(RegExp(r'/api$'), '')
          : '$clean/api';

      if (alternateUrl.isNotEmpty && alternateUrl != clean) {
        final altResponse = await dio.get(alternateUrl);
        return altResponse.headers.value('x-tis-rms') == 'true' ||
            (altResponse.statusCode == 200 &&
                altResponse.data is Map &&
                altResponse.data['message']?.toString().contains('TIS RMS') == true);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Filtered physical LAN subnet prefixes ────────────────────────────────

  /// Returns valid physical IPv4 /24 subnet prefixes (e.g. ["192.168.1."]).
  /// Explicitly filters out virtual adapters (VirtualBox, VMware, WSL, vEthernet, APIPA, Bluetooth).
  static Future<List<String>> getSubnetPrefixes() async {
    final prefixes = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        // Ignore known virtual/tunnel/container interfaces that cause dead scanning on Windows
        if (name.contains('virtualbox') ||
            name.contains('vbox') ||
            name.contains('vmware') ||
            name.contains('wsl') ||
            name.contains('bluetooth') ||
            name.contains('vethernet') ||
            name.contains('teredo') ||
            name.contains('pseudo') ||
            name.contains('tap') ||
            name.contains('tun')) {
          continue;
        }

        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.') || // Loopback
              ip.startsWith('169.254.') || // APIPA (unconfigured network)
              ip.startsWith('192.168.56.') || // VirtualBox default host-only
              ip == '0.0.0.0') {
            continue;
          }

          final parts = ip.split('.');
          if (parts.length == 4) {
            prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}.');
          }
        }
      }
    } catch (_) {
      // Return empty on error
    }
    return prefixes.toList();
  }

  // ─── Concurrency-limited LAN Subnet Scanner ────────────────────────────────

  /// Probes hosts in a subnet using a concurrency-bounded pool (chunks of 25)
  /// and lightweight TCP socket checks first before attempting HTTP requests.
  /// Prevents Windows 10 socket buffer exhaustion (WSAENOBUFS 10055).
  static Future<String?> _scanSubnet(
    String prefix, {
    void Function(int scanned, int total)? onProgress,
  }) async {
    const total = 254;
    int scanned = 0;
    String? found;

    const chunkSize = 25;
    final allIps = List.generate(total, (i) => '$prefix${i + 1}');

    for (int chunkStart = 0; chunkStart < allIps.length; chunkStart += chunkSize) {
      if (found != null) break;

      final chunk = allIps.sublist(
        chunkStart,
        (chunkStart + chunkSize > allIps.length) ? allIps.length : chunkStart + chunkSize,
      );

      await Future.wait(
        chunk.map((ip) async {
          if (found != null) return;
          try {
            // Step 1: Lightweight raw TCP socket connect (300ms timeout)
            final socket = await Socket.connect(
              ip,
              _port,
              timeout: _socketTimeout,
            );
            socket.destroy();

            // Step 2: TCP connection succeeded! Confirm HTTP identity
            final url = 'http://$ip:$_port';
            final isAlive = await ping(
              url,
              timeout: const Duration(milliseconds: 700),
            );
            if (isAlive) {
              found = url;
            }
          } catch (_) {
            // Port closed or unreachable — ignore
          } finally {
            scanned++;
            onProgress?.call(scanned, total);
          }
        }),
      );
    }

    return found;
  }

  // ─── Main discovery entry point ───────────────────────────────────────────

  /// Scans physical subnets. Returns discovered server base URL or null.
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

  // ─── Master Resolution: LAN First, Then Seamless Tunnel Fallback ──────────

  /// Resolves the optimal server endpoint:
  /// 1. Fast Localhost check (for single-machine setups).
  /// 2. Fast check of previously working saved LAN URL.
  /// 3. Fast physical LAN discovery (bounded ~2.5s scan).
  /// 4. Previously saved Tunnel URL or Cloud Tunnel fallback (https://tis-rms.cc.cd/api).
  /// 5. VPS & Localhost fallbacks.
  static Future<String?> resolveServerWithFallback({
    void Function(String message)? onProgress,
  }) async {
    // 1. Fast Localhost Check (< 400ms)
    onProgress?.call('Checking local host (127.0.0.1)…');
    final localhostAlive = await ping(
      ApiConstants.localhostUrl,
      timeout: const Duration(milliseconds: 350),
    );
    if (localhostAlive) {
      await save(ApiConstants.localhostUrl);
      ApiConstants.setBaseUrl(ApiConstants.localhostUrl);
      return ApiConstants.localhostUrl;
    }

    // 2. Fast check of previously working saved server (instant reconnect)
    final saved = await getSaved();
    if (saved != null && saved.isNotEmpty) {
      onProgress?.call('Checking saved server connection…');
      final alive = await ping(saved, timeout: const Duration(seconds: 1));
      if (alive) {
        ApiConstants.setBaseUrl(saved);
        return saved;
      }
    }

    // 3. Scan physical Local Network (LAN)
    onProgress?.call('Scanning local network (LAN)…');
    final prefixes = await getSubnetPrefixes();
    if (prefixes.isNotEmpty) {
      final found = await discover(
        onProgress: (subnet, scanned, total) {
          onProgress?.call('Scanning LAN ${subnet}x … ($scanned/$total)');
        },
      );
      if (found != null) {
        await save(found);
        ApiConstants.setBaseUrl(found);
        return found;
      }
    }

    // 4. Cloudflare Tunnel Domain Fallback (https://tis-rms.cc.cd/api)
    onProgress?.call('Connecting to Cloud Tunnel…');
    final tunnelAlive = await ping(
      ApiConstants.tunnelUrl,
      timeout: const Duration(seconds: 3),
    );
    if (tunnelAlive) {
      await save(ApiConstants.tunnelUrl);
      ApiConstants.setBaseUrl(ApiConstants.tunnelUrl);
      return ApiConstants.tunnelUrl;
    }

    // 6. Cloud VPS Fallback (http://198.252.101.35:18484/api)
    onProgress?.call('Connecting to VPS backup…');
    final vpsAlive = await ping(
      ApiConstants.vpsUrl,
      timeout: const Duration(seconds: 2),
    );
    if (vpsAlive) {
      await save(ApiConstants.vpsUrl);
      ApiConstants.setBaseUrl(ApiConstants.vpsUrl);
      return ApiConstants.vpsUrl;
    }

    // Fallback default: Tunnel URL (https://tis-rms.cc.cd/api)
    ApiConstants.setBaseUrl(ApiConstants.tunnelUrl);
    return null;
  }

  /// Helper to check whether a URL points to a local or private address
  static bool _isLanUrl(String url) {
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
}
