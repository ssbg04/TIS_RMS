import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/archive_repository.dart';

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  return ArchiveRepository();
});

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
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
