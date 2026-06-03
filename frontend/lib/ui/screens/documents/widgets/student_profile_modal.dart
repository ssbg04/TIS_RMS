import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../domain/repositories/document_repository.dart'
    show MissingRequirements;
import '../../../providers/student_provider.dart';
import '../../../providers/document_provider.dart';

// ─────────────────────────────────────────────────────────────
// Public helper – call this anywhere to show the modal
// ─────────────────────────────────────────────────────────────
void showStudentProfileModal(
  BuildContext context, {
  required int studentId,
  required String userRole,
}) {
  final screenW = MediaQuery.of(context).size.width;
  final isMobile = screenW < 700;
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          color: AppColors.pageBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Modal header ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Student Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              // ── Scrollable profile body ──
              Flexible(
                child: StudentProfileModalBody(
                  studentId: studentId,
                  userRole: userRole,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Reusable body widget
// ─────────────────────────────────────────────────────────────
class StudentProfileModalBody extends ConsumerWidget {
  final int studentId;
  final String userRole;

  const StudentProfileModalBody({
    super.key,
    required this.studentId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentDetailProvider(studentId));
    final missingReqsAsync =
        ref.watch(missingRequirementsProvider(studentId));

    return studentAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Error: $e',
                style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
      data: (student) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(student),
            const SizedBox(height: 20),

            if (student.enrollments != null &&
                student.enrollments!.isNotEmpty) ...[
              const Text('Enrollments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...(() {
                final sorted = List.from(student.enrollments!);
                sorted.sort((a, b) =>
                    (b.gradeLevel ?? 0).compareTo(a.gradeLevel ?? 0));
                return sorted
                    .map<Widget>((e) => _buildEnrollmentCard(e))
                    .toList();
              })(),
              const SizedBox(height: 20),
            ],

            const Text('Document Requirements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            missingReqsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: AppColors.primaryGreen),
                ),
              ),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: AppColors.error)),
              data: (missing) => _buildRequirementsStatus(missing),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Info card ────────────────────────────────────────────
  Widget _buildInfoCard(dynamic student) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  '${student.firstName?[0] ?? ''}${student.lastName?[0] ?? ''}',
                  style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student.firstName} ${student.middleName != null ? student.middleName! + ' ' : ''}${student.lastName}${student.extension?.isNotEmpty == true ? ', ${student.extension}' : ''}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'LRN: ${student.lrn}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(student.status),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _buildInfoItem('Sex', student.sex ?? 'N/A'),
              _buildInfoItem('Birth Date', _formatDate(student.birthDate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    switch (status) {
      case 'Enrolled':
        color = AppColors.success;
        break;
      case 'Graduated':
        color = Colors.blue;
        break;
      case 'Transferred':
        color = Colors.orange;
        break;
      case 'Dropped':
        color = AppColors.error;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(status ?? 'Unknown',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  // ── Enrollment card ──────────────────────────────────────
  Widget _buildEnrollmentCard(dynamic enrollment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grade ${enrollment.gradeLevel}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${enrollment.sectionName ?? 'N/A'} · ${enrollment.yearRange ?? 'N/A'}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                if (enrollment.trackStrand != null)
                  Text('Track: ${enrollment.trackStrand}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Requirements status ──────────────────────────────────
  Widget _buildRequirementsStatus(MissingRequirements data) {
    final jhsMissing =
        data.missing.where((r) => r.category == 'JHS').toList();
    final shsMissing =
        data.missing.where((r) => r.category == 'SHS').toList();
    final jhsVerified =
        data.verified.where((r) => r.category == 'JHS').toList();
    final shsVerified =
        data.verified.where((r) => r.category == 'SHS').toList();
    final jhsTotal = jhsMissing.length + jhsVerified.length;
    final shsTotal = shsMissing.length + shsVerified.length;
    final hasJhs = jhsTotal > 0;
    final hasShs = shsTotal > 0;

    if (!hasJhs && !hasShs) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text('No document requirements for this student.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    Widget levelSection({
      required String label,
      required Color color,
      required bool isCurrent,
      required List<dynamic> missing,
      required List<dynamic> verified,
      required int total,
    }) {
      final completed = verified.length;
      final missingCount = missing.length;
      final isDone = missingCount == 0 && total > 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone
                ? AppColors.success.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.25),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: color)),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Current',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  isDone
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle,
                              size: 13, color: AppColors.success),
                          const SizedBox(width: 3),
                          const Text('Complete',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold)),
                        ])
                      : Text('$completed/$total done',
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip('$total Total', color),
                      _chip('$completed Done', AppColors.success),
                      _chip('$missingCount Missing',
                          missingCount > 0 ? AppColors.error : AppColors.success),
                    ],
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Not Yet Submitted',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700)),
                    const SizedBox(height: 6),
                    ...missing.map((r) =>
                        _reqItem(r.name, AppColors.error, Icons.pending_actions)),
                  ],
                  if (verified.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Completed',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                    const SizedBox(height: 6),
                    ...verified.map((r) =>
                        _reqItem(r.name, AppColors.success, Icons.check_circle)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasJhs)
          levelSection(
            label: 'JHS',
            color: Colors.teal,
            isCurrent: data.category == 'JHS',
            missing: jhsMissing,
            verified: jhsVerified,
            total: jhsTotal,
          ),
        if (hasShs)
          levelSection(
            label: 'SHS',
            color: Colors.purple,
            isCurrent: data.category == 'SHS',
            missing: shsMissing,
            verified: shsVerified,
            total: shsTotal,
          ),
      ],
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _reqItem(String name, Color color, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
        ]),
      );

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) return '${date.month}/${date.day}/${date.year}';
    return date.toString();
  }
}
