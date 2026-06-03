import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/entities/document_requirement_model.dart';
import '../../domain/entities/folder_model.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

// ============================================================
// Query params for documents
// ============================================================
class DocumentQueryParams {
  final String search;
  final int page;
  final int limit;
  final String status;
  final String documentType;
  final String gradeLevel;
  final String schoolYear;
  // Optional: filter by specific student (for "Open Documents Folder" redirect)
  final int? studentId;

  const DocumentQueryParams({
    this.search = '',
    this.page = 1,
    this.limit = 20,
    this.status = 'All Statuses',
    this.documentType = 'All Types',
    this.gradeLevel = '',
    this.schoolYear = '',
    this.studentId,
  });

  DocumentQueryParams copyWith({
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
    return DocumentQueryParams(
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

// ============================================================
// Opened Folder State
// ============================================================
final openedFolderStudentIdProvider = NotifierProvider<OpenedFolderStudentIdNotifier, int?>(
  OpenedFolderStudentIdNotifier.new,
);

class OpenedFolderStudentIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setStudentId(int? id) => state = id;
}

final documentQueryProvider =
    NotifierProvider<DocumentQueryNotifier, DocumentQueryParams>(
        DocumentQueryNotifier.new);

class DocumentQueryNotifier extends Notifier<DocumentQueryParams> {
  @override
  DocumentQueryParams build() => const DocumentQueryParams();

  void setSearch(String value) => state = state.copyWith(search: value, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
  void setLimit(int limit) => state = state.copyWith(limit: limit, page: 1);
  void setStatus(String status) => state = state.copyWith(status: status, page: 1);
  void setDocumentType(String type) => state = state.copyWith(documentType: type, page: 1);
  void setGradeLevel(String gradeLevel) => state = state.copyWith(gradeLevel: gradeLevel, page: 1);
  void setSchoolYear(String schoolYear) => state = state.copyWith(schoolYear: schoolYear, page: 1);

  /// Navigate to a specific student's documents
  void setStudentId(int? studentId) {
    state = state.copyWith(
      studentId: studentId,
      clearStudentId: studentId == null,
      page: 1,
      search: '',
    );
  }

  void reset() => state = const DocumentQueryParams();
}

// ============================================================
// Document page provider — fetches from /documents with all filters
// OR from /documents/student/:id when studentId is specified
// ============================================================
final documentPageProvider =
    FutureProvider.autoDispose<DocumentPage>((ref) async {
  final query = ref.watch(documentQueryProvider);
  final repo = ref.read(documentRepositoryProvider);

  return repo.getDocuments(
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
// Student-specific documents provider
// ============================================================
final studentDocumentsProvider =
    FutureProvider.family.autoDispose<List<dynamic>, int>((ref, studentId) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getDocumentsByStudent(studentId);
});

// ============================================================
// Folders for all students — list of student root folders
// ============================================================
final studentFoldersProvider =
    FutureProvider.autoDispose<List<FolderModel>>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  // Fetch top-level folders (no parentId filter = all root folders)
  return repo.getFolders();
});

// ============================================================
// Document statuses provider — fetches distinct statuses from backend
// ============================================================
final documentStatusesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getStatuses();
});

// ============================================================
// Requirements providers
// ============================================================
final documentRequirementsProvider =
    FutureProvider.autoDispose<List<DocumentRequirementModel>>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  // Only show enabled requirements in the upload dropdown
  return repo.getRequirements(isEnabled: true);
});

final requirementsSettingsProvider =
    FutureProvider.autoDispose<RequirementsSettings>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getRequirementsSettings();
});

final missingRequirementsProvider =
    FutureProvider.family.autoDispose<MissingRequirements, int>((ref, studentId) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getMissingRequirements(studentId);
});

// ============================================================
// Folder providers
// ============================================================
final foldersProvider =
    FutureProvider.autoDispose<List<FolderModel>>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getFolders();
});

final studentFolderProvider =
    FutureProvider.family.autoDispose<FolderModel, int>((ref, studentId) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getStudentFolder(studentId);
});

// ============================================================
// Print Queue providers
// ============================================================
final printQueueProvider =
    FutureProvider.autoDispose<List<PrintQueueItem>>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getPrintQueue();
});

final printQueueMutationProvider =
    AsyncNotifierProvider<PrintQueueMutationNotifier, void>(
        PrintQueueMutationNotifier.new);

class PrintQueueMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> addToQueue(int documentId) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.addToPrintQueue(documentId);
      state = const AsyncData(null);
      ref.invalidate(printQueueProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> removeFromQueue(int queueId) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.removeFromPrintQueue(queueId);
      state = const AsyncData(null);
      ref.invalidate(printQueueProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> clearQueue() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.clearPrintQueue();
      state = const AsyncData(null);
      ref.invalidate(printQueueProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> executePrint() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.executePrintQueue();
      state = const AsyncData(null);
      ref.invalidate(printQueueProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ============================================================
// Document mutations
// ============================================================
final documentMutationProvider =
    AsyncNotifierProvider<DocumentMutationNotifier, void>(
        DocumentMutationNotifier.new);

class DocumentMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> updateDocumentStatus(int id, String status) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.updateDocumentStatus(id, status);
      state = const AsyncData(null);
      ref.invalidate(documentPageProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteDocument(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.deleteDocument(id);
      state = const AsyncData(null);
      ref.invalidate(documentPageProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> copyDocument(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.copyDocument(id);
      state = const AsyncData(null);
      ref.invalidate(documentPageProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkDelete(List<int> ids) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.bulkDeleteDocuments(ids);
      state = const AsyncData(null);
      ref.invalidate(documentPageProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkUpdateStatus(List<int> ids, String status) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.bulkUpdateStatus(ids, status);
      state = const AsyncData(null);
      ref.invalidate(documentPageProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkAddToPrintQueue(List<int> ids) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.bulkAddToPrintQueue(ids);
      state = const AsyncData(null);
      ref.invalidate(documentPageProvider);
      ref.invalidate(printQueueProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkCopy(List<int> ids) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.bulkCopyDocuments(ids);
      state = const AsyncData(null);
      ref.invalidate(documentPageProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ============================================================
// Requirement mutations
// ============================================================
final requirementMutationProvider =
    AsyncNotifierProvider<RequirementMutationNotifier, void>(
        RequirementMutationNotifier.new);

class RequirementMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> createRequirement(DocumentRequirementModel requirement) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.createRequirement(requirement);
      state = const AsyncData(null);
      ref.invalidate(requirementsSettingsProvider);
      ref.invalidate(documentRequirementsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateRequirement(DocumentRequirementModel requirement) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.updateRequirement(requirement);
      state = const AsyncData(null);
      ref.invalidate(requirementsSettingsProvider);
      ref.invalidate(documentRequirementsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteRequirement(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.deleteRequirement(id);
      state = const AsyncData(null);
      ref.invalidate(requirementsSettingsProvider);
      ref.invalidate(documentRequirementsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkUpdateRequirements(
      List<Map<String, dynamic>> requirements) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.bulkUpdateRequirements(requirements);
      state = const AsyncData(null);
      ref.invalidate(requirementsSettingsProvider);
      ref.invalidate(documentRequirementsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ============================================================
// Folder mutations
// ============================================================
final folderMutationProvider =
    AsyncNotifierProvider<FolderMutationNotifier, void>(
        FolderMutationNotifier.new);

class FolderMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<int> createFolder(
      {required String name,
      int? parentId,
      int? studentId,
      String? category}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      final id = await repo.createFolder(
        name: name,
        parentId: parentId,
        studentId: studentId,
        category: category,
      );
      state = const AsyncData(null);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
      if (studentId != null) {
        ref.invalidate(studentFolderProvider(studentId));
      }
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> renameFolder(int id, String name) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.renameFolder(id, name);
      state = const AsyncData(null);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteFolder(int id, {int? studentId}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.deleteFolder(id);
      state = const AsyncData(null);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
      if (studentId != null) {
        ref.invalidate(studentFolderProvider(studentId));
      }
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> syncFolders(int studentId) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.syncFolders(studentId);
      state = const AsyncData(null);
      ref.invalidate(studentFolderProvider(studentId));
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ============================================================
// Recycle Bin / Trash providers
// ============================================================
final trashDocumentsProvider =
    FutureProvider.autoDispose<List<TrashDocumentModel>>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  return repo.getTrashDocuments();
});

final trashMutationProvider =
    AsyncNotifierProvider<TrashMutationNotifier, void>(
        TrashMutationNotifier.new);

class TrashMutationNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> restoreDocument(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.restoreDocument(id);
      state = const AsyncData(null);
      ref.invalidate(trashDocumentsProvider);
      ref.invalidate(documentPageProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkRestore(List<int> ids) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.bulkRestoreDocuments(ids);
      state = const AsyncData(null);
      ref.invalidate(trashDocumentsProvider);
      ref.invalidate(documentPageProvider);
      ref.invalidate(foldersProvider);
      ref.invalidate(studentFoldersProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> permanentDelete(int id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.permanentDeleteDocument(id);
      state = const AsyncData(null);
      ref.invalidate(trashDocumentsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> bulkPermanentDelete(List<int> ids) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.bulkPermanentDeleteDocuments(ids);
      state = const AsyncData(null);
      ref.invalidate(trashDocumentsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}