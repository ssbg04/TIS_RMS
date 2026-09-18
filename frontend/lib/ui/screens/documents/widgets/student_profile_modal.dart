import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../domain/repositories/document_repository.dart'
    show MissingRequirements;
import '../../../../domain/entities/document_requirement_model.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/document_provider.dart';
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

    final isMobileOrAndroid = widget.isMobile ||
        Theme.of(context).platform == TargetPlatform.android;
    final actionIconSize = isMobileOrAndroid ? 20.0 : 18.0;
    final buttonConstraints = isMobileOrAndroid
        ? const BoxConstraints(minWidth: 36, minHeight: 36)
        : const BoxConstraints(minWidth: 28, minHeight: 28);
    final buttonPadding = isMobileOrAndroid
        ? const EdgeInsets.all(4)
        : EdgeInsets.zero;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEdit = (widget.onEdit != null || widget.onEditById != null) &&
        widget.userRole != 'teacher';
    final hasDelete =
        (widget.onDelete != null || widget.onDeleteById != null) &&
            widget.userRole != 'teacher';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: widget.isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: widget.isMobile ? double.infinity : 620,
          height: widget.isMobile
              ? MediaQuery.of(context).size.height * 0.88
              : 680,
          color: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Modal header ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: actionIconSize,
                          ),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                            padding: buttonPadding,
                          ),
                          padding: buttonPadding,
                          constraints: buttonConstraints,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // ── Scrollable profile body ──
                  Expanded(
                    child: StudentProfileModalBody(
                      studentId: _currentStudentId,
                      userRole: widget.userRole,
                      hideEnrollmentActions: widget.hideEnrollmentActions,
                    ),
                  ),
                  // ── Fixed footer with navigation + action buttons ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                        ),
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Previous / Next Navigation
                        if (students.isNotEmpty && currentIndex != -1)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Previous Student',
                                child: IconButton(
                                  icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: currentIndex > 0
                                        ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                                    size: 16,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                      ),
                                    ),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '${currentIndex + 1} / ${students.length}',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                                        ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                                    size: 16,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  onPressed: currentIndex < students.length - 1
                                      ? () => setState(() {
                                            _currentStudentId =
                                                students[currentIndex + 1].id;
                                          })
                                      : null,
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox.shrink(),

                        // Right: Actions (Delete / Edit) - Clean text buttons with no background or border
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasDelete) ...[
                              Tooltip(
                                message: 'Delete Student',
                                child: TextButton.icon(
                                  onPressed: () {
                                    if (widget.onDeleteById != null) {
                                      widget.onDeleteById!(_currentStudentId);
                                    } else if (widget.onDelete != null) {
                                      widget.onDelete!();
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                  label: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    backgroundColor: Colors.transparent,
                                    side: BorderSide.none,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (hasEdit) ...[
                              Tooltip(
                                message: 'Edit Student',
                                child: TextButton.icon(
                                  onPressed: () {
                                    if (widget.onEditById != null) {
                                      widget.onEditById!(_currentStudentId);
                                    } else if (widget.onEdit != null) {
                                      widget.onEdit!();
                                    }
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryGreen),
                                  label: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryGreen,
                                    backgroundColor: Colors.transparent,
                                    side: BorderSide.none,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Error: $e', style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ),
      data: (student) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(context, student),
              const SizedBox(height: 20),

            const SizedBox(height: 20),
            const Text(
              'Enrollments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No enrollment records found for this student.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              data: (missing) => _buildRequirementsStatus(context, missing),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
      },
    );
  }

  // ── Info card ────────────────────────────────────────────
  Widget _buildInfoCard(BuildContext context, dynamic student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    _CopyableLrnButton(
                      lrn: student.lrn?.toString(),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(student.status),
            ],
          ),
          Divider(height: 24, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _buildInfoItem(context, 'Sex', (student.sex != null && student.sex!.isNotEmpty) ? student.sex! : '-'),
              _buildInfoItem(context, 'Birth Date', student.birthDate != null ? _formatDate(student.birthDate!) : '-'),
              _build4psItem(context, student.is4ps),
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

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = value.trim().isEmpty ? '-' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          displayValue,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _build4psItem(BuildContext context, bool is4ps) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '4Ps Beneficiary',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        if (is4ps)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: isDark ? const Color(0xFF8B8ED8) : AppColors.fourPs,
              ),
              const SizedBox(width: 4),
              Text(
                'Yes - 4Ps',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8B8ED8) : AppColors.fourPs,
                ),
              ),
            ],
          )
        else
          Text(
            '-',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  Widget _buildEnrollmentCard(
    BuildContext context,
    WidgetRef ref,
    dynamic enrollment,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${enrollment.sectionName ?? '-'} · ${enrollment.yearRange ?? '-'}',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (enrollment.trackStrand != null)
                  Text(
                    'Track: ${enrollment.trackStrand}',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Requirements status ──────────────────────────────────
  Widget _buildRequirementsStatus(BuildContext context, MissingRequirements data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jhsMissing = data.missing.where((r) => r.category == 'JHS').toList();
    final shsMissing = data.missing.where((r) => r.category == 'SHS').toList();
    final jhsVerified = data.verified.where((r) => r.category == 'JHS').toList();
    final shsVerified = data.verified.where((r) => r.category == 'SHS').toList();

    final hasJhs = (jhsMissing.length + jhsVerified.length) > 0;
    final hasShs = (shsMissing.length + shsVerified.length) > 0;

    if (!hasJhs && !hasShs) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'No document requirements for this student.',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      );
    }

    Widget levelSection({
      required String label,
      required Color color,
      required bool isCurrent,
      required List<DocumentRequirementModel> missing,
      required List<DocumentRequirementModel> verified,
    }) {
      final mandatoryMissing = missing.where((r) => r.isMandatory).toList();
      final optionalMissing = missing.where((r) => !r.isMandatory).toList();
      final mandatoryVerified = verified.where((r) => r.isMandatory).toList();
      final optionalVerified = verified.where((r) => !r.isMandatory).toList();

      final mandatoryTotal = mandatoryMissing.length + mandatoryVerified.length;
      final mandatoryDone = mandatoryVerified.length;
      final archivedCount = verified.where((r) => r.documentStatus == 'Archived').length;
      final activeCompletedCount = verified.where((r) => r.documentStatus != 'Archived').length;

      final isAllMandatoryDone = mandatoryMissing.isEmpty && mandatoryTotal > 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? AppColors.primaryGreen.withValues(alpha: isDark ? 0.6 : 0.8)
                : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level header strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Current Level',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (isAllMandatoryDone)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          archivedCount == mandatoryTotal ? Icons.archive_outlined : Icons.check_circle_rounded,
                          size: 14,
                          color: archivedCount == mandatoryTotal
                              ? (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700)
                              : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          archivedCount == mandatoryTotal
                              ? 'All Archived ($mandatoryTotal/$mandatoryTotal)'
                              : 'All Submitted ($mandatoryDone/$mandatoryTotal)',
                          style: TextStyle(
                            fontSize: 11,
                            color: archivedCount == mandatoryTotal
                                ? (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700)
                                : AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '$mandatoryDone / $mandatoryTotal Required Done',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            // Body with stats & items
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary badge row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildCountBadge(
                        label: 'Required: $mandatoryDone / $mandatoryTotal',
                        color: isAllMandatoryDone ? AppColors.success : Colors.orange,
                        isDark: isDark,
                      ),
                      if (activeCompletedCount > 0)
                        _buildCountBadge(
                          label: '$activeCompletedCount Active',
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                      if (archivedCount > 0)
                        _buildCountBadge(
                          label: '$archivedCount Archived',
                          color: Colors.blueGrey,
                          isDark: isDark,
                        ),
                      if (mandatoryMissing.isNotEmpty)
                        _buildCountBadge(
                          label: '${mandatoryMissing.length} Missing',
                          color: AppColors.error,
                          isDark: isDark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Mandatory Requirements Group ──
                  if (mandatoryTotal > 0) ...[
                    Text(
                      'MANDATORY REQUIREMENTS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...mandatoryVerified.map((r) => _buildRequirementCard(context, r, r.documentStatus == 'Archived' ? 'archived' : 'completed', isDark)),
                    ...mandatoryMissing.map((r) => _buildRequirementCard(context, r, 'missing_mandatory', isDark)),
                  ],

                  // ── Optional Requirements Group ──
                  if ((optionalMissing.length + optionalVerified.length) > 0) ...[
                    const SizedBox(height: 14),
                    Text(
                      'OPTIONAL REQUIREMENTS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...optionalVerified.map((r) => _buildRequirementCard(context, r, r.documentStatus == 'Archived' ? 'archived' : 'completed', isDark)),
                    ...optionalMissing.map((r) => _buildRequirementCard(context, r, 'missing_optional', isDark)),
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
          ),
        if (hasShs)
          levelSection(
            label: 'SHS',
            color: Colors.purple,
            isCurrent: data.category == 'SHS',
            missing: shsMissing,
            verified: shsVerified,
          ),
      ],
    );
  }

  Widget _buildCountBadge({required String label, required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? color.withValues(alpha: 0.9) : color,
        ),
      ),
    );
  }

  Widget _buildRequirementCard(
    BuildContext context,
    DocumentRequirementModel r,
    String state, // 'completed', 'archived', 'missing_mandatory', 'missing_optional'
    bool isDark,
  ) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;
    String statusLabel;
    Color statusColor;

    switch (state) {
      case 'completed':
        bg = AppColors.success.withValues(alpha: isDark ? 0.08 : 0.04);
        border = AppColors.success.withValues(alpha: isDark ? 0.25 : 0.2);
        iconColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        statusLabel = 'Completed';
        statusColor = AppColors.success;
        break;
      case 'archived':
        bg = Colors.blueGrey.withValues(alpha: isDark ? 0.15 : 0.06);
        border = Colors.blueGrey.withValues(alpha: isDark ? 0.35 : 0.25);
        iconColor = isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700;
        icon = Icons.archive_outlined;
        statusLabel = 'Archived';
        statusColor = isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700;
        break;
      case 'missing_mandatory':
        bg = Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05);
        border = Colors.orange.withValues(alpha: isDark ? 0.3 : 0.25);
        iconColor = Colors.orange.shade700;
        icon = Icons.error_outline_rounded;
        statusLabel = 'Missing';
        statusColor = Colors.orange.shade800;
        break;
      case 'missing_optional':
      default:
        bg = isDark ? AppColors.darkSurface2 : Colors.grey.shade50;
        border = isDark ? AppColors.darkBorder : Colors.grey.shade200;
        iconColor = isDark ? AppColors.darkTextSecondary : Colors.grey.shade400;
        icon = Icons.radio_button_unchecked_rounded;
        statusLabel = 'Not Submitted';
        statusColor = isDark ? AppColors.darkTextSecondary : Colors.grey.shade600;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                if (r.description != null && r.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      r.description!.trim(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Type badge: Mandatory vs Optional
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: r.isMandatory
                  ? (isDark ? Colors.indigo.withValues(alpha: 0.25) : Colors.indigo.shade50)
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: r.isMandatory
                    ? (isDark ? Colors.indigo.shade300 : Colors.indigo.shade200)
                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                width: 0.8,
              ),
            ),
            child: Text(
              r.isMandatory ? 'Mandatory' : 'Optional',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: r.isMandatory
                    ? (isDark ? Colors.indigo.shade200 : Colors.indigo.shade800)
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state == 'archived') ...[
                  Icon(Icons.archive_outlined, size: 10, color: statusColor),
                  const SizedBox(width: 3),
                ],
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) return '${date.month}/${date.day}/${date.year}';
    return date.toString();
  }
}

class _CopyableLrnButton extends StatefulWidget {
  final String? lrn;
  final bool isDark;

  const _CopyableLrnButton({required this.lrn, required this.isDark});

  @override
  State<_CopyableLrnButton> createState() => _CopyableLrnButtonState();
}

class _CopyableLrnButtonState extends State<_CopyableLrnButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    final lrn = widget.lrn?.toString().trim() ?? '';
    if (lrn.isEmpty) return;

    Clipboard.setData(ClipboardData(text: lrn));
    HapticService.light();

    setState(() {
      _copied = true;
    });

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('LRN copied: $lrn'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: _handleCopy,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LRN: ${widget.lrn ?? 'N/A'}',
              style: TextStyle(
                color: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: _copied ? 'Copied!' : 'Copy LRN',
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: _copied
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('check'),
                        size: 15,
                        color: AppColors.primaryGreen,
                      )
                    : Icon(
                        Icons.copy_rounded,
                        key: const ValueKey('copy'),
                        size: 14,
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

