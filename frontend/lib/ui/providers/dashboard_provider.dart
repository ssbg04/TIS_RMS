import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/entities/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

class DashboardData {
  final DashboardStats stats;
  final List<PendingTask> pendingTasks;

  DashboardData({required this.stats, required this.pendingTasks});
}

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final repository = ref.read(dashboardRepositoryProvider);
  
  final stats = await repository.getStats();
  final tasks = await repository.getPendingTasks();
  
  return DashboardData(stats: stats, pendingTasks: tasks);
});
