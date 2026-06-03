import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_model.dart';
import 'document_provider.dart';
import 'archives_provider.dart';
import 'student_provider.dart' hide academicYearsProvider;
import 'users_provider.dart';
import 'notification_provider.dart';
import 'navigation_provider.dart';
import 'dashboard_provider.dart';
import 'setup_provider.dart';
import 'reports_provider.dart';
import 'ocr_provider.dart';
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  FutureOr<UserModel?> build() {
    return null; // Always starts null; auto-login handled in SplashScreen
  }

  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.login(
        username,
        password,
        rememberMe: rememberMe,
      );
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

    // Invalidate all persistent providers so the next login starts clean.
    // autoDispose providers clean themselves up automatically; only persistent ones need this.
    _invalidateAllProviders();
  }

  void _invalidateAllProviders() {
    // Documents & folders
    ref.invalidate(documentQueryProvider);
    ref.invalidate(documentPageProvider);
    ref.invalidate(documentMutationProvider);
    ref.invalidate(printQueueMutationProvider);
    ref.invalidate(trashMutationProvider);
    ref.invalidate(requirementMutationProvider);
    ref.invalidate(folderMutationProvider);
    ref.invalidate(openedFolderStudentIdProvider);

    // Archives
    ref.invalidate(archiveQueryProvider);
    ref.invalidate(archiveDocumentQueryProvider);
    ref.invalidate(archiveMutationProvider);

    // Students
    ref.invalidate(studentQueryProvider);
    ref.invalidate(studentMutationProvider);

    // Users & notifications
    ref.invalidate(usersProvider);
    ref.invalidate(notificationsProvider);

    // Navigation
    ref.invalidate(activeTabProvider);

    // Dashboard
    ref.invalidate(dashboardDataProvider);

    // Setup / Settings
    ref.invalidate(academicYearsListProvider);
    ref.invalidate(sectionsListProvider);
    ref.invalidate(gradeLevelsListProvider);
    ref.invalidate(setupMutationProvider);

    // Reports
    ref.invalidate(selectedAcademicYearIdProvider);
    ref.invalidate(academicYearsProvider);
    ref.invalidate(selectedGradeLevelProvider);
    ref.invalidate(selectedSectionIdProvider);
    ref.invalidate(selectedStatusFilterProvider);
    ref.invalidate(showOnlyMissingDocsProvider);
    ref.invalidate(filterPanelExpandedProvider);
    ref.invalidate(missingDocsFilterExpandedProvider);
    ref.invalidate(yearlyComparisonSelectedYearsProvider);
    ref.invalidate(yearlyComparisonSelectedStatusesProvider);

    // OCR
    ref.invalidate(ocrProvider);
  }

  Future<void> refreshUser() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final updatedUser = await repository.getProfile();
      state = AsyncData(updatedUser);
    } catch (e, stack) {
      // Don't emit error state to prevent UI disruptions on background refresh failures
      print('Background refresh failed: $e');
    }
  }

  Future<bool> verifyPassword(String password) async {
    final repository = ref.read(authRepositoryProvider);
    return await repository.verifyPassword(password);
  }
}

// Full profile data provider
final profileProvider = FutureProvider.autoDispose<UserModel>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return await repository.getProfile();
});

// Super Admin: pending password reset requests
final resetRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repository = ref.read(authRepositoryProvider);
      return await repository.getResetRequests();
    });
