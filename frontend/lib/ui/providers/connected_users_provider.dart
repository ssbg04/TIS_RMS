import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/connected_users_repository.dart';
import '../../domain/entities/connected_user_model.dart';
import '../../domain/entities/user_model.dart';
import '../../core/network/server_discovery.dart';

final connectedUsersRepositoryProvider = Provider<ConnectedUsersRepository>(
  (ref) => ConnectedUsersRepository(),
);

enum ServerConnectionStatus { connected, reconnecting, offline }

final serverConnectionStatusProvider = StateProvider<ServerConnectionStatus>(
  (ref) => ServerConnectionStatus.connected,
);

class HeartbeatService {
  final ConnectedUsersRepository _repository;
  final Ref? _ref;
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  UserModel? _currentUser;
  int _consecutiveFailures = 0;
  bool _isRecovering = false;
  bool _isDeviceOffline = false;

  /// Optional callback invoked when the server is verified unreachable via both LAN & Tunnel.
  void Function()? onConnectionLost;

  HeartbeatService(this._repository, [this._ref]);

  String get _platformName {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  void start(UserModel user) {
    stop(); // stop any existing timer & listeners
    _currentUser = user;
    _consecutiveFailures = 0;
    _isRecovering = false;

    // 1. Reactive OS network listener
    _initConnectivityListener();

    // 2. Initial heartbeat and adaptive scheduler
    _sendHeartbeat();
  }

  void _initConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasNoConnection = results.isEmpty ||
          (results.length == 1 && results.first == ConnectivityResult.none);

      if (hasNoConnection) {
        debugPrint('[HeartbeatService] Physical network disconnected.');
        _isDeviceOffline = true;
        _ref?.read(serverConnectionStatusProvider.notifier).state =
            ServerConnectionStatus.offline;
        _scheduleNextCheck(const Duration(seconds: 5));
      } else if (_isDeviceOffline) {
        debugPrint('[HeartbeatService] Physical network restored ($results). Triggering instant reconnect.');
        _isDeviceOffline = false;
        _ref?.read(serverConnectionStatusProvider.notifier).state =
            ServerConnectionStatus.reconnecting;
        checkNow();
      }
    });
  }

  Future<void> checkNow() => _sendHeartbeat();

  void _scheduleNextCheck([Duration? overrideDuration]) {
    _timer?.cancel();
    if (_currentUser == null) return;

    final Duration delay;
    if (overrideDuration != null) {
      delay = overrideDuration;
    } else {
      final currentStatus = _ref?.read(serverConnectionStatusProvider) ??
          ServerConnectionStatus.connected;
      switch (currentStatus) {
        case ServerConnectionStatus.connected:
          delay = const Duration(minutes: 1);
          break;
        case ServerConnectionStatus.reconnecting:
          delay = const Duration(seconds: 5);
          break;
        case ServerConnectionStatus.offline:
          // Exponential backoff up to 20s
          final backoff = (_consecutiveFailures * 5).clamp(5, 20);
          delay = Duration(seconds: backoff);
          break;
      }
    }

    _timer = Timer(delay, () {
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    final user = _currentUser;
    if (user == null) return;

    final success = await _repository.sendHeartbeat(
      username: user.username,
      role: user.role,
      platform: _platformName,
    );

    if (success) {
      _consecutiveFailures = 0;
      _isRecovering = false;
      _ref?.read(serverConnectionStatusProvider.notifier).state =
          ServerConnectionStatus.connected;
      _scheduleNextCheck();
    } else {
      _consecutiveFailures++;
      debugPrint('[HeartbeatService] Consecutive failure count: $_consecutiveFailures');

      // Attempt background LAN -> Tunnel auto-recovery
      if (_consecutiveFailures >= 2 && !_isRecovering) {
        _isRecovering = true;
        _ref?.read(serverConnectionStatusProvider.notifier).state =
            ServerConnectionStatus.reconnecting;
        debugPrint('[HeartbeatService] Attempting automatic LAN -> Tunnel recovery…');
        final recoveredUrl = await ServerDiscoveryService.resolveServerWithFallback();
        if (recoveredUrl != null) {
          debugPrint('[HeartbeatService] Successfully recovered connection to: $recoveredUrl');
          _consecutiveFailures = 0;
          _isRecovering = false;
          _ref?.read(serverConnectionStatusProvider.notifier).state =
              ServerConnectionStatus.connected;
          _scheduleNextCheck();
        } else {
          debugPrint('[HeartbeatService] All connection attempts (LAN & Tunnel) failed.');
          _isRecovering = false;
          _ref?.read(serverConnectionStatusProvider.notifier).state =
              ServerConnectionStatus.offline;
          onConnectionLost?.call();
          _scheduleNextCheck();
        }
      } else if (_consecutiveFailures >= 1) {
        _ref?.read(serverConnectionStatusProvider.notifier).state =
            ServerConnectionStatus.reconnecting;
        _scheduleNextCheck();
      } else {
        _scheduleNextCheck();
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    final user = _currentUser;
    if (user != null) {
      _repository.sendLogout(username: user.username);
      _currentUser = null;
    }
  }
}

final heartbeatServiceProvider = Provider<HeartbeatService>((ref) {
  final repository = ref.read(connectedUsersRepositoryProvider);
  final service = HeartbeatService(repository, ref);
  ref.onDispose(() => service.stop());
  return service;
});

final connectedUsersProvider =
    FutureProvider.autoDispose<List<ConnectedUserModel>>((ref) async {
  final repository = ref.read(connectedUsersRepositoryProvider);
  return await repository.getConnectedUsers();
});
