import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  FutureOr<UserModel?> build() {
    return null; // Always starts null; auto-login handled in SplashScreen
  }

  Future<bool> login(String username, String password, {bool rememberMe = false}) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.login(username, password, rememberMe: rememberMe);
      state = AsyncData(user);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Called from SplashScreen — tries to auto-login from stored token.
  Future<UserModel?> tryAutoLogin() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.tryAutoLogin();
      if (user != null) {
        state = AsyncData(user);
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AsyncData(null);
  }
}

// Full profile data provider
final profileProvider = FutureProvider.autoDispose<UserModel>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return await repository.getProfile();
});

// Super Admin: pending password reset requests
final resetRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return await repository.getResetRequests();
});