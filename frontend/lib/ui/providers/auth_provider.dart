import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_model.dart';
import 'document_provider.dart';
import 'archives_provider.dart';
import 'student_provider.dart' hide academicYearsProvider;
import 'navigation_provider.dart';
import 'reports_provider.dart';
import 'connected_users_provider.dart';
import '../../core/services/foreground_sync_service.dart';
import '../../core/services/fcm_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  TwoFactorChallenge? _pendingTwoFactorChallenge;

  TwoFactorChallenge? get pendingTwoFactorChallenge =>
      _pendingTwoFactorChallenge;

  void clearPendingTwoFactorChallenge() {
    _pendingTwoFactorChallenge = null;
  }

  @override
  FutureOr<UserModel?> build() {
    return null; // Always starts null; auto-login handled in SplashScreen
  }

  void _completeSessionStart(UserModel user) {
    state = AsyncData(user);
    ref.read(heartbeatServiceProvider).start(user);
    ForegroundSyncService.start();
    FcmService.registerToken();
  }

  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    _pendingTwoFactorChallenge = null;
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final outcome = await repository.login(
        username,
        password,
        rememberMe: rememberMe,
      );
      if (outcome.requiresTwoFactor) {
        _pendingTwoFactorChallenge = outcome.twoFactorChallenge;
        state = const AsyncData(null);
        return false;
      }
      _completeSessionStart(outcome.user!);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> verifyTwoFactorLogin({
    required String challengeToken,
    required String code,
    bool isBackupCode = false,
    bool rememberMe = false,
  }) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.verifyTwoFactorLogin(
        challengeToken: challengeToken,
        code: code,
        isBackupCode: isBackupCode,
        rememberMe: rememberMe,
      );
      _pendingTwoFactorChallenge = null;
      _completeSessionStart(user);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<String> resendTwoFactorLoginOtp(String challengeToken) {
    return ref.read(authRepositoryProvider).resendTwoFactorLoginOtp(challengeToken);
  }

  Future<Map<String, dynamic>> getTwoFactorStatus() {
    return ref.read(authRepositoryProvider).getTwoFactorStatus();
  }

  Future<Map<String, dynamic>> setupTotp() {
    return ref.read(authRepositoryProvider).setupTotp();
  }

  Future<List<String>> confirmTotp(String code) {
    return ref.read(authRepositoryProvider).confirmTotp(code);
  }

  Future<String?> setupEmailTwoFactor() {
    return ref.read(authRepositoryProvider).setupEmailTwoFactor();
  }

  Future<List<String>> confirmEmailTwoFactor(String code) {
    return ref.read(authRepositoryProvider).confirmEmailTwoFactor(code);
  }

  Future<List<String>> regenerateTwoFactorBackupCodes(String password) {
    return ref.read(authRepositoryProvider).regenerateTwoFactorBackupCodes(password);
  }

  Future<void> disableTwoFactor(String password) {
    return ref.read(authRepositoryProvider).disableTwoFactor(password);
  }

  Future<bool> loginWithBiometrics(String biometricToken) async {
    _pendingTwoFactorChallenge = null;
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.loginWithBiometrics(biometricToken);
      _completeSessionStart(user);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<String> registerBiometrics() async {
    final repository = ref.read(authRepositoryProvider);
    return await repository.registerBiometrics();
  }

  Future<void> disableBiometrics({String? token}) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.disableBiometrics(token: token);
  }

  /// Called from SplashScreen — tries to auto-login from stored token.
  Future<UserModel?> tryAutoLogin() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.tryAutoLogin();
      if (user != null) {
        state = AsyncData(user);
        ref.read(heartbeatServiceProvider).start(user);
        ForegroundSyncService.start();
        FcmService.registerToken();
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    ref.read(heartbeatServiceProvider).stop();
    ForegroundSyncService.stop();
    await FcmService.unregisterToken();
    final repository = ref.read(authRepositoryProvider);
    await repository.logoutWithServer();
    state = const AsyncData(null);

    // Invalidate all persistent providers so the next login starts clean.
    // autoDispose providers clean themselves up automatically; only persistent ones need this.
    _invalidateAllProviders();
  }

  void _invalidateAllProviders() {
    // Only reset persistent filter and navigation states.
    // autoDispose FutureProviders clean themselves up automatically when screens unmount;
    // invalidating them during logout triggers unnecessary unauthenticated API requests.
    ref.invalidate(documentQueryProvider);
    ref.invalidate(openedFolderProvider);
    ref.invalidate(archiveQueryProvider);
    ref.invalidate(studentQueryProvider);
    ref.invalidate(activeTabProvider);

    ref.invalidate(selectedAcademicYearIdProvider);
    ref.invalidate(selectedGradeLevelProvider);
    ref.invalidate(selectedSectionIdProvider);
    ref.invalidate(selectedStatusFilterProvider);
    ref.invalidate(showOnlyMissingDocsProvider);
    ref.invalidate(filterPanelExpandedProvider);
    ref.invalidate(missingDocsFilterExpandedProvider);
    ref.invalidate(yearlyComparisonSelectedYearsProvider);
    ref.invalidate(yearlyComparisonSelectedStatusesProvider);
  }



  Future<void> refreshUser() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final updatedUser = await repository.getProfile();
      state = AsyncData(updatedUser);
    } catch (e) {
      // Don't emit error state to prevent UI disruptions on background refresh failures
      debugPrint('Background refresh failed: $e');
    }
  }

  Future<bool> verifyPassword(String password) async {
    final repository = ref.read(authRepositoryProvider);
    return await repository.verifyPassword(password);
  }

  Future<String> requestAccountDeletion() async {
    final repository = ref.read(authRepositoryProvider);
    return await repository.requestAccountDeletion();
  }

  Future<String> requestSelfDeactivation() async {
    final repository = ref.read(authRepositoryProvider);
    final msg = await repository.requestSelfDeactivation();
    // Sign out locally after deactivation
    await logout();
    return msg;
  }
}

// Full profile data provider
final profileProvider = FutureProvider.autoDispose<UserModel>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return await repository.getProfile();
});
