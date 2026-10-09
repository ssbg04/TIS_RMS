import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../documents/widgets/student_profile_modal.dart';
import '../../documents/widgets/upload_ocr_modal.dart';
import '../../../../domain/entities/student_model.dart';

/// "Needs Attention" operational card for Dashboard (Priority 4).
/// Shows missing SF9, missing SF10, documents requiring verification,
/// and immediate action links directly to student targets.
class NeedsAttentionCard extends ConsumerWidget {
  const NeedsAttentionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).value;
    final userRole = user?.role ?? 'teacher';

    final kpisAsync = ref.watch(dashboardKpisProvider);
    final studentsAsync = ref.watch(enrolledStudentsForRequirementsProvider);

    final enrolledStudents = studentsAsync.asData?.value ?? [];
    final kpis = kpisAsync.asData?.value;

    // 1. Calculate missing SF9 count
    final missingSf9Students = enrolledStudents.where((s) {
      return s.missingDocuments.any(
        (d) => d.toUpperCase().contains('SF9') || d.toUpperCase().contains('FORM 9'),
      );
    }).toList();
    final sf9Count = missingSf9Students.isNotEmpty
        ? missingSf9Students.length
        : (kpis?.bottomStudents
                .where((s) => s.missingRequirements.any((d) => d.toUpperCase().contains('SF9')))
                .length ??
            0);

    // 2. Calculate missing SF10 count
    final missingSf10Students = enrolledStudents.where((s) {
      return s.missingDocuments.any(
        (d) => d.toUpperCase().contains('SF10') || d.toUpperCase().contains('FORM 10'),
      );
    }).toList();
    final sf10Count = missingSf10Students.isNotEmpty
        ? missingSf10Students.length
        : (kpis?.bottomStudents
                .where((s) => s.missingRequirements.any((d) => d.toUpperCase().contains('SF10')))
                .length ??
            0);

    final totalAlerts = sf9Count + sf10Count;

    // Top students needing immediate attention (most missing docs)
    final urgentStudents = enrolledStudents
        .where((s) => s.missingDocumentsCount > 0 || s.missingDocuments.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final countA = a.missingDocumentsCount > 0 ? a.missingDocumentsCount : a.missingDocuments.length;
        final countB = b.missingDocumentsCount > 0 ? b.missingDocumentsCount : b.missingDocuments.length;
        return countB.compareTo(countA);
      });
    final displayedStudents = urgentStudents.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: totalAlerts > 0
              ? (isDark ? AppColors.darkBorder : Colors.orange.shade200.withValues(alpha: 0.6))
              : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: totalAlerts > 0
                        ? Colors.orange.withValues(alpha: isDark ? 0.25 : 0.12)
                        : AppColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    totalAlerts > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: totalAlerts > 0 ? Colors.orange.shade800 : AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Needs Attention',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (totalAlerts > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: isDark ? 0.3 : 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalAlerts items',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        totalAlerts > 0
                            ? 'Operational items requiring action'
                            : 'All document requirements compliant',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(activeTabProvider.notifier).setTab('Documents');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Operational Alert Rows ──
          if (totalAlerts > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // SF9 alert
                  _buildAlertRow(
                    context: context,
                    icon: Icons.assignment_late_outlined,
                    iconColor: Colors.orange.shade800,
                    label: '$sf9Count missing SF9',
                    sublabel: 'Learner Progress Report Card missing for enrolled students',
                    actionLabel: 'View',
                    isDark: isDark,
                    onAction: () => _openMissingDocSheet(
                      context,
                      title: 'Students Missing SF9',
                      students: missingSf9Students,
                      userRole: userRole,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // SF10 alert
                  _buildAlertRow(
                    context: context,
                    icon: Icons.description_outlined,
                    iconColor: Colors.amber.shade800,
                    label: '$sf10Count missing SF10',
                    sublabel: 'Learner Permanent Academic Record missing',
                    actionLabel: 'View',
                    isDark: isDark,
                    onAction: () => _openMissingDocSheet(
                      context,
                      title: 'Students Missing SF10',
                      students: missingSf10Students,
                      userRole: userRole,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            // ── Urgent Student Spotlight ──
            if (displayedStudents.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Text(
                      'STUDENTS NEEDING ATTENTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    for (int i = 0; i < displayedStudents.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _buildStudentTile(
                        context: context,
                        student: displayedStudents[i],
                        userRole: userRole,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ] else ...[
            // All compliant state
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 36,
                      color: AppColors.primaryGreen.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All records in good standing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No missing SF9/SF10 or pending verification queues detected.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required String actionLabel,
    required bool isDark,
    required VoidCallback onAction,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAction,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: iconColor.withValues(alpha: isDark ? 0.25 : 0.18),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      sublabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward, size: 11, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTile({
    required BuildContext context,
    required StudentModel student,
    required String userRole,
    required bool isDark,
  }) {
    final missingList = student.missingDocuments.take(2).toList();
    final extraCount = student.missingDocuments.length - missingList.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
            child: Text(
              student.firstName.isNotEmpty ? student.firstName[0].toUpperCase() : 'S',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.listDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final doc in missingList)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '! ${_formatDocTag(doc)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    if (extraCount > 0)
                      Text(
                        '+$extraCount more',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            tooltip: 'Upload Document',
            color: AppColors.primaryGreen,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              UploadOcrModal.show(
                context,
                prefilledStudentId: student.id,
                prefilledLrn: student.lrn,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 18),
            tooltip: 'View Profile',
            color: isDark ? Colors.white70 : Colors.black87,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () {
              showStudentProfileModal(
                context,
                studentId: student.id,
                userRole: userRole,
                hideEnrollmentActions: true,
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDocTag(String doc) {
    final upper = doc.toUpperCase();
    if (upper.contains('SF9') || upper.contains('FORM 9')) return 'SF9';
    if (upper.contains('SF10') || upper.contains('FORM 10')) return 'SF10';
    if (upper.contains('PSA') || upper.contains('BIRTH')) return 'PSA';
    if (upper.contains('GOOD MORAL')) return 'Good Moral';
    return doc.length > 15 ? '${doc.substring(0, 14)}…' : doc;
  }

  void _openMissingDocSheet(
    BuildContext context, {
    required String title,
    required List<StudentModel> students,
    required String userRole,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${students.length} students currently missing this record',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No students missing this requirement.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: students.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
                    ),
                    itemBuilder: (context, i) {
                      final s = students[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        title: Text(
                          s.listDisplayName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'LRN: ${s.lrn}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                              tooltip: 'Upload Document',
                              color: AppColors.primaryGreen,
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                UploadOcrModal.show(
                                  context,
                                  prefilledStudentId: s.id,
                                  prefilledLrn: s.lrn,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_outline_rounded, size: 20),
                              tooltip: 'View Profile',
                              color: isDark ? Colors.white70 : Colors.black87,
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                showStudentProfileModal(
                                  context,
                                  studentId: s.id,
                                  userRole: userRole,
                                  hideEnrollmentActions: true,
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
