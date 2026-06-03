import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/entities/dashboard_models.dart';
import 'auth_provider.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

// ── Dashboard data (stats + recent activities preview for home screen) ─────
class DashboardData {
  final DashboardStats stats;
  final PaginatedActivities recentActivities;

  DashboardData({required this.stats, required this.recentActivities});
}

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final repository = ref.read(dashboardRepositoryProvider);
  final user = ref.watch(authProvider).value;
  final isTeacher = user?.role == 'teacher';

  final stats = await repository.getStats();
  final activities = await repository.getRecentActivities(
    page: 1,
    limit: 5,
    // Teachers only see student and document activities on the dashboard preview
    entityTypes: isTeacher ? 'student,document' : null,
  );
  return DashboardData(stats: stats, recentActivities: activities);
});

// ── Full paginated activities (used by RecentActivitiesScreen) ─────────────
class ActivityQueryParams {
  final int page;
  final int limit;
  final String dateFrom;
  final String dateTo;

  const ActivityQueryParams({
    this.page = 1,
    this.limit = 15,
    this.dateFrom = '',
    this.dateTo = '',
  });

  ActivityQueryParams copyWith({
    int? page,
    int? limit,
    String? dateFrom,
    String? dateTo,
  }) {
    return ActivityQueryParams(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
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
  void reset() => state = const ActivityQueryParams();
}

final recentActivitiesPageProvider =
    FutureProvider.autoDispose<PaginatedActivities>((ref) async {
      final query = ref.watch(activityQueryProvider);
      final repo = ref.read(dashboardRepositoryProvider);
      final user = ref.watch(authProvider).value;
      final isTeacher = user?.role == 'teacher';

      return repo.getRecentActivities(
        page: query.page,
        limit: query.limit,
        dateFrom: query.dateFrom.isEmpty ? null : query.dateFrom,
        dateTo: query.dateTo.isEmpty ? null : query.dateTo,
        // Teachers only see student and document activities
        entityTypes: isTeacher ? 'student,document' : null,
      );
    });
