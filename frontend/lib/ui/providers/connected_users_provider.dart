import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/connected_users_repository.dart';
import '../../domain/entities/connected_user_model.dart';
import '../../domain/entities/user_model.dart';

final connectedUsersRepositoryProvider = Provider<ConnectedUsersRepository>(
  (ref) => ConnectedUsersRepository(),
);

class HeartbeatService {
  final ConnectedUsersRepository _repository;
  Timer? _timer;
  UserModel? _currentUser;

  HeartbeatService(this._repository);

  String get _platformName {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  void start(UserModel user) {
    stop(); // stop any existing timer
    _currentUser = user;
    _sendHeartbeat();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    final user = _currentUser;
    if (user == null) return;
    _repository.sendHeartbeat(
      username: user.username,
      role: user.role,
      platform: _platformName,
    );
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
