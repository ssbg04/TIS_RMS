import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/users_provider.dart';
import '../../providers/setup_provider.dart';
import '../../../domain/entities/setup_models.dart';
import '../../../domain/entities/system_user.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/modals/custom_modal.dart';

// Fixed grade levels 7-12 — no backend management needed
const List<int> kGradeLevels = [7, 8, 9, 10, 11, 12];

// ============================================================
// TEACHER MANAGEMENT MODAL (entry point — replaces full screen)
// ============================================================
class TeacherManagementModal extends ConsumerStatefulWidget {
  const TeacherManagementModal({super.key});

  static void open(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    if (isAndroid) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeacherManagementModal()),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const TeacherManagementModal(),
      );
    }
  }

  @override
  ConsumerState<TeacherManagementModal> createState() =>
      _TeacherManagementModalState();
}

class _TeacherManagementModalState extends ConsumerState<TeacherManagementModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollingTimer;

  // Tab indices: 0=Teachers, 1=Academic Years, 2=Sections
  static const int _tabCount = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });

    // Polling every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshData();
    });
  }

  void _refreshData() {
    ref.invalidate(usersProvider);
    ref.invalidate(academicYearsListProvider);
    ref.invalidate(sectionsListProvider);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    final content = Column(
      children: [
        _buildTabBar(isAndroid),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_TeachersTab(), _AcademicYearsTab(), _SectionsTab()],
          ),
        ),
      ],
    );

    if (isAndroid) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Row(
            children: [
              Icon(Icons.school, size: 22, color: Colors.white),
              SizedBox(width: 10),
              Text('Teachers & Academic Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    return CustomModal(
      title: 'Teachers & Academic Setup',
      icon: Icons.school,
      maxWidth: 900,
      content: SizedBox(
        height: screenSize.height * 0.8,
        child: content,
      ),
    );
  }

  Widget _buildTabBar(bool isNarrow) {
    return Container(
      color: Colors.grey.shade50,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryGreen,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: isNarrow
            ? const [
                Tab(icon: Icon(Icons.people, size: 20)),
                Tab(icon: Icon(Icons.calendar_today, size: 20)),
                Tab(icon: Icon(Icons.segment, size: 20)),
              ]
            : const [
                Tab(icon: Icon(Icons.people, size: 18), text: 'Teachers'),
                Tab(
                  icon: Icon(Icons.calendar_today, size: 18),
                  text: 'Academic Years',
                ),
                Tab(icon: Icon(Icons.segment, size: 18), text: 'Sections'),
              ],
      ),
    );
  }
}

// ============================================================
// TEACHERS TAB
// ============================================================
class _TeachersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return usersAsync.when(
      data: (users) {
        final teachers = users.where((u) => u.role == 'teacher').toList();
        if (teachers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No teachers found.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create teachers in User Settings.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.p16),
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            return _TeacherCard(teacher: teachers[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading teachers: $e')),
    );
  }
}

class _TeacherCard extends ConsumerWidget {
  final SystemUser teacher;
  const _TeacherCard({required this.teacher});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p8),
      child: Material(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          onTap: () => showDialog(
            context: context,
            builder: (_) => TeacherDetailModal(teacher: teacher),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.p12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryGreen.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    teacher.firstName.isNotEmpty
                        ? teacher.firstName[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${teacher.lastName}, ${teacher.firstName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${teacher.username}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TEACHER DETAIL MODAL
// ============================================================
class TeacherDetailModal extends ConsumerWidget {
  final SystemUser teacher;
  const TeacherDetailModal({super.key, required this.teacher});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherSecsAsync = ref.watch(teacherSectionsProvider(teacher.id));

    return CustomModal(
      title:
          '${teacher.firstName}${teacher.middleName != null ? ' ${teacher.middleName}' : ''} ${teacher.lastName}${teacher.extension != null ? ' ${teacher.extension}' : ''}',
      icon: Icons.person,
      maxWidth: 480,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSizes.p20,
              right: AppSizes.p20,
              top: AppSizes.p16,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryGreen.withValues(
                    alpha: 0.15,
                  ),
                  child: Text(
                    teacher.firstName.isNotEmpty
                        ? teacher.firstName[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '@${teacher.username}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact info
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.p8),
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: teacher.email ?? 'Not set',
                  ),
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: teacher.phone ?? 'Not set',
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Assigned sections
                  const Text(
                    'Assigned Sections',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.p8),
                  teacherSecsAsync.when(
                    data: (sections) {
                      if (sections.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(AppSizes.p12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'No sections assigned yet.',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      // Group by academic year
                      final Map<String, List<SectionModel>> grouped = {};
                      for (var s in sections) {
                        final key = s.academicYearRange ?? 'Unknown Year';
                        grouped.putIfAbsent(key, () => []).add(s);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: grouped.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: entry.value.map((sec) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primaryGreen
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      'G${sec.gradeLevel} – ${sec.name}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => Text(
                      'Error: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p20,
              vertical: AppSizes.p12,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (_) => TeacherSectionsModal(teacher: teacher),
                  );
                },
                icon: const Icon(Icons.edit_note, size: 20),
                label: const Text(
                  'Manage Sections',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACADEMIC YEARS TAB
// ============================================================
class _AcademicYearsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearsAsync = ref.watch(academicYearsListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p16,
            AppSizes.p12,
            AppSizes.p16,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Old/manual academic years are added as Inactive. Activating one deactivates all others.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const AcademicYearFormModal(),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ADD'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: yearsAsync.when(
            data: (years) {
              if (years.isEmpty)
                return const Center(child: Text('No academic years created.'));
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final isActive = year.status == 'active';
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.p8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p12,
                      vertical: AppSizes.p12,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryGreen.withValues(alpha: 0.04)
                          : AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primaryGreen.withValues(alpha: 0.35)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: isActive
                              ? AppColors.primaryGreen
                              : Colors.grey.shade400,
                          size: 18,
                        ),
                        const SizedBox(width: AppSizes.p12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                year.yearRange,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isActive
                                      ? AppColors.primaryGreen
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.success.withValues(
                                          alpha: 0.12,
                                        )
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? AppColors.success
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Colors.blue.shade400,
                            size: 18,
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => AcademicYearFormModal(year: year),
                          ),
                          tooltip: 'Edit',
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            return IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: AppColors.error.withValues(alpha: 0.7),
                                size: 18,
                              ),
                              onPressed: () =>
                                  _confirmDelete(context, ref, year),
                              tooltip: 'Delete',
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AcademicYearModel year,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Academic Year',
          style: TextStyle(color: AppColors.error),
        ),
        content: Text(
          'Delete "${year.yearRange}"? This will also delete all sections in it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(setupMutationProvider.notifier)
                    .deleteAcademicYear(year.id);
                if (!context.mounted) return;
                showSuccessDialog(
                  context,
                  title: 'Deleted',
                  message: '"${year.yearRange}" has been deleted.',
                );
              } catch (e) {
                if (!context.mounted) return;
                showErrorDialog(
                  context,
                  'Deletion Failed',
                  e.toString().replaceAll('Exception: ', ''),
                );
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTIONS TAB (with Academic Year + Grade Level filters)
// ============================================================
class _SectionsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SectionsTab> createState() => _SectionsTabState();
}

class _SectionsTabState extends ConsumerState<_SectionsTab> {
  int? _filterYearId;
  int? _filterGradeLevel;
  bool _filtersInitialized = false;

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsListProvider);
    final yearsAsync = ref.watch(academicYearsListProvider);

    return yearsAsync.when(
      data: (years) {
        // Auto-select the active (or highest) year on first load
        if (!_filtersInitialized && years.isNotEmpty) {
          final active = years.firstWhere(
            (y) => y.status == 'active',
            orElse: () => years.first,
          );
          Future.microtask(() {
            if (mounted) {
              setState(() {
                _filterYearId = active.id;
                _filtersInitialized = true;
              });
            }
          });
        }

        return Column(
          children: [
            // Filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p12,
                AppSizes.p16,
                0,
              ),
              child: Row(
                children: [
                  // Academic year filter
                  Expanded(
                    flex: 3,
                    child: _FilterDropdown<int>(
                      hint: 'All Years',
                      icon: Icons.calendar_today,
                      value: _filterYearId,
                      items: years
                          .map(
                            (y) => DropdownMenuItem<int>(
                              value: y.id,
                              child: Text(
                                y.yearRange,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _filterYearId = v),
                      showClear: _filterYearId != null,
                      onClear: () => setState(() => _filterYearId = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Grade level filter
                  Expanded(
                    flex: 2,
                    child: _FilterDropdown<int>(
                      hint: 'All Grades',
                      icon: Icons.grade,
                      value: _filterGradeLevel,
                      items: kGradeLevels
                          .map(
                            (g) => DropdownMenuItem<int>(
                              value: g,
                              child: Text('Grade $g'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _filterGradeLevel = v),
                      showClear: _filterGradeLevel != null,
                      onClear: () => setState(() => _filterGradeLevel = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => SectionFormModal(
                          defaultAcademicYearId: _filterYearId,
                          defaultGradeLevel: _filterGradeLevel,
                        ),
                      ),
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: sectionsAsync.when(
                data: (sections) {
                  var filtered = sections;
                  if (_filterYearId != null) {
                    filtered = filtered
                        .where((s) => s.academicYearId == _filterYearId)
                        .toList();
                  }
                  if (_filterGradeLevel != null) {
                    filtered = filtered
                        .where((s) => s.gradeLevel == _filterGradeLevel)
                        .toList();
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.segment,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No sections found.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try adjusting the filters or add a new section.',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final section = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSizes.p8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p12,
                          vertical: AppSizes.p12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${section.gradeLevel}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSizes.p12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Grade ${section.gradeLevel} • ${section.academicYearRange ?? ""}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, _) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: Colors.blue.shade400,
                                        size: 18,
                                      ),
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) =>
                                            SectionFormModal(section: section),
                                      ),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: AppColors.error.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 18,
                                      ),
                                      onPressed: () => _confirmDeleteSection(
                                        context,
                                        ref,
                                        section,
                                      ),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _confirmDeleteSection(
    BuildContext context,
    WidgetRef ref,
    SectionModel section,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Section',
          style: TextStyle(color: AppColors.error),
        ),
        content: Text(
          'Are you sure you want to delete section "${section.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(setupMutationProvider.notifier)
                    .deleteSection(section.id);
                if (!context.mounted) return;
                showSuccessDialog(
                  context,
                  title: 'Section Deleted',
                  message: '"${section.name}" has been deleted.',
                );
              } catch (e) {
                if (!context.mounted) return;
                showErrorDialog(
                  context,
                  'Deletion Failed',
                  e.toString().replaceAll('Exception: ', ''),
                );
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

// Generic filter dropdown widget
class _FilterDropdown<T> extends StatelessWidget {
  final String hint;
  final IconData icon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool showClear;
  final VoidCallback? onClear;

  const _FilterDropdown({
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.showClear = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                menuMaxHeight: 300,
                hint: Text(
                  hint,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                isExpanded: true,
                icon: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: showClear
                      ? GestureDetector(
                          onTap: onClear,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                        )
                      : Icon(
                          Icons.expand_more,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                ),
                items: items,
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACADEMIC YEAR FORM MODAL
// ============================================================
class AcademicYearFormModal extends ConsumerStatefulWidget {
  final AcademicYearModel? year;
  const AcademicYearFormModal({super.key, this.year});

  @override
  ConsumerState<AcademicYearFormModal> createState() =>
      _AcademicYearFormModalState();
}

class _AcademicYearFormModalState extends ConsumerState<AcademicYearFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _yearRangeController;
  late String _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _yearRangeController = TextEditingController(
      text: widget.year?.yearRange ?? '',
    );
    // Default: editing keeps current status; adding defaults to inactive (old years)
    _status = widget.year?.status ?? 'inactive';
  }

  @override
  void dispose() {
    _yearRangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.year != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Academic Year' : 'Add Academic Year'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEditing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'New academic years are added as Inactive by default. Set to Active to make it the current year (this will deactivate all others).',
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            CustomTextField(
              hintText: 'Year Range (e.g. 2023-2024)',
              controller: _yearRangeController,
              prefixIcon: Icons.calendar_today,
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Year range is required' : null,
            ),
            const SizedBox(height: AppSizes.p16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.toggle_on_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Active (will deactivate others)'),
                ),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        PrimaryButton(
          label: isEditing ? 'UPDATE' : 'CREATE',
          isLoading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (widget.year != null) {
        await ref
            .read(setupMutationProvider.notifier)
            .updateAcademicYear(
              id: widget.year!.id,
              yearRange: _yearRangeController.text.trim(),
              status: _status,
            );
      } else {
        await ref
            .read(setupMutationProvider.notifier)
            .createAcademicYear(
              yearRange: _yearRangeController.text.trim(),
              status: _status,
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        title: widget.year != null
            ? 'Academic Year Updated'
            : 'Academic Year Created',
        message: widget.year != null
            ? 'Academic year has been successfully updated.'
            : 'Academic year has been successfully created.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        widget.year != null ? 'Update Failed' : 'Creation Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ============================================================
// SECTION FORM MODAL
// ============================================================
class SectionFormModal extends ConsumerStatefulWidget {
  final SectionModel? section;
  final int? defaultAcademicYearId;
  final int? defaultGradeLevel;
  const SectionFormModal({
    super.key,
    this.section,
    this.defaultAcademicYearId,
    this.defaultGradeLevel,
  });

  @override
  ConsumerState<SectionFormModal> createState() => _SectionFormModalState();
}

class _SectionFormModalState extends ConsumerState<SectionFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  int? _selectedGradeLevel;
  int? _selectedAcademicYearId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.section?.name ?? '');
    _selectedGradeLevel =
        widget.section?.gradeLevel ?? widget.defaultGradeLevel;
    _selectedAcademicYearId =
        widget.section?.academicYearId ?? widget.defaultAcademicYearId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.section != null;
    final yearsAsync = ref.watch(academicYearsListProvider);

    return AlertDialog(
      title: Text(isEditing ? 'Edit Section' : 'Add Section'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                hintText: 'Section Name',
                controller: _nameController,
                prefixIcon: Icons.segment,
                validator: (v) => v?.trim().isEmpty == true
                    ? 'Section name is required'
                    : null,
              ),
              const SizedBox(height: AppSizes.p16),
              // Fixed grade levels 7-12
              DropdownButtonFormField<int>(
                initialValue: _selectedGradeLevel,
                decoration: const InputDecoration(
                  labelText: 'Grade Level',
                  prefixIcon: Icon(Icons.grade),
                  border: OutlineInputBorder(),
                ),
                items: kGradeLevels.map((g) {
                  return DropdownMenuItem<int>(
                    value: g,
                    child: Text('Grade $g'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedGradeLevel = v),
                validator: (v) => v == null ? 'Grade level is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),
              yearsAsync.when(
                data: (years) {
                  // Auto-select active year if none selected
                  if (_selectedAcademicYearId == null && years.isNotEmpty) {
                    final active = years.firstWhere(
                      (y) => y.status == 'active',
                      orElse: () => years.first,
                    );
                    _selectedAcademicYearId = active.id;
                  }
                  final validIds = years.map((y) => y.id).toList();
                  final safeYear = validIds.contains(_selectedAcademicYearId)
                      ? _selectedAcademicYearId
                      : null;
                  return DropdownButtonFormField<int>(
                    initialValue: safeYear,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    items: years.map((y) {
                      return DropdownMenuItem<int>(
                        value: y.id,
                        child: Row(
                          children: [
                            Text(y.yearRange),
                            if (y.status == 'active') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedAcademicYearId = v),
                    validator: (v) =>
                        v == null ? 'Academic year is required' : null,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading academic years: $e'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        PrimaryButton(
          label: isEditing ? 'UPDATE' : 'CREATE',
          isLoading: _isLoading,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (widget.section != null) {
        await ref
            .read(setupMutationProvider.notifier)
            .updateSection(
              id: widget.section!.id,
              name: _nameController.text.trim(),
              gradeLevel: _selectedGradeLevel!,
              academicYearId: _selectedAcademicYearId!,
            );
      } else {
        await ref
            .read(setupMutationProvider.notifier)
            .createSection(
              name: _nameController.text.trim(),
              gradeLevel: _selectedGradeLevel!,
              academicYearId: _selectedAcademicYearId!,
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        title: widget.section != null ? 'Section Updated' : 'Section Created',
        message: widget.section != null
            ? 'Section has been successfully updated.'
            : 'Section has been successfully created.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        widget.section != null ? 'Update Failed' : 'Creation Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ============================================================
// TEACHER SECTIONS ASSIGN MODAL
// ============================================================
class TeacherSectionsModal extends ConsumerStatefulWidget {
  final SystemUser teacher;
  const TeacherSectionsModal({super.key, required this.teacher});

  @override
  ConsumerState<TeacherSectionsModal> createState() =>
      _TeacherSectionsModalState();
}

class _TeacherSectionsModalState extends ConsumerState<TeacherSectionsModal> {
  final List<int> _selectedSectionIds = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String _searchQuery = '';
  int? _selectedYearId;

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsListProvider);
    final teacherSecsAsync = ref.watch(
      teacherSectionsProvider(widget.teacher.id),
    );
    final yearsAsync = ref.watch(academicYearsListProvider);

    return CustomModal(
      title: 'Assign Sections',
      icon: Icons.edit_note,
      maxWidth: 600,
      headerActions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            '${widget.teacher.firstName} ${widget.teacher.lastName}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
      content: SizedBox(
        height: 600,
        child: Column(
          children: [
            Expanded(
              child: sectionsAsync.when(
                data: (allSections) {
                  return teacherSecsAsync.when(
                    data: (assignedSections) {
                      if (!_isInitialized) {
                        _selectedSectionIds
                          ..clear()
                          ..addAll(assignedSections.map((s) => s.id));
                        _isInitialized = true;
                      }

                      return yearsAsync.when(
                        data: (years) {
                          if (years.isEmpty)
                            return const Center(
                              child: Text('No academic years found.'),
                            );

                          if (_selectedYearId == null) {
                            final active = years.firstWhere(
                              (y) => y.status == 'active',
                              orElse: () => years.first,
                            );
                            _selectedYearId = active.id;
                          }

                          final activeYearSections = allSections
                              .where((s) => s.academicYearId == _selectedYearId)
                              .toList();

                          return DefaultTabController(
                            length: kGradeLevels.length + 1,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSizes.p16,
                                    AppSizes.p16,
                                    AppSizes.p16,
                                    0,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: CustomTextField(
                                            hintText: 'Search sections...',
                                            prefixIcon: Icons.search,
                                            onChanged: (val) => setState(
                                              () => _searchQuery = val
                                                  .toLowerCase(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _selectedYearId,
                                            icon: const Icon(
                                              Icons.expand_more,
                                              size: 18,
                                              color: AppColors.primaryGreen,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            items: years.map((y) {
                                              return DropdownMenuItem(
                                                value: y.id,
                                                child: Text(
                                                  y.yearRange +
                                                      (y.status == 'active'
                                                          ? ' (Active)'
                                                          : ''),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(
                                                  () => _selectedYearId = val,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TabBar(
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  labelColor: AppColors.primaryGreen,
                                  unselectedLabelColor: Colors.grey.shade600,
                                  indicatorColor: AppColors.primaryGreen,
                                  tabs: [
                                    const Tab(text: 'All'),
                                    ...kGradeLevels.map(
                                      (g) => Tab(text: 'Grade $g'),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      // ALL tab
                                      (() {
                                        final allGradesSections =
                                            activeYearSections.where((s) {
                                              if (_searchQuery.isNotEmpty &&
                                                  !s.name
                                                      .toLowerCase()
                                                      .contains(_searchQuery))
                                                return false;
                                              return true;
                                            }).toList();
                                        if (allGradesSections.isEmpty) {
                                          return Center(
                                            child: Text(
                                              'No sections found',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          );
                                        }
                                        return ListView.builder(
                                          padding: const EdgeInsets.all(
                                            AppSizes.p16,
                                          ),
                                          itemCount: allGradesSections.length,
                                          itemBuilder: (context, index) {
                                            final sec =
                                                allGradesSections[index];
                                            final isChecked =
                                                _selectedSectionIds.contains(
                                                  sec.id,
                                                );
                                            return CheckboxListTile(
                                              activeColor:
                                                  AppColors.primaryGreen,
                                              title: Text(
                                                '${sec.name} (Grade ${sec.gradeLevel})',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                              value: isChecked,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedSectionIds.add(
                                                      sec.id,
                                                    );
                                                  } else {
                                                    _selectedSectionIds.remove(
                                                      sec.id,
                                                    );
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        );
                                      })(),
                                      // INDIVIDUAL Grade tabs
                                      ...kGradeLevels.map((grade) {
                                        final gradeSections = activeYearSections
                                            .where((s) {
                                              if (s.gradeLevel != grade)
                                                return false;
                                              if (_searchQuery.isNotEmpty &&
                                                  !s.name
                                                      .toLowerCase()
                                                      .contains(_searchQuery))
                                                return false;
                                              return true;
                                            })
                                            .toList();

                                        if (gradeSections.isEmpty) {
                                          return Center(
                                            child: Text(
                                              'No sections found for Grade $grade',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          );
                                        }

                                        return ListView.builder(
                                          padding: const EdgeInsets.all(
                                            AppSizes.p16,
                                          ),
                                          itemCount: gradeSections.length,
                                          itemBuilder: (context, index) {
                                            final sec = gradeSections[index];
                                            final isChecked =
                                                _selectedSectionIds.contains(
                                                  sec.id,
                                                );
                                            return CheckboxListTile(
                                              activeColor:
                                                  AppColors.primaryGreen,
                                              title: Text(
                                                sec.name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                              value: isChecked,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedSectionIds.add(
                                                      sec.id,
                                                    );
                                                  } else {
                                                    _selectedSectionIds.remove(
                                                      sec.id,
                                                    );
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Error: $e'),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p20,
                vertical: AppSizes.p12,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMedium,
                          ),
                        ),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: 'SAVE',
                      isLoading: _isLoading,
                      onPressed: _handleSave,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(setupMutationProvider.notifier)
          .updateTeacherSections(
            teacherId: widget.teacher.id,
            sectionIds: _selectedSectionIds,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        title: 'Assignments Saved',
        message: 'Teacher sections have been successfully updated.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Save Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ============================================================
// Keep TeacherManagementScreen as an alias for backward compatibility
// (unused now but prevents any residual reference errors)
// ============================================================
class TeacherManagementScreen extends StatelessWidget {
  const TeacherManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => const TeacherManagementModal();
}
