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
  final String action;
  final String role;

  const UserHistoryQueryParams({
    this.page = 1,
    this.limit = 20,
    this.dateFrom = '',
    this.dateTo = '',
    this.action = '',
    this.role = '',
  });

  UserHistoryQueryParams copyWith({
    int? page,
    int? limit,
    String? dateFrom,
    String? dateTo,
    String? action,
    String? role,
  }) {
    return UserHistoryQueryParams(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      action: action ?? this.action,
      role: role ?? this.role,
    );
  }
}

final userHistoryQueryProvider =
    NotifierProvider.autoDispose<
      UserHistoryQueryNotifier,
      UserHistoryQueryParams
    >(UserHistoryQueryNotifier.new);

class UserHistoryQueryNotifier
    extends AutoDisposeNotifier<UserHistoryQueryParams> {
  @override
  UserHistoryQueryParams build() => const UserHistoryQueryParams();

  void setPage(int page) => state = state.copyWith(page: page);
  void setLimit(int limit) => state = state.copyWith(limit: limit, page: 1);
  void setDateFrom(String v) => state = state.copyWith(dateFrom: v, page: 1);
  void setDateTo(String v) => state = state.copyWith(dateTo: v, page: 1);
  void setAction(String v) => state = state.copyWith(action: v, page: 1);
  void setRole(String v) => state = state.copyWith(role: v, page: 1);
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
        action: query.action.isEmpty ? null : query.action,
        role: query.role.isEmpty ? null : query.role,
      );
    });
