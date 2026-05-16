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

  AcademicYear({required this.id, required this.yearRange, required this.status});

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
final academicYearsProvider = FutureProvider.autoDispose<List<AcademicYear>>((ref) async {
  final storage = const FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

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
final studentDetailProvider = FutureProvider.family.autoDispose<StudentModel, int>((ref, studentId) async {
  final repo = ref.read(studentRepositoryProvider);
  return repo.getStudentById(studentId);
});

// ============================================================
// Query params state — drives what the list shows
// ============================================================
class StudentQueryParams {
  final String search;
  final int    page;
  final int    limit;
  final String gradeLevel; // '' = All
  final String status;     // '' = All

  const StudentQueryParams({
    this.search     = '',
    this.page       = 1,
    this.limit      = 10,
    this.gradeLevel = '',
    this.status     = '',
  });

  StudentQueryParams copyWith({
    String? search,
    int?    page,
    int?    limit,
    String? gradeLevel,
    String? status,
  }) {
    return StudentQueryParams(
      search:     search     ?? this.search,
      page:       page       ?? this.page,
      limit:      limit      ?? this.limit,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      status:     status     ?? this.status,
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
      state = state.copyWith(gradeLevel: grade, page: 1);

  void setStatus(String status) =>
      state = state.copyWith(status: status, page: 1);

  void reset() => state = const StudentQueryParams();
}

// ============================================================
// Async data provider — re-fetches when query changes
// ============================================================
final studentPageProvider = FutureProvider.autoDispose<StudentPage>((ref) async {
  final query = ref.watch(studentQueryProvider);
  final repo  = ref.read(studentRepositoryProvider);

  return repo.getStudents(
    search:     query.search,
    page:       query.page,
    limit:      query.limit,
    gradeLevel: query.gradeLevel,
    status:     query.status,
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

  Future<void> createStudent({
    required String   lrn,
    required String   firstName,
    String?           middleName,
    required String   lastName,
    String?           extension,
    required String   sex,
    required DateTime birthDate,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.createStudent(
        lrn:        lrn,
        firstName:  firstName,
        middleName: middleName,
        lastName:   lastName,
        extension:  extension,
        sex:        sex,
        birthDate:  birthDate,
      );
      state = const AsyncData(null);
      // Invalidate to refresh the list
      ref.invalidate(studentPageProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateStudent({
    required int      id,
    required String   lrn,
    required String   firstName,
    String?           middleName,
    required String   lastName,
    String?           extension,
    required String   sex,
    required DateTime birthDate,
    String            status = 'Enrolled',
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.updateStudent(
        id:         id,
        lrn:        lrn,
        firstName:  firstName,
        middleName: middleName,
        lastName:   lastName,
        extension:  extension,
        sex:        sex,
        birthDate:  birthDate,
        status:     status,
      );
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteStudent(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.deleteStudent(id);
      state = const AsyncData(null);
      ref.invalidate(studentPageProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
