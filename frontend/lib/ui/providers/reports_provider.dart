import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/entities/report_models.dart';

// Repository provider
final reportRepositoryProvider = Provider<ReportRepository>((ref) => ReportRepository());

// Selected academic year (null = all years)
final selectedAcademicYearIdProvider = NotifierProvider<SelectedYearNotifier, int?>(() => SelectedYearNotifier());

class SelectedYearNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}

// Academic years list
final academicYearsProvider = FutureProvider<List<AcademicYear>>((ref) async {
  return await ref.read(reportRepositoryProvider).getAcademicYears();
});

// KPI stats — re-fetches when selected year changes
final reportStatsProvider = FutureProvider.autoDispose<ReportStats>((ref) async {
  final yearId = ref.watch(selectedAcademicYearIdProvider);
  return await ref.read(reportRepositoryProvider).getStats(academicYearId: yearId);
});

// Enrollment by grade — re-fetches when selected year changes
final enrollmentByGradeProvider = FutureProvider.autoDispose<List<GradeEnrollment>>((ref) async {
  final yearId = ref.watch(selectedAcademicYearIdProvider);
  return await ref.read(reportRepositoryProvider).getEnrollmentByGrade(academicYearId: yearId);
});

// Document status (global, not filtered by year)
final documentStatusProvider = FutureProvider.autoDispose<DocumentStatus>((ref) async {
  return await ref.read(reportRepositoryProvider).getDocumentStatus();
});

// Full export data — triggered manually, not auto-watched
final reportExportDataProvider = FutureProvider.autoDispose.family<ReportExportData, int?>((ref, yearId) async {
  return await ref.read(reportRepositoryProvider).getExportData(academicYearId: yearId);
});
