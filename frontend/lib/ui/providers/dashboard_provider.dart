import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/entities/dashboard_models.dart';
import 'auth_provider.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

// ── Dashboard data (stats + recent activities preview for home screen) ─────
class DashboardData {
  final DashboardStats stats;
  final PaginatedActivities recentActivities;
  final PaginatedUserHistory? userHistory;

  DashboardData({
    required this.stats,
    required this.recentActivities,
    this.userHistory,
  });
}

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final repository = ref.read(dashboardRepositoryProvider);
  final activityRepo = ActivityRepository();
  final user = ref.read(authProvider).value;
  final isTeacher = user?.role == 'teacher';

  final stats = await repository.getStats();
  final activities = await repository.getRecentActivities(
    page: 1,
    limit: 5,
    // Teachers only see student and document activities on the dashboard preview
    entityTypes: isTeacher ? 'student,document' : null,
  );
  PaginatedUserHistory? userHistory;
  if (!isTeacher) {
    userHistory = await activityRepo.getUserHistory(page: 1, limit: 5);
  }

  return DashboardData(
    stats: stats,
    recentActivities: activities,
    userHistory: userHistory,
  );
});

// ── KPI chart data (all 7 chart datasets) ──────────────────────────────────
final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) async {
  final repository = ref.read(dashboardRepositoryProvider);
  return repository.getKpis();
});

// ── Full paginated activities (used by RecentActivitiesScreen) ─────────────
class ActivityQueryParams {
  final int page;
  final int limit;
  final String dateFrom;
  final String dateTo;
  final String action;
  final String entityTypes;

  const ActivityQueryParams({
    this.page = 1,
    this.limit = 15,
    this.dateFrom = '',
    this.dateTo = '',
    this.action = '',
    this.entityTypes = '',
  });

  ActivityQueryParams copyWith({
    int? page,
    int? limit,
    String? dateFrom,
    String? dateTo,
    String? action,
    String? entityTypes,
  }) {
    return ActivityQueryParams(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      action: action ?? this.action,
      entityTypes: entityTypes ?? this.entityTypes,
    );
  }
}

final activityQueryProvider =
    NotifierProvider.autoDispose<ActivityQueryNotifier, ActivityQueryParams>(
      ActivityQueryNotifier.new,
    );

class ActivityQueryNotifier extends Notifier<ActivityQueryParams> {
  @override
  ActivityQueryParams build() => const ActivityQueryParams();

  void setPage(int page) => state = state.copyWith(page: page);
  void setDateFrom(String v) => state = state.copyWith(dateFrom: v, page: 1);
  void setDateTo(String v) => state = state.copyWith(dateTo: v, page: 1);
  void setAction(String v) => state = state.copyWith(action: v, page: 1);
  void setEntityTypes(String v) =>
      state = state.copyWith(entityTypes: v, page: 1);
  void reset() => state = const ActivityQueryParams();
}

final recentActivitiesPageProvider =
    FutureProvider.autoDispose<PaginatedActivities>((ref) async {
      final query = ref.watch(activityQueryProvider);
      final repo = ref.read(dashboardRepositoryProvider);
      final user = ref.read(authProvider).value;
      final isTeacher = user?.role == 'teacher';

      return repo.getRecentActivities(
        page: query.page,
        limit: query.limit,
        dateFrom: query.dateFrom.isEmpty ? null : query.dateFrom,
        dateTo: query.dateTo.isEmpty ? null : query.dateTo,
        action: query.action.isEmpty ? null : query.action,
        // Teachers only see student and document activities
        entityTypes: isTeacher
            ? 'student,document'
            : (query.entityTypes.isEmpty ? null : query.entityTypes),
      );
    });
