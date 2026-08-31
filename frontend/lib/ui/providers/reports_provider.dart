import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/entities/report_models.dart';

// Repository provider
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(),
);

// Selected academic year (null = all years)
final selectedAcademicYearIdProvider =
    NotifierProvider<SelectedYearNotifier, int?>(() => SelectedYearNotifier());

class SelectedYearNotifier extends Notifier<int?> {
  bool _hasExplicitSelection = false;
  bool get hasExplicitSelection => _hasExplicitSelection;

  @override
  int? build() {
    _hasExplicitSelection = false;
    return null;
  }

  void select(int? id) {
    _hasExplicitSelection = true;
    state = id;
  }

  void setDefaultIfUnset(int activeYearId) {
    if (!_hasExplicitSelection && state == null) {
      state = activeYearId;
    }
  }

  void reset() {
    _hasExplicitSelection = false;
    state = null;
  }
}

// Academic years list
final academicYearsProvider = FutureProvider<List<AcademicYear>>((ref) async {
  final list = await ref.read(reportRepositoryProvider).getAcademicYears();
  return List<AcademicYear>.from(list)
    ..sort((a, b) => b.yearRange.compareTo(a.yearRange));
});

// Filter providers
final selectedGradeLevelProvider =
    NotifierProvider<SelectedGradeLevelNotifier, int?>(
      () => SelectedGradeLevelNotifier(),
    );

class SelectedGradeLevelNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  @override
  set state(int? val) => super.state = val;
}

final selectedSectionIdProvider =
    NotifierProvider<SelectedSectionIdNotifier, int?>(
      () => SelectedSectionIdNotifier(),
    );

class SelectedSectionIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  @override
  set state(int? val) => super.state = val;
}

final selectedStatusFilterProvider =
    NotifierProvider<SelectedStatusFilterNotifier, String?>(
      () => SelectedStatusFilterNotifier(),
    );

class SelectedStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  @override
  set state(String? val) => super.state = val;
}

final showOnlyMissingDocsProvider =
    NotifierProvider<ShowOnlyMissingDocsNotifier, bool>(
      () => ShowOnlyMissingDocsNotifier(),
    );

class ShowOnlyMissingDocsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool val) => super.state = val;
}

// ── Filter Panel Visibility ───────────────────────────────────────────────────
final filterPanelExpandedProvider = NotifierProvider<_BoolNotifier, bool>(
  () => _BoolNotifier(initial: true),
);

// ── Missing Docs Filter Visibility ───────────────────────────────────────────
final missingDocsFilterExpandedProvider = NotifierProvider<_BoolNotifier, bool>(
  () => _BoolNotifier(initial: true),
);

// ── Yearly Comparison Filters ─────────────────────────────────────────────────

/// Selected years for yearly comparison (empty = default 4 consecutive years)
final yearlyComparisonSelectedYearsProvider =
    NotifierProvider<SelectedYearsNotifier, Set<String>>(
      () => SelectedYearsNotifier(),
    );

class SelectedYearsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String year) {
    final current = Set<String>.from(state);
    if (current.contains(year)) {
      current.remove(year);
    } else {
      current.add(year);
    }
    state = current;
  }

  void setYears(Set<String> years) => state = years;

  void clear() => state = {};
}

/// Selected statuses for yearly comparison (empty = all statuses)
final yearlyComparisonSelectedStatusesProvider =
    NotifierProvider<SelectedStatusesNotifier, Set<String>>(
      () => SelectedStatusesNotifier(),
    );

class SelectedStatusesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'enrolled', 'inactive', 'dropped', 'graduated', 'transferred'};

  void toggle(String status) {
    final current = Set<String>.from(state);
    if (current.contains(status)) {
      current.remove(status);
    } else {
      current.add(status);
    }
    state = current;
  }

  void selectAll() =>
      state = {'enrolled', 'inactive', 'dropped', 'graduated', 'transferred'};
}

// KPI stats & compliance data — re-fetches when any filter changes
final reportStatsProvider = FutureProvider.autoDispose<ReportStats>((
  ref,
) async {
  final yearId = ref.watch(selectedAcademicYearIdProvider);
  final grade = ref.watch(selectedGradeLevelProvider);
  final sectionId = ref.watch(selectedSectionIdProvider);
  final status = ref.watch(selectedStatusFilterProvider);

  return await ref
      .read(reportRepositoryProvider)
      .getStats(
        academicYearId: yearId,
        gradeLevel: grade,
        sectionId: sectionId,
        status: status,
      );
});

// Sections by academic year
final sectionsByYearProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, int>((ref, yearId) async {
      return await ref.read(reportRepositoryProvider).getSections(yearId);
    });

// Filtered sections list (optionally filtered by selected grade level)
final filteredSectionsProvider =
    Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final yearId = ref.watch(selectedAcademicYearIdProvider);
      if (yearId == null) return [];

      final sectionsAsync = ref.watch(sectionsByYearProvider(yearId));
      final sections = sectionsAsync.asData?.value ?? [];

      final grade = ref.watch(selectedGradeLevelProvider);
      if (grade == null) return sections;

      return sections
          .where((sec) => (sec['grade_level'] as num).toInt() == grade)
          .toList();
    });

// Yearly comparison data
final yearlyComparisonProvider =
    FutureProvider.autoDispose<List<YearlyComparisonData>>((ref) async {
      return await ref.read(reportRepositoryProvider).getYearlyComparison();
    });

// Storage usage data
final storageStatsProvider = FutureProvider.autoDispose<int>((ref) async {
  return await ref.read(reportRepositoryProvider).getStorageUsed();
});

// Selected Academic Year for Transparency Board (null = default to active academic year)
final transparencyBoardYearProvider = StateProvider<int?>((ref) => null);

// DepEd Transparency Board Data provider
final transparencyBoardProvider =
    FutureProvider.autoDispose<TransparencyBoardData>((ref) async {
      final selectedYearId = ref.watch(transparencyBoardYearProvider);
      return await ref
          .read(reportRepositoryProvider)
          .getTransparencyBoardData(academicYearId: selectedYearId);
    });


// ── Internal helper Notifier for simple bool toggles ─────────────────────────
class _BoolNotifier extends Notifier<bool> {
  final bool initial;
  _BoolNotifier({required this.initial});

  @override
  bool build() => initial;

  void toggle() => state = !state;

  @override
  set state(bool val) => super.state = val;
}
