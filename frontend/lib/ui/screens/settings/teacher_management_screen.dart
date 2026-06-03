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

class TeacherManagementScreen extends ConsumerStatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  ConsumerState<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends ConsumerState<TeacherManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: AppSizes.p24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryGreen,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.people), text: 'Teachers'),
                    Tab(icon: Icon(Icons.calendar_today), text: 'Academic Years'),
                    Tab(icon: Icon(Icons.segment), text: 'Sections'),
                    Tab(icon: Icon(Icons.grade), text: 'Grade Levels'),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTeachersTab(),
                    _buildAcademicYearsTab(),
                    _buildSectionsTab(),
                    _buildGradeLevelsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppSizes.p8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teachers & Academic Setup',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                'Configure academic years, grade levels, sections, and teacher assignments',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TEACHERS TAB
  // ==========================================
  Widget _buildTeachersTab() {
    final usersAsync = ref.watch(usersProvider);

    return usersAsync.when(
      data: (users) {
        final teachers = users.where((u) => u.role == 'teacher').toList();
        if (teachers.isEmpty) {
          return const Center(child: Text('No teachers found. Create teachers in User Settings.'));
        }
        return ListView.builder(
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            final teacher = teachers[index];
            return Container(
              margin: const EdgeInsets.only(bottom: AppSizes.p12),
              padding: const EdgeInsets.all(AppSizes.p16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: AppSizes.p16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${teacher.lastName}, ${teacher.firstName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('@${teacher.username} • ${teacher.email ?? "No Email"}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        // Display assigned sections dynamically
                        Consumer(builder: (context, ref, _) {
                          final teacherSecsAsync = ref.watch(teacherSectionsProvider(teacher.id));
                          return teacherSecsAsync.when(
                            data: (sections) {
                              if (sections.isEmpty) {
                                return const Text('No sections assigned',
                                    style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500));
                              }
                              return Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: sections.map((sec) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      'G${sec.gradeLevel} - ${sec.name} (${sec.academicYearRange ?? ""})',
                                      style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            error: (_, __) => const Text('Error loading sections', style: TextStyle(fontSize: 12, color: Colors.red)),
                          );
                        }),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showManageTeacherSectionsModal(context, teacher),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Manage Sections'),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading teachers: $e')),
    );
  }

  void _showManageTeacherSectionsModal(BuildContext context, SystemUser teacher) {
    showDialog(
      context: context,
      builder: (context) => TeacherSectionsModal(teacher: teacher),
    );
  }

  // ==========================================
  // ACADEMIC YEARS TAB
  // ==========================================
  Widget _buildAcademicYearsTab() {
    final yearsAsync = ref.watch(academicYearsListProvider);

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => _showAcademicYearModal(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Academic Year'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: yearsAsync.when(
            data: (years) {
              if (years.isEmpty) {
                return const Center(child: Text('No academic years created.'));
              }
              return ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.p8),
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.primaryGreen),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(year.yearRange, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: year.status == 'active'
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  year.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: year.status == 'active' ? AppColors.success : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAcademicYearModal(context, year: year),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _confirmDeleteAcademicYear(year),
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

  void _showAcademicYearModal(BuildContext context, {AcademicYearModel? year}) {
    showDialog(
      context: context,
      builder: (context) => AcademicYearFormModal(year: year),
    );
  }

  void _confirmDeleteAcademicYear(AcademicYearModel year) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Academic Year', style: TextStyle(color: AppColors.error)),
        content: Text('Are you sure you want to delete academic year "${year.yearRange}"? This will delete all enrolled students in this academic year.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(setupMutationProvider.notifier).deleteAcademicYear(year.id);
                if (!mounted) return;
                showSuccessDialog(
                  context,
                  title: 'Academic Year Deleted',
                  message: 'Academic year "${year.yearRange}" has been deleted.',
                );
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Deletion Failed', e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTIONS TAB
  // ==========================================
  Widget _buildSectionsTab() {
    final sectionsAsync = ref.watch(sectionsListProvider);

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => _showSectionModal(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Section'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: sectionsAsync.when(
            data: (sections) {
              if (sections.isEmpty) {
                return const Center(child: Text('No sections created.'));
              }
              return ListView.builder(
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.p8),
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.segment, color: AppColors.primaryGreen),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(section.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('Grade ${section.gradeLevel} • Year: ${section.academicYearRange ?? ""}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showSectionModal(context, section: section),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _confirmDeleteSection(section),
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

  void _showSectionModal(BuildContext context, {SectionModel? section}) {
    showDialog(
      context: context,
      builder: (context) => SectionFormModal(section: section),
    );
  }

  void _confirmDeleteSection(SectionModel section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section', style: TextStyle(color: AppColors.error)),
        content: Text('Are you sure you want to delete section "${section.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(setupMutationProvider.notifier).deleteSection(section.id);
                if (!mounted) return;
                showSuccessDialog(
                  context,
                  title: 'Section Deleted',
                  message: 'Section "${section.name}" has been deleted.',
                );
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Deletion Failed', e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GRADE LEVELS TAB
  // ==========================================
  Widget _buildGradeLevelsTab() {
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            onPressed: () => _showGradeLevelModal(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Grade Level'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: gradeLevelsAsync.when(
            data: (grades) {
              if (grades.isEmpty) {
                return const Center(child: Text('No grade levels configured. Default 7-12 are seeded on backend.'));
              }
              return ListView.builder(
                itemCount: grades.length,
                itemBuilder: (context, index) {
                  final grade = grades[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.p8),
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.grade, color: AppColors.primaryGreen),
                        const SizedBox(width: AppSizes.p16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(grade.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('Level: ${grade.level}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showGradeLevelModal(context, grade: grade),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => _confirmDeleteGradeLevel(grade),
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

  void _showGradeLevelModal(BuildContext context, {GradeLevelModel? grade}) {
    showDialog(
      context: context,
      builder: (context) => GradeLevelFormModal(grade: grade),
    );
  }

  void _confirmDeleteGradeLevel(GradeLevelModel grade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Grade Level', style: TextStyle(color: AppColors.error)),
        content: Text('Are you sure you want to delete grade level "${grade.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(setupMutationProvider.notifier).deleteGradeLevel(grade.id);
                if (!mounted) return;
                showSuccessDialog(
                  context,
                  title: 'Grade Level Deleted',
                  message: 'Grade level "${grade.name}" has been deleted.',
                );
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Deletion Failed', e.toString().replaceAll('Exception: ', ''));
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
// ACADEMIC YEAR FORM MODAL
// ============================================================
class AcademicYearFormModal extends ConsumerStatefulWidget {
  final AcademicYearModel? year;
  const AcademicYearFormModal({super.key, this.year});

  @override
  ConsumerState<AcademicYearFormModal> createState() => _AcademicYearFormModalState();
}

class _AcademicYearFormModalState extends ConsumerState<AcademicYearFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _yearRangeController;
  late String _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _yearRangeController = TextEditingController(text: widget.year?.yearRange ?? '');
    _status = widget.year?.status ?? 'active';
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
            CustomTextField(
              hintText: 'Year Range (e.g. 2023-2024)',
              controller: _yearRangeController,
              prefixIcon: Icons.calendar_today,
              validator: (v) => v?.trim().isEmpty == true ? 'Year range is required' : null,
            ),
            const SizedBox(height: AppSizes.p16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.toggle_on_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
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
        await ref.read(setupMutationProvider.notifier).updateAcademicYear(
              id: widget.year!.id,
              yearRange: _yearRangeController.text.trim(),
              status: _status,
            );
      } else {
        await ref.read(setupMutationProvider.notifier).createAcademicYear(
              yearRange: _yearRangeController.text.trim(),
              status: _status,
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        title: widget.year != null ? 'Academic Year Updated' : 'Academic Year Created',
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
  const SectionFormModal({super.key, this.section});

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
    _selectedGradeLevel = widget.section?.gradeLevel;
    _selectedAcademicYearId = widget.section?.academicYearId;
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
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);

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
                validator: (v) => v?.trim().isEmpty == true ? 'Section name is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),
              gradeLevelsAsync.when(
                data: (grades) {
                  final validGrades = grades.map((g) => g.level).toList();
                  final safeGrade = validGrades.contains(_selectedGradeLevel) ? _selectedGradeLevel : null;
                  return DropdownButtonFormField<int>(
                    value: safeGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade Level',
                      prefixIcon: Icon(Icons.grade),
                      border: OutlineInputBorder(),
                    ),
                    items: grades.map((g) {
                      return DropdownMenuItem<int>(value: g.level, child: Text(g.name));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedGradeLevel = v),
                    validator: (v) => v == null ? 'Grade level is required' : null,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading grade levels: $e'),
              ),
              const SizedBox(height: AppSizes.p16),
              yearsAsync.when(
                data: (years) {
                  final validYears = years.map((y) => y.id).toList();
                  final safeYear = validYears.contains(_selectedAcademicYearId) ? _selectedAcademicYearId : null;
                  return DropdownButtonFormField<int>(
                    value: safeYear,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    items: years.map((y) {
                      return DropdownMenuItem<int>(value: y.id, child: Text(y.yearRange));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedAcademicYearId = v),
                    validator: (v) => v == null ? 'Academic year is required' : null,
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
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
        await ref.read(setupMutationProvider.notifier).updateSection(
              id: widget.section!.id,
              name: _nameController.text.trim(),
              gradeLevel: _selectedGradeLevel!,
              academicYearId: _selectedAcademicYearId!,
            );
      } else {
        await ref.read(setupMutationProvider.notifier).createSection(
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
// GRADE LEVEL FORM MODAL
// ============================================================
class GradeLevelFormModal extends ConsumerStatefulWidget {
  final GradeLevelModel? grade;
  const GradeLevelFormModal({super.key, this.grade});

  @override
  ConsumerState<GradeLevelFormModal> createState() => _GradeLevelFormModalState();
}

class _GradeLevelFormModalState extends ConsumerState<GradeLevelFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _levelController;
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController(text: widget.grade?.level.toString() ?? '');
    _nameController = TextEditingController(text: widget.grade?.name ?? '');
  }

  @override
  void dispose() {
    _levelController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.grade != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Grade Level' : 'Add Grade Level'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              hintText: 'Level Integer (e.g. 7)',
              controller: _levelController,
              prefixIcon: Icons.numbers,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Level is required';
                if (int.tryParse(v) == null) return 'Must be a valid integer';
                return null;
              },
            ),
            const SizedBox(height: AppSizes.p16),
            CustomTextField(
              hintText: 'Name (e.g. Grade 7)',
              controller: _nameController,
              prefixIcon: Icons.grade,
              validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
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
      final lvl = int.parse(_levelController.text.trim());
      if (widget.grade != null) {
        await ref.read(setupMutationProvider.notifier).updateGradeLevel(
              id: widget.grade!.id,
              level: lvl,
              name: _nameController.text.trim(),
            );
      } else {
        await ref.read(setupMutationProvider.notifier).createGradeLevel(
              level: lvl,
              name: _nameController.text.trim(),
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        title: widget.grade != null ? 'Grade Level Updated' : 'Grade Level Created',
        message: widget.grade != null
            ? 'Grade level has been successfully updated.'
            : 'Grade level has been successfully created.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        widget.grade != null ? 'Update Failed' : 'Creation Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ============================================================
// TEACHER SECTIONS MULTI-SELECT MODAL
// ============================================================
class TeacherSectionsModal extends ConsumerStatefulWidget {
  final SystemUser teacher;
  const TeacherSectionsModal({super.key, required this.teacher});

  @override
  ConsumerState<TeacherSectionsModal> createState() => _TeacherSectionsModalState();
}

class _TeacherSectionsModalState extends ConsumerState<TeacherSectionsModal> {
  final List<int> _selectedSectionIds = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsListProvider);
    final teacherSecsAsync = ref.watch(teacherSectionsProvider(widget.teacher.id));

    return AlertDialog(
      title: Text('Assign Sections to ${widget.teacher.firstName} ${widget.teacher.lastName}'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: sectionsAsync.when(
          data: (allSections) {
            return teacherSecsAsync.when(
              data: (assignedSections) {
                if (!_isInitialized) {
                  _selectedSectionIds.clear();
                  _selectedSectionIds.addAll(assignedSections.map((s) => s.id));
                  _isInitialized = true;
                }

                if (allSections.isEmpty) {
                  return const Center(child: Text('No sections available to assign.'));
                }

                // Group sections by Academic Year for neat presentation
                final Map<String, List<SectionModel>> grouped = {};
                for (var sec in allSections) {
                  final key = sec.academicYearRange ?? 'No Academic Year';
                  if (!grouped.containsKey(key)) grouped[key] = [];
                  grouped[key]!.add(sec);
                }

                return ListView(
                  children: grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 15),
                          ),
                        ),
                        const Divider(),
                        ...entry.value.map((sec) {
                          final isChecked = _selectedSectionIds.contains(sec.id);
                          return CheckboxListTile(
                            activeColor: AppColors.primaryGreen,
                            title: Text('${sec.name} - Grade ${sec.gradeLevel}'),
                            value: isChecked,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedSectionIds.add(sec.id);
                                } else {
                                  _selectedSectionIds.remove(sec.id);
                                }
                              });
                            },
                          );
                        }),
                        const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading teacher sections: $e'),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading sections: $e'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        PrimaryButton(
          label: 'SAVE ASSIGNMENTS',
          isLoading: _isLoading,
          onPressed: _handleSave,
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(setupMutationProvider.notifier).updateTeacherSections(
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
