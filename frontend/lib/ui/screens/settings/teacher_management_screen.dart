import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/users_provider.dart';
import '../../providers/setup_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/setup_models.dart';
import '../../../domain/entities/system_user.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/modals/custom_modal.dart';
import 'widgets/bulk_academic_import_modal.dart';

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

  // Tab indices: 0=Academic Structure, 1=Teacher Advisers
  static const int _tabCount = 2;

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
      if (mounted && ref.read(authProvider).value != null) {
        _refreshData();
      }
    });
  }

  void _refreshData() {
    ref.invalidate(usersProvider);
    ref.invalidate(academicYearsListProvider);
    ref.invalidate(sectionsListProvider);
    ref.invalidate(gradeLevelsListProvider);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      children: [
        _buildTabBar(isAndroid),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _AcademicStructureTab(),
              _TeacherAdvisersTab(),
            ],
          ),
        ),
      ],
    );

    if (isAndroid) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkPageBackground : AppColors.surfaceWhite,
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Academic & Class Management',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    return CustomModal(
      title: 'Academic & Class Management',
      maxWidth: 920,
      content: SizedBox(height: screenSize.height * 0.8, child: content),
    );
  }

  Widget _buildTabBar(bool isNarrow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        indicatorColor: AppColors.primaryGreen,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: isNarrow
            ? const [
                Tab(
                  icon: Icon(Icons.account_tree_outlined, size: 18),
                  text: 'Academic',
                ),
                Tab(
                  icon: Icon(Icons.people_alt_outlined, size: 18),
                  text: 'Advisers',
                ),
              ]
            : const [
                Tab(
                  icon: Icon(Icons.account_tree_outlined, size: 18),
                  text: 'Academic Structure',
                ),
                Tab(
                  icon: Icon(Icons.people_alt_outlined, size: 18),
                  text: 'Teacher Advisers',
                ),
              ],
      ),
    );
  }
}

// ============================================================
// TEACHER ADVISERS TAB
// ============================================================
class _TeacherAdvisersTab extends ConsumerStatefulWidget {
  const _TeacherAdvisersTab();

  @override
  ConsumerState<_TeacherAdvisersTab> createState() => _TeacherAdvisersTabState();
}

class _TeacherAdvisersTabState extends ConsumerState<_TeacherAdvisersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return usersAsync.when(
      data: (users) {
        final teachers = users.where((u) => u.role == 'teacher' && u.isActive).toList();
        if (teachers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No active teachers found.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create teachers in User Settings.',
                  style: TextStyle(color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final allSections = sectionsAsync.value ?? [];
        final assignedTeacherIds = allSections.map((s) => s.teacherId).whereType<int>().toSet();
        final assignedCount = teachers.where((t) => assignedTeacherIds.contains(t.id)).length;
        final unassignedCount = teachers.length - assignedCount;

        final filteredTeachers = teachers.where((t) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          final text = '${t.firstName} ${t.lastName} ${t.username}'.toLowerCase();
          return text.contains(q);
        }).toList();

        return Column(
          children: [
            // Search & Stats Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.p16, AppSizes.p12, AppSizes.p16, AppSizes.p8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search teacher name or @username...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${teachers.length} Active Teachers',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.2),
                          ),
                        ),
                        child: Text(
                          '$assignedCount Advisers Assigned',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      if (unassignedCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.25),
                            ),
                          ),
                          child: Text(
                            '$unassignedCount Unassigned',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Teachers List
            Expanded(
              child: filteredTeachers.isEmpty
                  ? Center(
                      child: Text(
                        'No teachers match "$_searchQuery"',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSizes.p16),
                      itemCount: filteredTeachers.length,
                      itemBuilder: (context, index) {
                        final teacher = filteredTeachers[index];
                        final teacherSections = allSections.where((s) => s.teacherId == teacher.id).toList();
                        return _TeacherCard(
                          teacher: teacher,
                          assignedSections: teacherSections,
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading teachers: $e')),
    );
  }
}

class _TeacherCard extends StatefulWidget {
  final SystemUser teacher;
  final List<SectionModel> assignedSections;
  const _TeacherCard({required this.teacher, required this.assignedSections});

  @override
  State<_TeacherCard> createState() => _TeacherCardState();
}

class _TeacherCardState extends State<_TeacherCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = widget.assignedSections;
    const maxVisible = 2;
    final hasOverflow = sections.length > maxVisible;
    final displayed = (_isExpanded || !hasOverflow)
        ? sections
        : sections.take(maxVisible).toList();
    final overflowCount = sections.length - maxVisible;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p8),
      child: Material(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          onTap: () => showDialog(
            context: context,
            builder: (_) => TeacherDetailModal(teacher: widget.teacher),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.p12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                  child: Text(
                    widget.teacher.firstName.isNotEmpty ? widget.teacher.firstName[0].toUpperCase() : 'T',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.teacher.lastName}, ${widget.teacher.firstName}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '@${widget.teacher.username}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Assigned Sections Chips
                      if (sections.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ...displayed.map((s) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.18 : 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.2),
                                  ),
                                ),
                                child: Text(
                                  'G${s.gradeLevel} - ${s.name}${s.academicYearRange != null ? ' (${s.academicYearRange})' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.primaryGreen,
                                  ),
                                ),
                              );
                            }),
                            if (hasOverflow)
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() => _isExpanded = !_isExpanded),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    _isExpanded ? 'Show less' : '+$overflowCount more',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'No sections assigned',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.4 : 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => TeacherSectionsModal(teacher: widget.teacher),
                  ),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Sections', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600, fontSize: 14),
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
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                  Text(
                    'Assigned Sections',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.primaryGreen,
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
                                      color: isDark
                                          ? AppColors.primaryGreen.withValues(alpha: 0.2)
                                          : AppColors.primaryGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.primaryGreen.withValues(alpha: 0.45)
                                            : AppColors.primaryGreen.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      'G${sec.gradeLevel} – ${sec.name}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.primaryGreen,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACADEMIC YEARS OVERVIEW MODAL (Manage all years, dates & activation)
// ============================================================
class AcademicYearsOverviewModal extends ConsumerWidget {
  const AcademicYearsOverviewModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const AcademicYearsOverviewModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearsAsync = ref.watch(academicYearsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomModal(
      title: 'Manage Academic Years',
      icon: Icons.calendar_month,
      maxWidth: 620,
      content: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.p16, AppSizes.p12, AppSizes.p16, AppSizes.p8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Old/manual academic years are added as Inactive. Activating one deactivates all others.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(color: AppColors.primaryGreen),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => BulkAcademicImportModal.show(context),
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Bulk Import', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const AcademicYearFormModal(),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Year', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: yearsAsync.when(
                data: (years) {
                  if (years.isEmpty) {
                    return const Center(child: Text('No academic years created.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.p16),
                    itemCount: years.length,
                    itemBuilder: (context, index) {
                      final year = years[index];
                      final isActive = year.status == 'active';
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSizes.p8),
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primaryGreen.withValues(alpha: isDark ? 0.08 : 0.04)
                              : (isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          border: Border.all(
                            color: isActive
                                ? AppColors.primaryGreen.withValues(alpha: 0.35)
                                : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: isActive
                                  ? AppColors.primaryGreen
                                  : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade400),
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
                                          : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                    ),
                                  ),
                                  if (year.startDate != null || year.endDate != null)
                                    Text(
                                      '${year.startDate ?? ""} to ${year.endDate ?? ""}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextMuted : Colors.grey.shade500,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.success.withValues(alpha: 0.12)
                                          : (isDark ? AppColors.darkSurface2 : Colors.grey.withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isActive
                                            ? AppColors.success
                                            : (isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isActive)
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await ref.read(setupMutationProvider.notifier).updateAcademicYear(
                                          id: year.id,
                                          yearRange: year.yearRange,
                                          status: 'active',
                                          startDate: year.startDate,
                                          endDate: year.endDate,
                                        );
                                    if (context.mounted) {
                                      showSuccessDialog(
                                        context,
                                        title: 'Activated',
                                        message: '"${year.yearRange}" is now the active academic year.',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showErrorDialog(
                                        context,
                                        'Activation Failed',
                                        e.toString().replaceAll('Exception: ', ''),
                                      );
                                    }
                                  }
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                child: const Text('Set Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue.shade400, size: 18),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AcademicYearFormModal(year: year),
                              ),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: AppColors.error.withValues(alpha: 0.7), size: 18),
                              onPressed: () => _confirmDeleteYear(context, ref, year),
                              tooltip: 'Delete',
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
        ),
      ),
    );
  }

  void _confirmDeleteYear(BuildContext context, WidgetRef ref, AcademicYearModel year) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        title: const Text('Delete Academic Year', style: TextStyle(color: AppColors.error)),
        content: Text(
          'Delete "${year.yearRange}"? This will also delete all sections in it.',
          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(setupMutationProvider.notifier).deleteAcademicYear(year.id);
                if (!context.mounted) return;
                showSuccessDialog(context, title: 'Deleted', message: '"${year.yearRange}" has been deleted.');
              } catch (e) {
                if (!context.mounted) return;
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
// ACADEMIC STRUCTURE TAB (Years + Sections + Grade 7-12 + Advisers)
// ============================================================
class _AcademicStructureTab extends ConsumerStatefulWidget {
  const _AcademicStructureTab();

  @override
  ConsumerState<_AcademicStructureTab> createState() => _AcademicStructureTabState();
}

class _AcademicStructureTabState extends ConsumerState<_AcademicStructureTab>
    with SingleTickerProviderStateMixin {
  int? _filterYearId;
  int? _filterGradeLevel;
  bool _filtersInitialized = false;
  late TabController _gradeTabController;

  @override
  void initState() {
    super.initState();
    // 0 = All Grades, 1..6 = Grade 7..12
    _gradeTabController = TabController(length: kGradeLevels.length + 1, vsync: this);
    _gradeTabController.addListener(_onGradeTabChanged);
  }

  void _onGradeTabChanged() {
    if (!_gradeTabController.indexIsChanging) {
      setState(() {
        if (_gradeTabController.index == 0) {
          _filterGradeLevel = null;
        } else {
          _filterGradeLevel = kGradeLevels[_gradeTabController.index - 1];
        }
      });
    }
  }

  @override
  void dispose() {
    _gradeTabController.removeListener(_onGradeTabChanged);
    _gradeTabController.dispose();
    super.dispose();
  }

  void _openAdviserSelector(BuildContext context, SectionModel section) {
    showDialog(
      context: context,
      builder: (_) => _SectionAdviserSelectorModal(section: section),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(sectionsListProvider);
    final yearsAsync = ref.watch(academicYearsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = MediaQuery.of(context).size.width < 700 ||
        Theme.of(context).platform == TargetPlatform.android;

    return yearsAsync.when(
      data: (years) {
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
            // Controls toolbar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.p16,
                AppSizes.p12,
                AppSizes.p16,
                AppSizes.p8,
              ),
              child: isNarrow
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _FilterDropdown<int>(
                                hint: 'All Years',
                                icon: Icons.calendar_today,
                                value: _filterYearId,
                                items: years
                                    .map(
                                      (y) => DropdownMenuItem<int>(
                                        value: y.id,
                                        child: Text(
                                          y.yearRange + (y.status == 'active' ? ' (Active)' : ''),
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
                            SizedBox(
                              height: 42,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  side: const BorderSide(color: AppColors.primaryGreen),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => AcademicYearsOverviewModal.show(context),
                                icon: const Icon(Icons.date_range, size: 16),
                                label: const Text('Manage Years', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 38,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryGreen,
                                    side: const BorderSide(color: AppColors.primaryGreen),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => BulkAcademicImportModal.show(context),
                                  icon: const Icon(Icons.upload_file, size: 16),
                                  label: const Text('Bulk Import', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 38,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => SectionFormModal(
                                      defaultAcademicYearId: _filterYearId,
                                      defaultGradeLevel: _filterGradeLevel,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Section', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
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
                                      y.yearRange + (y.status == 'active' ? ' (Active)' : ''),
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
                        SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(color: AppColors.primaryGreen),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => AcademicYearsOverviewModal.show(context),
                            icon: const Icon(Icons.date_range, size: 16),
                            label: const Text('Manage Years', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(color: AppColors.primaryGreen),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => BulkAcademicImportModal.show(context),
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text('Bulk Import', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => SectionFormModal(
                                defaultAcademicYearId: _filterYearId,
                                defaultGradeLevel: _filterGradeLevel,
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
            ),

            // Grade Tabs Filtering
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                  bottom: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                ),
              ),
              child: TabBar(
                controller: _gradeTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primaryGreen,
                unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                indicatorColor: AppColors.primaryGreen,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                tabs: [
                  const Tab(text: 'All Grades'),
                  ...kGradeLevels.map((g) => Tab(text: 'Grade $g')),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Sections List
            Expanded(
              child: sectionsAsync.when(
                data: (sections) {
                  var filtered = sections;
                  if (_filterYearId != null) {
                    filtered = filtered.where((s) => s.academicYearId == _filterYearId).toList();
                  }
                  if (_filterGradeLevel != null) {
                    filtered = filtered.where((s) => s.gradeLevel == _filterGradeLevel).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.segment,
                            size: 48,
                            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filterGradeLevel != null
                                ? 'No sections found for Grade $_filterGradeLevel.'
                                : 'No sections found.',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try adjusting the academic year or click "+ Section" to add one.',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
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
                      vertical: AppSizes.p4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final section = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSizes.p8),
                        padding: const EdgeInsets.all(AppSizes.p12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Grade level avatar
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.18 : 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'G${section.gradeLevel}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSizes.p12),
                            // Section info & Adviser chip
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        section.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if ((section.academicYearRange ?? '').isNotEmpty)
                                        Text(
                                          section.academicYearRange!,
                                          style: TextStyle(
                                            color: isDark ? AppColors.darkTextMuted : Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Interactive Adviser Chip
                                  _buildAdviserChip(context, section, isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.edit_outlined, color: Colors.blue.shade400, size: 18),
                                  tooltip: 'Edit Section',
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => SectionFormModal(section: section),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.delete_outline, color: AppColors.error.withValues(alpha: 0.7), size: 18),
                                  tooltip: 'Delete Section',
                                  onPressed: () => _confirmDeleteSection(context, ref, section),
                                ),
                              ],
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

  Widget _buildAdviserChip(BuildContext context, SectionModel section, bool isDark) {
    if (section.teacherFullName != null) {
      return InkWell(
        onTap: () => _openAdviserSelector(context, section),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person, size: 13, color: AppColors.primaryGreen),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Adviser: ${section.teacherFullName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.primaryGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.primaryGreen.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _openAdviserSelector(context, section),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_outlined, size: 13, color: Colors.amber.shade700),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'No Adviser Assigned • Click to assign',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSection(
    BuildContext context,
    WidgetRef ref,
    SectionModel section,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
        title: const Text('Delete Section', style: TextStyle(color: AppColors.error)),
        content: Text(
          'Are you sure you want to delete section "${section.name}"?',
          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(setupMutationProvider.notifier).deleteSection(section.id);
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

// ============================================================
// SECTION ADVISER SELECTOR MODAL (1-click quick adviser assignment)
// ============================================================
class _SectionAdviserSelectorModal extends ConsumerStatefulWidget {
  final SectionModel section;
  const _SectionAdviserSelectorModal({required this.section});

  @override
  ConsumerState<_SectionAdviserSelectorModal> createState() =>
      _SectionAdviserSelectorModalState();
}

class _SectionAdviserSelectorModalState
    extends ConsumerState<_SectionAdviserSelectorModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _assignAdviser(int? teacherId, String teacherName) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(setupMutationProvider.notifier).setSectionAdviser(
            sectionId: widget.section.id,
            teacherId: teacherId,
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        title: 'Adviser Updated',
        message: teacherId != null
            ? '$teacherName assigned as adviser for section "${widget.section.name}".'
            : 'Adviser removed from section "${widget.section.name}".',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Failed to Assign Adviser',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomModal(
      title: 'Assign Class Adviser',
      icon: Icons.person_pin_outlined,
      maxWidth: 480,
      content: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Info Card
            Container(
              padding: const EdgeInsets.all(AppSizes.p12),
              margin: const EdgeInsets.fromLTRB(AppSizes.p16, AppSizes.p12, AppSizes.p16, AppSizes.p8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        'G${widget.section.gradeLevel}',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Academic Year: ${widget.section.academicYearRange ?? "Unknown"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.section.teacherFullName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Current: ${widget.section.teacherFullName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search teacher name or username...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),

            // Options List
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  final teachers = users.where((u) => u.role == 'teacher' && u.isActive).toList();
                  final allSections = sectionsAsync.value ?? [];

                  final filteredTeachers = teachers.where((t) {
                    if (_searchQuery.isEmpty) return true;
                    final text = '${t.firstName} ${t.lastName} ${t.username}'.toLowerCase();
                    return text.contains(_searchQuery);
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(AppSizes.p16),
                    children: [
                      // "Unassign / Clear Adviser" Tile
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: widget.section.teacherId == null
                                ? AppColors.primaryGreen
                                : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                          ),
                        ),
                        tileColor: widget.section.teacherId == null
                            ? AppColors.primaryGreen.withValues(alpha: 0.08)
                            : (isDark ? AppColors.darkSurfaceCard : Colors.white),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          child: const Icon(Icons.person_off_outlined, size: 16, color: Colors.grey),
                        ),
                        title: const Text('None (Unassigned)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Leave this section without an adviser', style: TextStyle(fontSize: 11)),
                        trailing: widget.section.teacherId == null
                            ? const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 20)
                            : null,
                        onTap: _isLoading ? null : () => _assignAdviser(null, 'No Adviser'),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Teachers (${filteredTeachers.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      ...filteredTeachers.map((teacher) {
                        final isCurrent = widget.section.teacherId == teacher.id;
                        final advisingCount = allSections.where((s) => s.teacherId == teacher.id).length;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                                : (isDark ? AppColors.darkSurfaceCard : Colors.white),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.primaryGreen
                                  : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                              child: Text(
                                teacher.firstName.isNotEmpty ? teacher.firstName[0].toUpperCase() : 'T',
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            title: Text(
                              '${teacher.lastName}, ${teacher.firstName}',
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '@${teacher.username} • Advises $advisingCount ${advisingCount == 1 ? "section" : "sections"}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 20)
                                : const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: _isLoading
                                ? null
                                : () => _assignAdviser(teacher.id, '${teacher.lastName}, ${teacher.firstName}'),
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading teachers: $e')),
              ),
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(icon, size: 14, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                menuMaxHeight: 300,
                hint: Text(
                  hint,
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500),
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
                            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                          ),
                        )
                      : Icon(
                          Icons.expand_more,
                          size: 18,
                          color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
                        ),
                ),
                items: items,
                onChanged: onChanged,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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

/// Formats text strictly to XXXX-XXXX (e.g. 2025-2026)
class YearRangeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text.length > newValue.text.length) {
      if (oldValue.text.endsWith('-') && newValue.text.length == 4) {
        final shortened = newValue.text.substring(0, 3);
        return TextEditingValue(
          text: shortened,
          selection: TextSelection.collapsed(offset: shortened.length),
        );
      }
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 8) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 4) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AcademicYearFormModalState extends ConsumerState<AcademicYearFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _yearRangeController;
  late String _status;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _yearRangeController = TextEditingController(
      text: widget.year?.yearRange ?? '',
    );
    // Default: editing keeps current status; adding defaults to inactive (old years)
    _status = widget.year?.status ?? 'inactive';
    _startDate = widget.year?.startDate != null ? DateTime.tryParse(widget.year!.startDate!) : null;
    _endDate = widget.year?.endDate != null ? DateTime.tryParse(widget.year!.endDate!) : null;
  }

  String? _formatYmd(DateTime? dt) {
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _yearRangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.year != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow =
        MediaQuery.of(context).size.width < 600 ||
        Theme.of(context).platform == TargetPlatform.android;
    return CustomModal(
      title: isEditing ? 'Edit Academic Year' : 'Add Academic Year',
      icon: Icons.calendar_today,
      maxWidth: 480,
      content: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isNarrow ? 12 : AppSizes.p20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              if (!isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: isDark ? Colors.blueAccent : Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New academic years are added as Inactive by default. Set to Active to make it the current year (this will deactivate all others).',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.blueAccent : Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              CustomTextField(
                hintText: 'Year Range (e.g. 2025-2026)',
                controller: _yearRangeController,
                prefixIcon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                maxLength: 9,
                counterText: '',
                inputFormatters: [
                  YearRangeInputFormatter(),
                ],
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'Year range is required';
                  final regex = RegExp(r'^(\d{4})-(\d{4})$');
                  final match = regex.firstMatch(val);
                  if (match == null) {
                    return 'Invalid format. Use XXXX-XXXX (e.g. 2025-2026)';
                  }
                  final startYear = int.tryParse(match.group(1)!);
                  final endYear = int.tryParse(match.group(2)!);
                  if (startYear == null || endYear == null) {
                    return 'Invalid year format';
                  }
                  if (endYear != startYear + 1) {
                    return 'End year must be start year + 1 ($startYear-${startYear + 1})';
                  }
                  final currentYear = DateTime.now().year;
                  if (startYear > currentYear) {
                    return 'Cannot add future academic year beyond $currentYear-${currentYear + 1}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.p16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  ),
                  color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                ),
                child: SwitchListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  title: Text(
                    _status == 'active'
                        ? 'Active Academic Year'
                        : 'Inactive Academic Year',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    _status == 'active'
                        ? (isNarrow
                            ? 'Active (will deactivate others)'
                            : 'Currently active (will deactivate other years)')
                        : 'Inactive (archived / previous year)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  secondary: Icon(
                    _status == 'active'
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: _status == 'active'
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  value: _status == 'active',
                  activeTrackColor: AppColors.primaryGreen,
                  onChanged: (val) {
                    setState(() {
                      _status = val ? 'active' : 'inactive';
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSizes.p16),
              // Date Range Picker (1 picker only using calendar_date_picker2)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  ),
                  color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final initialDates = <DateTime>[];
                    if (_startDate != null) initialDates.add(_startDate!);
                    if (_endDate != null) initialDates.add(_endDate!);

                    final results = await showCalendarDatePicker2Dialog(
                      context: context,
                      config: CalendarDatePicker2WithActionButtonsConfig(
                        calendarType: CalendarDatePicker2Type.range,
                        firstDate: DateTime(1990),
                        lastDate: DateTime(2100),
                        selectedDayHighlightColor: AppColors.primaryGreen,
                        okButton: const Text('APPLY', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                        cancelButton: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      dialogSize: const Size(325, 400),
                      value: initialDates,
                      borderRadius: BorderRadius.circular(16),
                    );

                    if (results != null && results.isNotEmpty) {
                      setState(() {
                        _startDate = results.first;
                        _endDate = results.length > 1 ? results.last : results.first;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_outlined,
                          size: 20,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (_startDate != null && _endDate != null)
                                ? '${_formatYmd(_startDate)}  to  ${_formatYmd(_endDate)}'
                                : _startDate != null
                                    ? 'Start: ${_formatYmd(_startDate)} (Select End Date)'
                                    : 'Select Academic Year Dates (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              color: (_startDate != null || _endDate != null)
                                  ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                              fontWeight: (_startDate != null || _endDate != null)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_startDate != null || _endDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear dates',
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMedium,
                            ),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: PrimaryButton(
                        label: isEditing ? 'UPDATE' : 'CREATE',
                        isLoading: _isLoading,
                        onPressed: _handleSubmit,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final startStr = _formatYmd(_startDate);
      final endStr = _formatYmd(_endDate);
      if (widget.year != null) {
        await ref
            .read(setupMutationProvider.notifier)
            .updateAcademicYear(
              id: widget.year!.id,
              yearRange: _yearRangeController.text.trim(),
              status: _status,
              startDate: startStr,
              endDate: endStr,
            );
      } else {
        await ref
            .read(setupMutationProvider.notifier)
            .createAcademicYear(
              yearRange: _yearRangeController.text.trim(),
              status: _status,
              startDate: startStr,
              endDate: endStr,
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessDialog(
        context,
        title: widget.year != null
            ? 'Updated'
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
  int? _selectedTeacherId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.section?.name ?? '');
    _selectedGradeLevel =
        widget.section?.gradeLevel ?? widget.defaultGradeLevel;
    _selectedAcademicYearId =
        widget.section?.academicYearId ?? widget.defaultAcademicYearId;
    _selectedTeacherId = widget.section?.teacherId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.section != null;
    final yearsAsync = ref.watch(academicYearsListProvider);
    final usersAsync = ref.watch(usersProvider);
    final isNarrow =
        MediaQuery.of(context).size.width < 600 ||
        Theme.of(context).platform == TargetPlatform.android;

    return CustomModal(
      title: isEditing ? 'Edit Section' : 'Add Section',
      icon: Icons.segment,
      maxWidth: 480,
      content: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isNarrow ? 12 : AppSizes.p20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: AppSizes.p16),
                  // Class Adviser (Optional)
                  usersAsync.when(
                    data: (users) {
                      final teachers = users.where((u) => u.role == 'teacher' && u.isActive).toList();
                      final validTeacherIds = teachers.map((t) => t.id).toList();
                      final safeTeacherId = validTeacherIds.contains(_selectedTeacherId)
                          ? _selectedTeacherId
                          : null;
                      return DropdownButtonFormField<int?>(
                        initialValue: safeTeacherId,
                        decoration: const InputDecoration(
                          labelText: 'Class Adviser (Optional)',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('None (Unassigned)'),
                          ),
                          ...teachers.map((t) {
                            return DropdownMenuItem<int?>(
                              value: t.id,
                              child: Text('${t.lastName}, ${t.firstName} (@${t.username})'),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _selectedTeacherId = v),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              side: BorderSide(
                                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMedium,
                                ),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: PrimaryButton(
                            label: isEditing ? 'UPDATE' : 'CREATE',
                            isLoading: _isLoading,
                            onPressed: _handleSubmit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
              teacherId: _selectedTeacherId,
            );
      } else {
        await ref
            .read(setupMutationProvider.notifier)
            .createSection(
              name: _nameController.text.trim(),
              gradeLevel: _selectedGradeLevel!,
              academicYearId: _selectedAcademicYearId!,
              teacherId: _selectedTeacherId,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                          if (years.isEmpty) {
                            return const Center(
                              child: Text('No academic years found.'),
                            );
                          }

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
                                          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                                          border: Border.all(
                                            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
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
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
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
                                                      .contains(_searchQuery)) {
                                                return false;
                                              }
                                              return true;
                                            }).toList();
                                        if (allGradesSections.isEmpty) {
                                          return Center(
                                            child: Text(
                                              'No sections found',
                                              style: TextStyle(
                                                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
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
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? AppColors.darkTextPrimary : null,
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
                                              if (s.gradeLevel != grade) {
                                                return false;
                                              }
                                              if (_searchQuery.isNotEmpty &&
                                                  !s.name
                                                      .toLowerCase()
                                                      .contains(_searchQuery)) {
                                                return false;
                                              }
                                              return true;
                                            })
                                            .toList();

                                        if (gradeSections.isEmpty) {
                                          return Center(
                                            child: Text(
                                              'No sections found for Grade $grade',
                                              style: TextStyle(
                                                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade500,
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
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? AppColors.darkTextPrimary : null,
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
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMedium,
                            ),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: PrimaryButton(
                        label: 'SAVE',
                        isLoading: _isLoading,
                        onPressed: _handleSave,
                      ),
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
