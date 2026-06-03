import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/setup_models.dart';
import '../../domain/repositories/setup_repository.dart';

final setupRepositoryProvider = Provider<SetupRepository>((ref) {
  return SetupRepository();
});

final academicYearsListProvider = FutureProvider<List<AcademicYearModel>>((ref) async {
  final repo = ref.read(setupRepositoryProvider);
  return repo.getAcademicYears();
});

final sectionsListProvider = FutureProvider<List<SectionModel>>((ref) async {
  final repo = ref.read(setupRepositoryProvider);
  return repo.getAllSections();
});

final gradeLevelsListProvider = FutureProvider<List<GradeLevelModel>>((ref) async {
  final repo = ref.read(setupRepositoryProvider);
  return repo.getGradeLevels();
});

final teacherSectionsProvider = FutureProvider.family<List<SectionModel>, int>((ref, teacherId) async {
  final repo = ref.read(setupRepositoryProvider);
  return repo.getTeacherSections(teacherId);
});

// Setup mutation notifier for CRUD setup actions
final setupMutationProvider = AsyncNotifierProvider<SetupMutationNotifier, void>(
  SetupMutationNotifier.new,
);

class SetupMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  // Academic Years
  Future<void> createAcademicYear({required String yearRange, required String status}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.createAcademicYear(yearRange: yearRange, status: status);
      state = const AsyncData(null);
      ref.invalidate(academicYearsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateAcademicYear({required int id, required String yearRange, required String status}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.updateAcademicYear(id: id, yearRange: yearRange, status: status);
      state = const AsyncData(null);
      ref.invalidate(academicYearsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteAcademicYear(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.deleteAcademicYear(id);
      state = const AsyncData(null);
      ref.invalidate(academicYearsListProvider);
      // Cascades delete sections
      ref.invalidate(sectionsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Sections
  Future<void> createSection({required String name, required int gradeLevel, required int academicYearId}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.createSection(name: name, gradeLevel: gradeLevel, academicYearId: academicYearId);
      state = const AsyncData(null);
      ref.invalidate(sectionsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateSection({required int id, required String name, required int gradeLevel, required int academicYearId}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.updateSection(id: id, name: name, gradeLevel: gradeLevel, academicYearId: academicYearId);
      state = const AsyncData(null);
      ref.invalidate(sectionsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteSection(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.deleteSection(id);
      state = const AsyncData(null);
      ref.invalidate(sectionsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Grade Levels
  Future<void> createGradeLevel({required int level, required String name}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.createGradeLevel(level: level, name: name);
      state = const AsyncData(null);
      ref.invalidate(gradeLevelsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateGradeLevel({required int id, required int level, required String name}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.updateGradeLevel(id: id, level: level, name: name);
      state = const AsyncData(null);
      ref.invalidate(gradeLevelsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteGradeLevel(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.deleteGradeLevel(id);
      state = const AsyncData(null);
      ref.invalidate(gradeLevelsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Teacher Sections Assignment
  Future<void> updateTeacherSections({required int teacherId, required List<int> sectionIds}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(setupRepositoryProvider);
      await repo.updateTeacherSections(teacherId: teacherId, sectionIds: sectionIds);
      state = const AsyncData(null);
      ref.invalidate(teacherSectionsProvider(teacherId));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
