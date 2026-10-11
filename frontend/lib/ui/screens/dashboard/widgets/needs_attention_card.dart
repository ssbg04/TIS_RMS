import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../documents/widgets/student_profile_modal.dart';
import '../../documents/widgets/upload_ocr_modal.dart';
import '../../../../domain/entities/dashboard_models.dart';

/// "Needs Attention" operational card for Dashboard.
/// Dynamically monitors missing mandatory document requirements from the backend
/// and provides immediate action links directly to student targets.
class NeedsAttentionCard extends ConsumerWidget {
  const NeedsAttentionCard({super.key});

  IconData _getRequirementIcon(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('SF9') || upper.contains('REPORT CARD') || upper.contains('FORM 9')) {
      return Icons.assignment_late_outlined;
    }
    if (upper.contains('SF10') || upper.contains('FORM 137') || upper.contains('FORM 10')) {
      return Icons.description_outlined;
    }
    if (upper.contains('PSA') || upper.contains('BIRTH')) {
      return Icons.badge_outlined;
    }
    if (upper.contains('GOOD MORAL')) {
      return Icons.verified_outlined;
    }
    if (upper.contains('MEDICAL')) {
      return Icons.medical_services_outlined;
    }
    if (upper.contains('CERTIFICATE') || upper.contains('ENROLLMENT')) {
      return Icons.card_membership_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _getRequirementColor(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('SF9') || upper.contains('FORM 9')) {
      return Colors.orange.shade800;
    }
    if (upper.contains('SF10') || upper.contains('FORM 137') || upper.contains('FORM 10')) {
      return Colors.amber.shade800;
    }
    if (upper.contains('PSA') || upper.contains('BIRTH')) {
      return const Color(0xFF0284C7); // Sky Blue
    }
    if (upper.contains('GOOD MORAL')) {
      return const Color(0xFF16A34A); // Green
    }
    if (upper.contains('MEDICAL')) {
      return const Color(0xFFDC2626); // Red
    }
    return const Color(0xFF7C3AED); // Purple
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).value;
    final userRole = user?.role ?? 'teacher';

    final kpisAsync = ref.watch(dashboardKpisProvider);

    if (kpisAsync.isLoading) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (kpisAsync.hasError) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 28, color: Colors.orange.shade800),
              const SizedBox(height: 8),
              Text(
                'Unable to load operational alerts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => ref.invalidate(dashboardKpisProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final kpis = kpisAsync.value;
    final needsAttention = kpis?.needsAttention;

    // missing requirements from backend needsAttention
    final List<MissingRequirementGroup> missingGroups = needsAttention?.missingRequirements ?? [];
    final totalAlerts = needsAttention?.totalAlerts ??
        missingGroups.fold<int>(0, (sum, g) => sum + g.count);

    // Urgent students needing immediate attention
    final List<StudentDocCount> urgentStudents = needsAttention?.urgentStudents.isNotEmpty == true
        ? needsAttention!.urgentStudents
        : (kpis?.bottomStudents.where((s) => s.missingCount > 0).take(5).toList() ?? []);
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

          // ── Operational Alert Requirement Chips (Approach A) ──
          if (totalAlerts > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in missingGroups)
                    _buildRequirementChip(
                      context: context,
                      item: item,
                      isDark: isDark,
                      onTap: () => _openMissingDocSheet(
                        context,
                        title: 'Students Missing ${item.name}',
                        students: item.students,
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
                      'No missing mandatory documents detected.',
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

  Widget _buildRequirementChip({
    required BuildContext context,
    required MissingRequirementGroup item,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final icon = _getRequirementIcon(item.name);
    final color = _getRequirementColor(item.name);

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Click to view ${item.count} student${item.count == 1 ? '' : 's'} missing ${item.name}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.35 : 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  '${item.count} missing ${item.name}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTile({
    required BuildContext context,
    required StudentDocCount student,
    required String userRole,
    required bool isDark,
  }) {
    final missingList = student.missingRequirements.take(2).toList();
    final extraCount = student.missingRequirements.length - missingList.length;
    final initial = student.name.trim().isNotEmpty
        ? student.name.trim()[0].toUpperCase()
        : 'S';

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
              initial,
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
                  student.name,
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
    final clean = doc.replaceAll(RegExp(r'^\[.*?\]\s*'), '').trim();
    final upper = clean.toUpperCase();
    if (upper.contains('SF9') || upper.contains('FORM 9')) return 'SF9';
    if (upper.contains('SF10') || upper.contains('FORM 10') || upper.contains('FORM 137')) return 'SF10';
    if (upper.contains('PSA') || upper.contains('BIRTH')) return 'PSA';
    if (upper.contains('GOOD MORAL')) return 'Good Moral';
    return clean.length > 15 ? '${clean.substring(0, 14)}…' : clean;
  }

  void _openMissingDocSheet(
    BuildContext context, {
    required String title,
    required List<StudentDocCount> students,
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
                          s.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'LRN: ${s.lrn != null && s.lrn!.isNotEmpty ? s.lrn : 'N/A'}${s.gradeLevel != null ? ' • Grade ${s.gradeLevel}' : ''}',
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
