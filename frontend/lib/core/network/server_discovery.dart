import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_constants.dart';

/// Discovers the TIS RMS server on the local network (LAN) and manages seamless fallback to Cloud Tunnel.
/// 1. Instant UDP discovery beacon (<50ms) to detect local server on Wi-Fi/LAN automatically.
/// 2. Verifies physical network interfaces, filtering out virtual/bridge/loopback adapters.
/// 3. Probes local subnet hosts with bounded concurrency (pools of 25) using lightweight raw TCP checks first.
/// 4. Confirms identity via HTTP X-TIS-RMS response header.
/// 5. Prioritizes LAN for speed and offline resilience, seamlessly falling back to Cloud Tunnel (https://tis-rms.cc.cd/api).
class ServerDiscoveryService {
  static const int _port = 18484;
  static const int _discoveryPort = 18485;
  static const String _prefsKey = 'server_url';
  static const Duration _socketTimeout = Duration(milliseconds: 300);
  static const Duration _pingTimeout = Duration(seconds: 2);
  static const Duration _udpTimeout = Duration(milliseconds: 350);

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

  // ─── UDP Discovery Beacon (Instant <50ms auto-detection) ────────────────────

  /// Broadcasts a lightweight UDP probe ('TIS_RMS_DISCOVER') on port 18485.
  /// If the TIS RMS backend / Server Manager is running on the LAN, it replies in <50ms.
  /// Returns the discovered server URL (e.g. "http://192.168.1.50:18484") or null.
  static Future<String?> quickUdpBeacon({
    Duration timeout = _udpTimeout,
  }) async {
    RawDatagramSocket? socket;
    Timer? timer;
    final completer = Completer<String?>();

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      final message = utf8.encode('TIS_RMS_DISCOVER');

      // 1. Broadcast to standard global local subnet broadcast address
      try {
        socket.send(message, InternetAddress('255.255.255.255'), _discoveryPort);
      } catch (_) {}

      // 2. Also broadcast explicitly to all active physical subnet broadcast IPs (e.g. 192.168.1.255)
      try {
        final prefixes = await getSubnetPrefixes();
        for (final prefix in prefixes) {
          final broadcastIp = '${prefix}255';
          try {
            socket.send(message, InternetAddress(broadcastIp), _discoveryPort);
          } catch (_) {}
        }
      } catch (_) {}

      // Listen for UDP response from server
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null && !completer.isCompleted) {
            try {
              final text = utf8.decode(datagram.data).trim();
              if (text.contains('TIS_RMS_SERVER')) {
                int port = _port;
                try {
                  final Map<String, dynamic> data = jsonDecode(text);
                  if (data['port'] != null) {
                    port = int.tryParse(data['port'].toString()) ?? _port;
                  }
                } catch (_) {}

                final senderIp = datagram.address.address;
                final candidateUrl = 'http://$senderIp:$port';

                timer?.cancel();
                completer.complete(candidateUrl);
              }
            } catch (_) {}
          }
        }
      });

      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      final result = await completer.future;
      if (result != null) {
        // Fast HTTP verify check (500ms) to ensure API server is fully ready
        final verified = await ping(result, timeout: const Duration(milliseconds: 500));
        if (verified) {
          return result;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      timer?.cancel();
      socket?.close();
    }
  }

  // ─── Manual LAN-Only Scanner (Never falls back to Cloud Tunnel) ───────────

  /// Scans specifically for local network endpoints. Bypasses SharedPreferences
  /// and NEVER returns Cloud Tunnel. Used when user explicitly clicks "Scan Local Network".
  static Future<String?> scanLanOnly({
    void Function(String message)? onProgress,
  }) async {
    // 1. Fast UDP Discovery Beacon (<400ms)
    onProgress?.call('Broadcasting LAN discovery beacon…');
    final udpFound = await quickUdpBeacon(timeout: const Duration(milliseconds: 400));
    if (udpFound != null) {
      await save(udpFound);
      ApiConstants.setBaseUrl(udpFound);
      return udpFound;
    }

    // 2. Physical Subnet Probing (Fallback if Wi-Fi router blocks UDP broadcast)
    onProgress?.call('Scanning local network IP range…');
    final prefixes = await getSubnetPrefixes();
    if (prefixes.isNotEmpty) {
      final subnetFound = await discover(
        onProgress: (subnet, scanned, total) {
          onProgress?.call('Scanning LAN ${subnet}x … ($scanned/$total)');
        },
      );
      if (subnetFound != null) {
        await save(subnetFound);
        ApiConstants.setBaseUrl(subnetFound);
        return subnetFound;
      }
    }

    return null;
  }

  // ─── Master Resolution: Fast Concurrent Race (LAN & Tunnel) ──────────

  /// Resolves the optimal server endpoint with minimal latency:
  /// 1. Phase 1 (Concurrent <350ms): Races Localhost, UDP Beacon, and Saved LAN.
  /// 2. Phase 2 (Parallel Race): If Phase 1 didn't yield a local server, concurrently
  ///    probes Cloud Tunnel and physical subnets so remote/mobile users connect in <700ms
  ///    instead of stalling through 254-host scans.
  static Future<String?> resolveServerWithFallback({
    void Function(String message)? onProgress,
  }) async {
    // ── Phase 1: Fast Concurrent Local Checks (< 350ms) ──
    onProgress?.call('Probing local server & LAN…');

    final localFutures = <Future<String?>>[];

    // 1a. Localhost check
    localFutures.add(() async {
      final alive = await ping(
        ApiConstants.localhostUrl,
        timeout: const Duration(milliseconds: 300),
      );
      return alive ? ApiConstants.localhostUrl : null;
    }());

    // 1b. UDP Beacon (<350ms)
    localFutures.add(quickUdpBeacon(timeout: const Duration(milliseconds: 350)));

    // 1c. Saved LAN check
    final saved = await getSaved();
    if (saved != null && saved.isNotEmpty && ApiConstants.isLanUrl(saved)) {
      localFutures.add(() async {
        final alive = await ping(saved, timeout: const Duration(milliseconds: 350));
        return alive ? saved : null;
      }());
    }

    // Wait for the fast local checks
    final localResults = await Future.wait(localFutures);
    for (final res in localResults) {
      if (res != null) {
        await save(res);
        ApiConstants.setBaseUrl(res);
        return res;
      }
    }

    // ── Phase 2: Parallel Race (Cloud Tunnel vs LAN Subnet) ──
    onProgress?.call('Connecting to server (Tunnel / LAN)…');

    final completer = Completer<String?>();
    bool completed = false;

    void completeWith(String? url) {
      if (!completed && url != null) {
        completed = true;
        if (!completer.isCompleted) {
          completer.complete(url);
        }
      }
    }

    // Task A: Cloud Tunnel probe (fast primary path for off-campus/remote)
    final tunnelTask = () async {
      final tunnelAlive = await ping(
        ApiConstants.tunnelUrl,
        timeout: const Duration(seconds: 3),
      );
      if (tunnelAlive) {
        completeWith(ApiConstants.tunnelUrl);
        return ApiConstants.tunnelUrl;
      }

      // Legacy fallback tunnel
      final legacyAlive = await ping(
        ApiConstants.legacyTunnelUrl,
        timeout: const Duration(seconds: 2),
      );
      if (legacyAlive) {
        completeWith(ApiConstants.legacyTunnelUrl);
        return ApiConstants.legacyTunnelUrl;
      }
      return null;
    }();

    // Task B: Subnet probe (for school LAN where router dropped UDP beacon)
    final subnetTask = () async {
      try {
        final prefixes = await getSubnetPrefixes();
        if (prefixes.isNotEmpty) {
          final found = await discover(
            onProgress: (subnet, scanned, total) {
              if (!completed) {
                onProgress?.call('Scanning LAN ${subnet}x … ($scanned/$total)');
              }
            },
          );
          if (found != null) {
            completeWith(found);
            return found;
          }
        }
      } catch (_) {}
      return null;
    }();

    // Race both tasks
    await Future.any([
      tunnelTask.then((res) {
        if (res != null) completeWith(res);
      }),
      subnetTask.then((res) {
        if (res != null) completeWith(res);
      }),
      // Fallback timeout safety
      Future.delayed(const Duration(seconds: 5)),
    ]);

    // If either finished first and succeeded
    if (completed) {
      final winningUrl = await completer.future;
      if (winningUrl != null) {
        await save(winningUrl);
        ApiConstants.setBaseUrl(winningUrl);

        // If Cloud Tunnel won, let subnet discovery silently finish in background
        // and upgrade to LAN if local server is discovered
        if (!ApiConstants.isLanUrl(winningUrl)) {
          subnetTask.then((lanFound) async {
            if (lanFound != null) {
              await save(lanFound);
              ApiConstants.setBaseUrl(lanFound);
            }
          }).catchError((_) {});
        }

        return winningUrl;
      }
    }

    // Check if any finished right after timeout
    final tunnelResult = await tunnelTask;
    if (tunnelResult != null) {
      await save(tunnelResult);
      ApiConstants.setBaseUrl(tunnelResult);
      return tunnelResult;
    }

    final subnetResult = await subnetTask;
    if (subnetResult != null) {
      await save(subnetResult);
      ApiConstants.setBaseUrl(subnetResult);
      return subnetResult;
    }

    // Default fallback
    ApiConstants.setBaseUrl(ApiConstants.tunnelUrl);
    return null;
  }
}
