import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../../domain/entities/student_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/modals/custom_modal.dart';
import '../../documents/widgets/student_profile_modal.dart';

class SectionRosterModal extends ConsumerStatefulWidget {
  final SectionModel section;

  const SectionRosterModal({
    super.key,
    required this.section,
  });

  static Future<void> show(BuildContext context, {required SectionModel section}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => SectionRosterModal(section: section),
    );
  }

  @override
  ConsumerState<SectionRosterModal> createState() => _SectionRosterModalState();
}

class _SectionRosterModalState extends ConsumerState<SectionRosterModal> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).value;
    final userRole = user?.role ?? 'teacher';

    final query = SectionRosterQuery(
      section: widget.section.name,
      gradeLevel: widget.section.gradeLevel.toString(),
      schoolYear: widget.section.academicYearRange ?? '',
      search: _searchQuery,
      limit: 100,
    );

    final rosterAsync = ref.watch(sectionRosterProvider(query));

    return CustomModal(
      title: 'Grade ${widget.section.gradeLevel} – ${widget.section.name}',
      icon: Icons.groups_rounded,
      maxWidth: 640,
      content: SizedBox(
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section Info Card
            Container(
              margin: const EdgeInsets.fromLTRB(AppSizes.p20, AppSizes.p12, AppSizes.p20, AppSizes.p8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.class_outlined,
                      size: 20,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Grade ${widget.section.gradeLevel} - ${widget.section.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (widget.section.academicYearRange != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.section.academicYearRange!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Adviser: ${widget.section.teacherFullName ?? "Unassigned"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search student name or LRN...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.darkPageBackground : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Roster List Area
            Expanded(
              child: rosterAsync.when(
                data: (studentPage) {
                  final students = studentPage.students;
                  if (students.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.p24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.group_off_outlined,
                              size: 48,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No learners found matching "$_searchQuery"'
                                  : 'No students enrolled in this section yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                child: const Text('Clear search'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Subheader count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Learners (${studentPage.total})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Tap learner to view profile',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // List of students
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: 8),
                          itemCount: students.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final student = students[index];
                            return _StudentItemCard(
                              student: student,
                              userRole: userRole,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.p20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load student roster',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(sectionRosterProvider(query)),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentItemCard extends StatelessWidget {
  final StudentModel student;
  final String userRole;
  final bool isDark;

  const _StudentItemCard({
    required this.student,
    required this.userRole,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          showStudentProfileModal(
            context,
            studentId: student.id,
            userRole: userRole,
            hideEnrollmentActions: userRole != 'admin',
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              // Avatar with initial
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                child: Text(
                  student.lastName.isNotEmpty ? student.lastName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name and LRN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'LRN: ${student.lrn}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        if (student.sex.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '•  ${student.sex}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 4Ps Badge if applicable
              if (student.is4ps) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '4Ps',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],

              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: student.status.toLowerCase() == 'enrolled'
                      ? AppColors.primaryGreen.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  student.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: student.status.toLowerCase() == 'enrolled'
                        ? AppColors.primaryGreen
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Arrow
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
