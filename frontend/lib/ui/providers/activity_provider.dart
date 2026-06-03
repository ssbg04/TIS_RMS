import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/entities/dashboard_models.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository();
});

// ── User History query state ───────────────────────────────────────────────
class UserHistoryQueryParams {
  final int page;
  final int limit;
  final String dateFrom;
  final String dateTo;

  const UserHistoryQueryParams({
    this.page = 1,
    this.limit = 20,
    this.dateFrom = '',
    this.dateTo = '',
  });

  UserHistoryQueryParams copyWith({
    int? page,
    int? limit,
    String? dateFrom,
    String? dateTo,
  }) {
    return UserHistoryQueryParams(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }
}

final userHistoryQueryProvider =
    NotifierProvider.autoDispose<
      UserHistoryQueryNotifier,
      UserHistoryQueryParams
    >(UserHistoryQueryNotifier.new);

class UserHistoryQueryNotifier
    extends Notifier<UserHistoryQueryParams> {
  @override
  UserHistoryQueryParams build() => const UserHistoryQueryParams();

  void setPage(int page) => state = state.copyWith(page: page);
  void setDateFrom(String v) => state = state.copyWith(dateFrom: v, page: 1);
  void setDateTo(String v) => state = state.copyWith(dateTo: v, page: 1);
  void reset() => state = const UserHistoryQueryParams();
}

final userHistoryPageProvider =
    FutureProvider.autoDispose<PaginatedUserHistory>((ref) async {
      final query = ref.watch(userHistoryQueryProvider);
      final repo = ref.read(activityRepositoryProvider);
      return repo.getUserHistory(
        page: query.page,
        limit: query.limit,
        dateFrom: query.dateFrom.isEmpty ? null : query.dateFrom,
        dateTo: query.dateTo.isEmpty ? null : query.dateTo,
      );
    });
