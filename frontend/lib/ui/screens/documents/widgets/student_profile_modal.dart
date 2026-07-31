import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../domain/repositories/document_repository.dart'
    show MissingRequirements;
import '../../../providers/student_provider.dart';
import '../../../providers/document_provider.dart';
import '../../students/widgets/edit_enrollment_modal.dart';

// ─────────────────────────────────────────────────────────────
// Public helper – call this anywhere to show the modal
// ─────────────────────────────────────────────────────────────
void showStudentProfileModal(
  BuildContext context, {
  required int studentId,
  required String userRole,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  void Function(int studentId)? onEditById,
  void Function(int studentId)? onDeleteById,
  bool hideEnrollmentActions = false,
}) {
  final screenW = MediaQuery.of(context).size.width;
  final isMobile = screenW < 700;
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _StudentProfileDialogShell(
      initialStudentId: studentId,
      userRole: userRole,
      onEdit: onEdit,
      onDelete: onDelete,
      onEditById: onEditById,
      onDeleteById: onDeleteById,
      hideEnrollmentActions: hideEnrollmentActions,
      isMobile: isMobile,
    ),
  );
}

class _StudentProfileDialogShell extends ConsumerStatefulWidget {
  final int initialStudentId;
  final String userRole;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final void Function(int studentId)? onEditById;
  final void Function(int studentId)? onDeleteById;
  final bool hideEnrollmentActions;
  final bool isMobile;

  const _StudentProfileDialogShell({
    required this.initialStudentId,
    required this.userRole,
    this.onEdit,
    this.onDelete,
    this.onEditById,
    this.onDeleteById,
    required this.hideEnrollmentActions,
    required this.isMobile,
  });

  @override
  ConsumerState<_StudentProfileDialogShell> createState() =>
      _StudentProfileDialogShellState();
}

class _StudentProfileDialogShellState
    extends ConsumerState<_StudentProfileDialogShell> {
  late int _currentStudentId;

  @override
  void initState() {
    super.initState();
    _currentStudentId = widget.initialStudentId;
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(studentPageProvider);
    final students = pageState.value?.students ?? [];
    final currentIndex = students.indexWhere((s) => s.id == _currentStudentId);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: widget.isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          color: AppColors.pageBackground,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Modal header ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Student Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (students.isNotEmpty && currentIndex != -1) ...[
                      Tooltip(
                        message: 'Previous Student',
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: currentIndex > 0
                                ? Colors.white
                                : Colors.white24,
                            size: 16,
                          ),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                            padding: EdgeInsets.zero,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: currentIndex > 0
                              ? () => setState(() {
                                    _currentStudentId =
                                        students[currentIndex - 1].id;
                                  })
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '${currentIndex + 1}/${students.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Next Student',
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: currentIndex < students.length - 1
                                ? Colors.white
                                : Colors.white24,
                            size: 16,
                          ),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                            padding: EdgeInsets.zero,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: currentIndex < students.length - 1
                              ? () => setState(() {
                                    _currentStudentId =
                                        students[currentIndex + 1].id;
                                  })
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if ((widget.onEdit != null || widget.onEditById != null) &&
                        widget.userRole != 'teacher')
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 18,
                        ),
                        tooltip: 'Edit Student',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          if (widget.onEditById != null) {
                            widget.onEditById!(_currentStudentId);
                          } else if (widget.onEdit != null) {
                            widget.onEdit!();
                          }
                        },
                      ),
                    if ((widget.onEdit != null || widget.onEditById != null) &&
                        widget.userRole != 'teacher')
                      const SizedBox(width: 8),
                    if ((widget.onDelete != null ||
                            widget.onDeleteById != null) &&
                        widget.userRole != 'teacher')
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 18,
                        ),
                        tooltip: 'Delete Student',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          if (widget.onDeleteById != null) {
                            widget.onDeleteById!(_currentStudentId);
                          } else if (widget.onDelete != null) {
                            widget.onDelete!();
                          }
                        },
                      ),
                    if ((widget.onDelete != null ||
                            widget.onDeleteById != null) &&
                        widget.userRole != 'teacher')
                      const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // ── Scrollable profile body ──
              Flexible(
                child: StudentProfileModalBody(
                  studentId: _currentStudentId,
                  userRole: widget.userRole,
                  hideEnrollmentActions: widget.hideEnrollmentActions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable body widget
// ─────────────────────────────────────────────────────────────
class StudentProfileModalBody extends ConsumerWidget {
  final int studentId;
  final String userRole;
  final bool hideEnrollmentActions;

  const StudentProfileModalBody({
    super.key,
    required this.studentId,
    required this.userRole,
    this.hideEnrollmentActions = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentDetailProvider(studentId));
    final missingReqsAsync = ref.watch(missingRequirementsProvider(studentId));

    return studentAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Error: $e', style: const TextStyle(color: AppColors.error)),
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

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Enrollments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (!hideEnrollmentActions &&
                    (userRole == 'admin' || userRole == 'super_admin'))
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.45),
                        builder: (ctx) => EditEnrollmentModal(
                          studentId: studentId,
                          enrollment: null,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Enrollment'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (student.enrollments != null &&
                student.enrollments!.isNotEmpty) ...[
              ...(() {
                final sorted = List.from(student.enrollments!);
                sorted.sort(
                  (a, b) => (b.gradeLevel ?? 0).compareTo(a.gradeLevel ?? 0),
                );

                final seen = <String>{};
                final uniqueEnrollments = [];
                for (final e in sorted) {
                  final key = '${e.gradeLevel}_${e.academicYearId}';
                  if (!seen.contains(key)) {
                    seen.add(key);
                    uniqueEnrollments.add(e);
                  }
                }

                return uniqueEnrollments
                    .map<Widget>((e) => _buildEnrollmentCard(context, ref, e))
                    .toList();
              })(),
              const SizedBox(height: 20),
            ],

            const Text(
              'Document Requirements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            missingReqsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              error: (e, _) => Text(
                'Error: $e',
                style: const TextStyle(color: AppColors.error),
              ),
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
            offset: const Offset(0, 3),
          ),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.profileDisplayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'LRN: ${student.lrn}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
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
              _buildInfoItem('Birth Date', student.birthDate != null ? _formatDate(student.birthDate!) : 'N/A'),
              _build4psItem(student.is4ps),
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
      child: Text(
        status ?? 'Unknown',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _build4psItem(bool is4ps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4Ps Beneficiary',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: is4ps
                ? Colors.deepPurple.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: is4ps
                  ? Colors.deepPurple.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                is4ps ? Icons.check_circle : Icons.cancel_outlined,
                size: 12,
                color: is4ps ? Colors.deepPurple : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                is4ps ? 'Yes — 4Ps' : 'No',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: is4ps ? Colors.deepPurple : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Enrollment card ──────────────────────────────────────
  Widget _buildEnrollmentCard(
    BuildContext context,
    WidgetRef ref,
    dynamic enrollment,
  ) {
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
                Text(
                  'Grade ${enrollment.gradeLevel}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${enrollment.sectionName ?? 'N/A'} · ${enrollment.yearRange ?? 'N/A'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (enrollment.trackStrand != null)
                  Text(
                    'Track: ${enrollment.trackStrand}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (!hideEnrollmentActions &&
              (userRole == 'admin' || userRole == 'super_admin')) ...[
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              tooltip: 'Edit Enrollment',
              onPressed: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.45),
                  builder: (ctx) => EditEnrollmentModal(
                    studentId: studentId,
                    enrollment: enrollment,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.error,
              ),
              tooltip: 'Delete Enrollment',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Enrollment'),
                    content: const Text(
                      'Are you sure you want to delete this enrollment? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('CANCEL'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ref
                              .read(studentMutationProvider.notifier)
                              .deleteEnrollment(
                                studentId: studentId,
                                enrollmentId: enrollment.id,
                              );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('DELETE'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── Requirements status ──────────────────────────────────
  Widget _buildRequirementsStatus(MissingRequirements data) {
    final jhsMissing = data.missing.where((r) => r.category == 'JHS').toList();
    final shsMissing = data.missing.where((r) => r.category == 'SHS').toList();
    final jhsVerified = data.verified
        .where((r) => r.category == 'JHS')
        .toList();
    final shsVerified = data.verified
        .where((r) => r.category == 'SHS')
        .toList();
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
          child: Text(
            'No document requirements for this student.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
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
            color: Colors.grey.shade200,
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  isDone
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 13,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'Complete',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '$completed/$total done',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Total: $total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Done: $completed',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Missing: $missingCount',
                        style: TextStyle(
                          fontSize: 13,
                          color: missingCount > 0
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Not Yet Submitted',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...missing.map(
                      (r) => _reqItem(
                        r.name,
                        AppColors.error,
                        Icons.pending_actions,
                      ),
                    ),
                  ],
                  if (verified.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...verified.map(
                      (r) => _reqItem(
                        r.name,
                        AppColors.success,
                        Icons.check_circle,
                      ),
                    ),
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
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Widget _reqItem(String name, Color color, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) return '${date.month}/${date.day}/${date.year}';
    return date.toString();
  }
}
