import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/archive_repository.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/entities/folder_model.dart';

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  return ArchiveRepository();
});

// ============================================================
// Legacy student-level archive query (kept for backward compat)
// ============================================================
class ArchiveQueryParams {
  final String search;
  final int page;
  final int limit;
  final String status;

  const ArchiveQueryParams({
    this.search = '',
    this.page = 1,
    this.limit = 10,
    this.status = 'All Statuses',
  });

  ArchiveQueryParams copyWith({
    String? search,
    int? page,
    int? limit,
    String? status,
  }) {
    return ArchiveQueryParams(
      search: search ?? this.search,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      status: status ?? this.status,
    );
  }
}

final archiveQueryProvider = NotifierProvider<ArchiveQueryNotifier, ArchiveQueryParams>(ArchiveQueryNotifier.new);

class ArchiveQueryNotifier extends Notifier<ArchiveQueryParams> {
  @override
  ArchiveQueryParams build() => const ArchiveQueryParams();

  void setSearch(String value) => state = state.copyWith(search: value, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
  void setLimit(int limit) => state = state.copyWith(limit: limit, page: 1);
  void setStatus(String status) => state = state.copyWith(status: status, page: 1);
  void reset() => state = const ArchiveQueryParams();
}

final archivePageProvider = FutureProvider.autoDispose<ArchivePage>((ref) async {
  final query = ref.watch(archiveQueryProvider);
  final repo = ref.read(archiveRepositoryProvider);

  return repo.getArchives(
    search: query.search,
    page: query.page,
    limit: query.limit,
    status: query.status,
  );
});

final archiveMutationProvider = AsyncNotifierProvider<ArchiveMutationNotifier, void>(ArchiveMutationNotifier.new);

class ArchiveMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> restoreArchive(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(archiveRepositoryProvider);
      await repo.restoreArchive(id);
      state = const AsyncData(null);
      ref.invalidate(archivePageProvider);
      ref.invalidate(archiveDocumentPageProvider);
      ref.invalidate(archiveStudentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> purgeArchive(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(archiveRepositoryProvider);
      await repo.purgeArchive(id);
      state = const AsyncData(null);
      ref.invalidate(archivePageProvider);
      ref.invalidate(archiveDocumentPageProvider);
      ref.invalidate(archiveStudentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ============================================================
// New: Document-centric archive query params
// ============================================================
class ArchiveDocumentQueryParams {
  final String search;
  final int page;
  final int limit;
  final String status;        // student status filter
  final String documentType;
  final String gradeLevel;
  final String schoolYear;
  final int? studentId;

  const ArchiveDocumentQueryParams({
    this.search = '',
    this.page = 1,
    this.limit = 20,
    this.status = 'All Statuses',
    this.documentType = 'All Types',
    this.gradeLevel = '',
    this.schoolYear = '',
    this.studentId,
  });

  ArchiveDocumentQueryParams copyWith({
    String? search,
    int? page,
    int? limit,
    String? status,
    String? documentType,
    String? gradeLevel,
    String? schoolYear,
    int? studentId,
    bool clearStudentId = false,
  }) {
    return ArchiveDocumentQueryParams(
      search: search ?? this.search,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      status: status ?? this.status,
      documentType: documentType ?? this.documentType,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      schoolYear: schoolYear ?? this.schoolYear,
      studentId: clearStudentId ? null : (studentId ?? this.studentId),
    );
  }
}

final archiveDocumentQueryProvider =
    NotifierProvider<ArchiveDocumentQueryNotifier, ArchiveDocumentQueryParams>(
  ArchiveDocumentQueryNotifier.new,
);

class ArchiveDocumentQueryNotifier extends Notifier<ArchiveDocumentQueryParams> {
  @override
  ArchiveDocumentQueryParams build() => const ArchiveDocumentQueryParams();

  void setSearch(String value) => state = state.copyWith(search: value, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
  void setLimit(int limit) => state = state.copyWith(limit: limit, page: 1);
  void setStatus(String status) => state = state.copyWith(status: status, page: 1);
  void setDocumentType(String type) => state = state.copyWith(documentType: type, page: 1);
  void setGradeLevel(String gradeLevel) => state = state.copyWith(gradeLevel: gradeLevel, page: 1);
  void setSchoolYear(String schoolYear) => state = state.copyWith(schoolYear: schoolYear, page: 1);
  void setStudentId(int? studentId) => state = state.copyWith(
        studentId: studentId,
        clearStudentId: studentId == null,
        page: 1,
        search: '',
      );
  void reset() => state = const ArchiveDocumentQueryParams();
}

// ============================================================
// New: Paginated archived documents
// ============================================================
final archiveDocumentPageProvider =
    FutureProvider.autoDispose<DocumentPage>((ref) async {
  final query = ref.watch(archiveDocumentQueryProvider);
  final repo = ref.read(archiveRepositoryProvider);
  return repo.getArchivedDocuments(
    search: query.search,
    page: query.page,
    limit: query.limit,
    status: query.status,
    documentType: query.documentType,
    gradeLevel: query.gradeLevel,
    schoolYear: query.schoolYear,
    studentId: query.studentId,
  );
});

// ============================================================
// New: Student folders for archived students (Graduated/Transferred/Dropped)
// ============================================================
final archiveStudentFoldersProvider =
    FutureProvider.autoDispose<List<FolderModel>>((ref) async {
  final query = ref.watch(archiveDocumentQueryProvider);
  final repo = ref.read(archiveRepositoryProvider);
  return repo.getArchivedStudentFolders(
    search: query.search,
    status: query.status,
  );
});
