import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_constants.dart';
import '../../domain/repositories/student_repository.dart';
import '../../domain/entities/student_model.dart';

// ============================================================
// Academic Years Model
// ============================================================
class AcademicYear {
  final int id;
  final String yearRange;
  final String status;

  AcademicYear({
    required this.id,
    required this.yearRange,
    required this.status,
  });

  factory AcademicYear.fromJson(Map<String, dynamic> json) {
    return AcademicYear(
      id: json['id'] as int,
      yearRange: json['year_range'] as String,
      status: json['status'] as String? ?? 'active',
    );
  }
}

// ============================================================
// Repository provider
// ============================================================
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository();
});

// ============================================================
// Academic Years Provider
// ============================================================
final academicYearsProvider = FutureProvider.autoDispose<List<AcademicYear>>((
  ref,
) async {
  final storage = const FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  final dio = ApiConstants.createDio();

  try {
    final response = await dio.get(
      '/setup/academic-years',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (response.data as List)
        .map((y) => AcademicYear.fromJson(y as Map<String, dynamic>))
        .toList();
  } catch (e) {
    return [];
  }
});

// ============================================================
// Student Detail Provider
// ============================================================
final studentDetailProvider = FutureProvider.family
    .autoDispose<StudentModel, int>((ref, studentId) async {
      final repo = ref.read(studentRepositoryProvider);
      return repo.getStudentById(studentId);
    });

// ============================================================
// Query params state — drives what the list shows
// ============================================================
class StudentQueryParams {
  final String search;
  final int page;
  final int limit;
  final String gradeLevel; // '' = All
  final String status; // '' = All
  final String section; // '' = All
  final String schoolYear; // '' = All
  final String is4Ps; // '' = All, 'true' = Yes, 'false' = No
  final String lrn; // '' = All
  final String sortBy; // '' = None, 'lrn', 'name', 'grade_section', 'doc_status'
  final String sortOrder; // '' = None, 'asc', 'desc'

  const StudentQueryParams({
    this.search = '',
    this.page = 1,
    this.limit = 20,
    this.gradeLevel = '',
    this.status = '',
    this.section = '',
    this.schoolYear = '',
    this.is4Ps = '',
    this.lrn = '',
    this.sortBy = '',
    this.sortOrder = '',
  });

  StudentQueryParams copyWith({
    String? search,
    int? page,
    int? limit,
    String? gradeLevel,
    String? status,
    String? section,
    String? schoolYear,
    String? is4Ps,
    String? lrn,
    String? sortBy,
    String? sortOrder,
  }) {
    return StudentQueryParams(
      search: search ?? this.search,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      status: status ?? this.status,
      section: section ?? this.section,
      schoolYear: schoolYear ?? this.schoolYear,
      is4Ps: is4Ps ?? this.is4Ps,
      lrn: lrn ?? this.lrn,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

// ============================================================
// Notifier — manages the live query state
// ============================================================
final studentQueryProvider =
    NotifierProvider<StudentQueryNotifier, StudentQueryParams>(
      StudentQueryNotifier.new,
    );

class StudentQueryNotifier extends Notifier<StudentQueryParams> {
  @override
  StudentQueryParams build() => const StudentQueryParams();

  void setSearch(String value) {
    // Reset to page 1 whenever search changes
    state = state.copyWith(search: value, page: 1);
  }

  void setPage(int page) => state = state.copyWith(page: page);

  void setLimit(int limit) => state = state.copyWith(limit: limit, page: 1);

  void setGradeLevel(String grade) =>
      state = state.copyWith(gradeLevel: grade, section: '', page: 1);

  void setStatus(String status) =>
      state = state.copyWith(status: status, page: 1);

  void setSection(String section) =>
      state = state.copyWith(section: section, page: 1);

  void setSchoolYear(String schoolYear) => state = state.copyWith(
    schoolYear: schoolYear,
    gradeLevel: '',
    section: '',
    page: 1,
  );

  void setIs4Ps(String is4Ps) => state = state.copyWith(is4Ps: is4Ps, page: 1);

  void setLrn(String lrn) => state = state.copyWith(lrn: lrn, page: 1);

  void setSort(String sortBy, String sortOrder) => state = state.copyWith(
    sortBy: sortBy,
    sortOrder: sortOrder,
    page: 1,
  );

  void setFilters({
    String? schoolYear,
    String? gradeLevel,
    String? section,
    String? status,
    String? is4Ps,
    String? sortBy,
    String? sortOrder,
    int? limit,
  }) {
    state = state.copyWith(
      schoolYear: schoolYear ?? state.schoolYear,
      gradeLevel: gradeLevel ?? state.gradeLevel,
      section: section ?? state.section,
      status: status ?? state.status,
      is4Ps: is4Ps ?? state.is4Ps,
      sortBy: sortBy ?? state.sortBy,
      sortOrder: sortOrder ?? state.sortOrder,
      limit: limit ?? state.limit,
      page: 1,
    );
  }

  void reset() => state = const StudentQueryParams();
}

// ============================================================
// Multi-Select & Filter State Providers
// ============================================================
final studentMultiSelectProvider = StateProvider<bool>((ref) => false);
final studentSelectedIdsProvider = StateProvider<List<int>>((ref) => []);

final studentActiveFilterCountProvider = Provider<int>((ref) {
  final query = ref.watch(studentQueryProvider);
  return [
    query.gradeLevel.isNotEmpty,
    query.section.isNotEmpty,
    query.status.isNotEmpty,
    query.schoolYear.isNotEmpty,
    query.is4Ps.isNotEmpty,
    query.sortBy.isNotEmpty,
    query.limit != 20,
  ].where((v) => v).length;
});

// ============================================================
// Async data provider — re-fetches when query changes
// ============================================================
final studentPageProvider = FutureProvider.autoDispose<StudentPage>((
  ref,
) async {
  final query = ref.watch(studentQueryProvider);
  final repo = ref.read(studentRepositoryProvider);

  final sub = repo.onStudentChanged.listen((_) {
    ref.invalidateSelf();
  });

  ref.onDispose(() => sub.cancel());

  return repo.getStudents(
    search: query.search,
    page: query.page,
    limit: query.limit,
    gradeLevel: query.gradeLevel,
    status: query.status,
    section: query.section,
    schoolYear: query.schoolYear,
    is4ps: query.is4Ps,
    lrn: query.lrn,
    sortBy: query.sortBy,
    sortOrder: query.sortOrder,
  );
});

// ============================================================
// Mutation notifier — handles Create / Update / Delete
// ============================================================
final studentMutationProvider =
    AsyncNotifierProvider<StudentMutationNotifier, void>(
      StudentMutationNotifier.new,
    );

class StudentMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<int> createStudent({
    required String lrn,
    required String firstName,
    String? middleName,
    required String lastName,
    String? extension,
    required String sex,
    required DateTime? birthDate,
    required int academicYearId,
    required int gradeLevel,
    required int sectionId,
    String? trackStrand,
    bool is4ps = false,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      final id = await repo.createStudent(
        lrn: lrn,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        extension: extension,
        sex: sex,
        birthDate: birthDate,
        academicYearId: academicYearId,
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        trackStrand: trackStrand,
        is4ps: is4ps,
      );
      state = const AsyncData(null);
      // Invalidate to refresh the list
      ref.invalidate(studentPageProvider);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateStudent({
    required int id,
    required String lrn,
    required String firstName,
    String? middleName,
    required String lastName,
    String? extension,
    required String sex,
    required DateTime? birthDate,
    int academicYearId = 0,
    int gradeLevel = 0,
    int sectionId = 0,
    String? trackStrand,
    String status = 'Enrolled',
    bool is4ps = false,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(
        id: id,
        lrn: lrn,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        extension: extension,
        sex: sex,
        birthDate: birthDate,
        status: status,
        academicYearId: academicYearId,
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        trackStrand: trackStrand,
        is4ps: is4ps,
      );
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
      ref.invalidate(studentDetailProvider(id));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> setStudentInactive(int id, StudentModel student) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.setStudentInactive(id, student);
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
      ref.invalidate(studentDetailProvider(id));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkEnroll({
    required List<int> studentIds,
    required int academicYearId,
    required int gradeLevel,
    required int sectionId,
    String? trackStrand,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.bulkEnroll(
        studentIds: studentIds,
        academicYearId: academicYearId,
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        trackStrand: trackStrand,
      );
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
      for (final id in studentIds) {
        ref.invalidate(studentDetailProvider(id));
      }
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkGraduate(List<int> studentIds) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.bulkGraduate(studentIds);
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
      for (final id in studentIds) {
        ref.invalidate(studentDetailProvider(id));
      }
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkChangeStatus(
    List<StudentModel> students,
    String newStatus,
  ) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.bulkChangeStatus(students, newStatus);
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
      for (final student in students) {
        ref.invalidate(studentDetailProvider(student.id));
      }
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateEnrollment({
    required int studentId,
    required int enrollmentId,
    required int academicYearId,
    required int gradeLevel,
    required int sectionId,
    String? trackStrand,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.updateEnrollment(
        enrollmentId: enrollmentId,
        academicYearId: academicYearId,
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        trackStrand: trackStrand,
      );
      state = const AsyncData(null);
      ref.invalidate(studentDetailProvider(studentId));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteEnrollment({
    required int studentId,
    required int enrollmentId,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.deleteEnrollment(enrollmentId);
      state = const AsyncData(null);
      ref.invalidate(studentDetailProvider(studentId));
      ref.invalidate(studentPageProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> addEnrollment({
    required int studentId,
    required int academicYearId,
    required int gradeLevel,
    required int sectionId,
    String? trackStrand,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.addEnrollment(
        studentId: studentId,
        academicYearId: academicYearId,
        gradeLevel: gradeLevel,
        sectionId: sectionId,
        trackStrand: trackStrand,
      );
      state = const AsyncData(null);
      ref.invalidate(studentDetailProvider(studentId));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Submits a batch of student records to POST /students/bulk-ocr-import.
  /// Returns the raw result map: { created, skipped, failed, results }
  Future<Map<String, dynamic>> bulkCreateStudents(
    List<Map<String, dynamic>> students,
  ) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      final result = await repo.bulkCreateStudents(students);
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<List<OcrEnrollmentRecord>> scanEnrollmentFromSF(int studentId) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      final result = await repo.scanEnrollmentFromSF(studentId);
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
