import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/connected_users_repository.dart';
import '../../domain/entities/connected_user_model.dart';
import '../../domain/entities/user_model.dart';
import '../../core/network/server_discovery.dart';

final connectedUsersRepositoryProvider = Provider<ConnectedUsersRepository>(
  (ref) => ConnectedUsersRepository(),
);

class HeartbeatService {
  final ConnectedUsersRepository _repository;
  Timer? _timer;
  UserModel? _currentUser;
  int _consecutiveFailures = 0;
  bool _isRecovering = false;

  /// Optional callback invoked when the server is verified unreachable via both LAN & Tunnel.
  void Function()? onConnectionLost;

  HeartbeatService(this._repository);

  String get _platformName {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  void start(UserModel user) {
    stop(); // stop any existing timer
    _currentUser = user;
    _consecutiveFailures = 0;
    _isRecovering = false;
    _sendHeartbeat();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
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
    } else {
      _consecutiveFailures++;
      debugPrint('[HeartbeatService] Consecutive failure count: $_consecutiveFailures');

      // If heartbeats fail 2 times in a row, attempt background LAN -> Tunnel recovery
      if (_consecutiveFailures >= 2 && !_isRecovering) {
        _isRecovering = true;
        debugPrint('[HeartbeatService] Attempting automatic LAN -> Tunnel recovery…');
        final recoveredUrl = await ServerDiscoveryService.resolveServerWithFallback();
        if (recoveredUrl != null) {
          debugPrint('[HeartbeatService] Successfully recovered connection to: $recoveredUrl');
          _consecutiveFailures = 0;
          _isRecovering = false;
        } else {
          debugPrint('[HeartbeatService] All connection attempts (LAN & Tunnel) failed.');
          _isRecovering = false;
          onConnectionLost?.call();
        }
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    final user = _currentUser;
    if (user != null) {
      _repository.sendLogout(username: user.username);
      _currentUser = null;
    }
  }
}

final heartbeatServiceProvider = Provider<HeartbeatService>((ref) {
  final repository = ref.read(connectedUsersRepositoryProvider);
  final service = HeartbeatService(repository);
  ref.onDispose(() => service.stop());
  return service;
});

final connectedUsersProvider =
    FutureProvider.autoDispose<List<ConnectedUserModel>>((ref) async {
  final repository = ref.read(connectedUsersRepositoryProvider);
  return await repository.getConnectedUsers();
});
