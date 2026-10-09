import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../domain/entities/student_model.dart';
import '../../../../domain/entities/document_model.dart';
import '../../../../domain/entities/dashboard_models.dart' show RecentActivity;
import '../../../../domain/repositories/document_repository.dart'
    show MissingRequirements;
import '../../../../domain/entities/document_requirement_model.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/document_provider.dart';
import 'document_preview_modal.dart';
import 'upload_ocr_modal.dart';
import 'print_queue_modal.dart';
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
  void Function(int studentId)? onEditDetailsById,
  void Function(int studentId)? onEditEnrollmentById,
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
      onEditDetailsById: onEditDetailsById,
      onEditEnrollmentById: onEditEnrollmentById,
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
  final void Function(int studentId)? onEditDetailsById;
  final void Function(int studentId)? onEditEnrollmentById;
  final bool hideEnrollmentActions;
  final bool isMobile;

  const _StudentProfileDialogShell({
    required this.initialStudentId,
    required this.userRole,
    this.onEdit,
    this.onDelete,
    this.onEditById,
    this.onDeleteById,
    this.onEditDetailsById,
    this.onEditEnrollmentById,
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
    final hasDelete =
        (widget.onDelete != null || widget.onDeleteById != null) &&
            widget.userRole.toLowerCase() != 'teacher';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: widget.isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: widget.isMobile ? double.infinity : 740,
          height: widget.isMobile
              ? MediaQuery.of(context).size.height * 0.92
              : 720,
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
                      onEditDetails: widget.onEditDetailsById != null
                          ? () => widget.onEditDetailsById!(_currentStudentId)
                          : (widget.onEditById != null
                              ? () => widget.onEditById!(_currentStudentId)
                              : widget.onEdit),
                      onEditEnrollment: widget.onEditEnrollmentById != null
                          ? () => widget.onEditEnrollmentById!(_currentStudentId)
                          : null,
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

                        // Right: Actions (Inactive) - Clean text button with no background or border
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasDelete) ...[
                              Tooltip(
                                message: 'Mark as Inactive',
                                child: TextButton.icon(
                                  onPressed: () {
                                    if (widget.onDeleteById != null) {
                                      widget.onDeleteById!(_currentStudentId);
                                    } else if (widget.onDelete != null) {
                                      widget.onDelete!();
                                    }
                                  },
                                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 18, color: Colors.blueGrey),
                                  label: const Text(
                                    'Inactive',
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blueGrey,
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
enum _StudentProfileTab { overview, documents, history }

class StudentProfileModalBody extends ConsumerStatefulWidget {
  final int studentId;
  final String userRole;
  final bool hideEnrollmentActions;
  final VoidCallback? onEditDetails;
  final VoidCallback? onEditEnrollment;

  const StudentProfileModalBody({
    super.key,
    required this.studentId,
    required this.userRole,
    this.hideEnrollmentActions = false,
    this.onEditDetails,
    this.onEditEnrollment,
  });

  @override
  ConsumerState<StudentProfileModalBody> createState() =>
      _StudentProfileModalBodyState();
}

class _StudentProfileModalBodyState
    extends ConsumerState<StudentProfileModalBody> {
  _StudentProfileTab _selectedTab = _StudentProfileTab.overview;

  Future<void> _handleAddToPrintQueue(DocumentModel doc) async {
    try {
      await ref.read(printQueueMutationProvider.notifier).addToQueue(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('${doc.fileName} added to Print Queue')),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to print queue: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentDetailProvider(widget.studentId));
    final missingReqsAsync =
        ref.watch(missingRequirementsProvider(widget.studentId));
    final docsAsync = ref.watch(studentDocumentsProvider(widget.studentId));
    final activitiesAsync =
        ref.watch(studentActivitiesProvider(widget.studentId));

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
        final docsList = docsAsync.valueOrNull ?? [];
        final activitiesList = activitiesAsync.valueOrNull ?? [];
        final missingData = missingReqsAsync.valueOrNull;

        return Column(
          children: [
            // ── Top Summary Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildInfoCard(context, student),
            ),

            // ── Segmented Navigation Tabs ──
            _buildTabBar(
              context,
              student,
              docsList.length,
              activitiesList.length,
              isDark,
            ),

            // ── Scrollable Tab Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_selectedTab),
                    child: switch (_selectedTab) {
                      _StudentProfileTab.overview => _buildOverviewTab(
                          context,
                          student,
                          missingData,
                          missingReqsAsync.isLoading,
                          isDark,
                        ),
                      _StudentProfileTab.documents => _buildDocumentsTab(
                          context,
                          student,
                          missingData,
                          docsAsync,
                          isDark,
                        ),
                      _StudentProfileTab.history => _buildHistoryTab(
                          context,
                          student,
                          activitiesAsync,
                          isDark,
                        ),
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────
  Widget _buildTabBar(
    BuildContext context,
    StudentModel student,
    int docCount,
    int actCount,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Overview',
              icon: Icons.person_outline_rounded,
              isSelected: _selectedTab == _StudentProfileTab.overview,
              isDark: isDark,
              onTap: () => setState(() => _selectedTab = _StudentProfileTab.overview),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              label: 'Documents',
              icon: Icons.folder_outlined,
              count: docCount,
              isSelected: _selectedTab == _StudentProfileTab.documents,
              isDark: isDark,
              onTap: () => setState(() => _selectedTab = _StudentProfileTab.documents),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              label: 'History',
              icon: Icons.history_rounded,
              count: actCount,
              isSelected: _selectedTab == _StudentProfileTab.history,
              isDark: isDark,
              onTap: () => setState(() => _selectedTab = _StudentProfileTab.history),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    int? count,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Overview ──────────────────────────────────────
  Widget _buildOverviewTab(
    BuildContext context,
    StudentModel student,
    MissingRequirements? missing,
    bool isLoadingMissing,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enrollment Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Enrollments',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.onEditEnrollment != null &&
                widget.userRole.toLowerCase() != 'teacher')
              Tooltip(
                message: 'Manage or Add Enrollments',
                child: InkWell(
                  onTap: widget.onEditEnrollment,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen
                          .withValues(alpha: isDark ? 0.20 : 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryGreen
                            .withValues(alpha: isDark ? 0.45 : 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_calendar_rounded,
                            size: 12,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Edit Enrollment',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (student.enrollments != null && student.enrollments!.isNotEmpty) ...[
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
          const SizedBox(height: 18),
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
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No enrollment records found for this student.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Document Requirements Status Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Document Requirements',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _selectedTab = _StudentProfileTab.documents),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text(
                'Open Documents Hub',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (isLoadingMissing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (missing != null)
          _buildRequirementsStatus(
            context,
            missing,
            onUploadRequirement: (req) => UploadOcrModal.show(
              context,
              prefilledStudentId: student.id,
              prefilledLrn: student.lrn,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              ),
            ),
            child: const Center(
              child: Text(
                'No requirement data available.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tab 2: Documents Hub ──────────────────────────────────
  Widget _buildDocumentsTab(
    BuildContext context,
    StudentModel student,
    MissingRequirements? missing,
    AsyncValue<List<DocumentModel>> docsAsync,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 450;
              final buttons = Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => PrintQueueModal.show(context),
                    icon: const Icon(Icons.print_outlined, size: 14),
                    label: const Text('Print Queue', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade300,
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => UploadOcrModal.show(
                      context,
                      prefilledStudentId: student.id,
                      prefilledLrn: student.lrn,
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 14),
                    label:
                        const Text('Upload File', style: TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Workspace',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Upload, view, verify, and print scholastic documents.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    buttons,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document Workspace',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upload, view, verify, and print scholastic documents.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  buttons,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Section: Requirements Checklist
        const Text(
          'Requirements Checklist',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (missing != null)
          _buildRequirementsStatus(
            context,
            missing,
            onUploadRequirement: (req) => UploadOcrModal.show(
              context,
              prefilledStudentId: student.id,
              prefilledLrn: student.lrn,
            ),
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          ),
        const SizedBox(height: 16),

        // Section: Uploaded Files
        _buildDocumentsList(context, student, docsAsync, isDark),
      ],
    );
  }

  Widget _buildDocumentsList(
    BuildContext context,
    StudentModel student,
    AsyncValue<List<DocumentModel>> docsAsync,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Files on Record',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                docsAsync.maybeWhen(
                  data: (docs) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${docs.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.invalidate(studentDocumentsProvider(student.id)),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        docsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load documents: $e',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          data: (docs) {
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 40,
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No documents uploaded yet',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload or scan school forms to add them to this student\'s folder.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => UploadOcrModal.show(
                        context,
                        prefilledStudentId: student.id,
                        prefilledLrn: student.lrn,
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 15),
                      label: const Text('Upload Document',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: docs
                  .map((doc) =>
                      _buildDocumentItemTile(context, student, doc, isDark))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDocumentItemTile(
    BuildContext context,
    StudentModel student,
    DocumentModel doc,
    bool isDark,
  ) {
    final bool isMobile = MediaQuery.of(context).size.width < 500;
    final isArchived = doc.status.toLowerCase() == 'archived';
    final statusColor = isArchived ? Colors.grey : AppColors.success;
    final statusIcon = isArchived
        ? Icons.archive_outlined
        : Icons.check_circle_rounded;
    final statusLabel = isArchived ? 'Archived' : 'Verified';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildDocIcon(doc.fileName, isDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.fileName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 9, color: statusColor),
                          const SizedBox(width: 3),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (doc.documentType != null &&
                        doc.documentType!.isNotEmpty) ...[
                      Flexible(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface2
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            doc.documentType!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      flex: 3,
                      child: Text(
                        doc.size != null && doc.size!.isNotEmpty
                            ? (isMobile
                                ? doc.size!
                                : '${doc.size!} • ${_formatDate(doc.createdAt)}')
                            : _formatDate(doc.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Actions: View, Verify (if pending only), Print
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Preview',
                child: IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  color: AppColors.primaryGreen,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => showDocumentPreview(
                    context: context,
                    document: doc,
                  ),
                ),
              ),

              Tooltip(
                message: 'Add to Print Queue',
                child: IconButton(
                  icon: const Icon(Icons.print_outlined, size: 17),
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => _handleAddToPrintQueue(doc),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 3: History ───────────────────────────────────────
  Widget _buildHistoryTab(
    BuildContext context,
    StudentModel student,
    AsyncValue<List<RecentActivity>> activitiesAsync,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Activity History',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                activitiesAsync.maybeWhen(
                  data: (items) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.invalidate(studentActivitiesProvider(student.id)),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        activitiesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load history: $e',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          data: (activities) {
            if (activities.isEmpty) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 40,
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No activity logs yet',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Events related to this student will appear here in chronological order.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: activities
                  .map((a) => _buildActivityItemTile(context, a, isDark))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityItemTile(
    BuildContext context,
    RecentActivity a,
    bool isDark,
  ) {
    IconData icon;
    Color iconColor;

    final act = a.action.toUpperCase();
    if (act.contains('CREATE') || act.contains('ADD')) {
      icon = Icons.add_circle_outline_rounded;
      iconColor = AppColors.success;
    } else if (act.contains('DELETE')) {
      icon = Icons.delete_outline_rounded;
      iconColor = AppColors.error;
    } else if (act.contains('ARCHIVE')) {
      icon = Icons.archive_outlined;
      iconColor = Colors.blueGrey;
    } else if (act.contains('UPLOAD')) {
      icon = Icons.upload_file_rounded;
      iconColor = Colors.teal;
    } else {
      icon = Icons.edit_note_rounded;
      iconColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.description.isNotEmpty
                      ? a.description
                      : '${a.action} ${a.entityType}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      a.performedBy ?? a.username ?? 'System',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.access_time_rounded,
                        size: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(a.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocIcon(String fileName, bool isDark) {
    final ext = fileName.split('.').last.toLowerCase();
    IconData icon = Icons.description_rounded;
    Color color = Colors.blue;
    if (['pdf'].contains(ext)) {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.redAccent;
    } else if (['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext)) {
      icon = Icons.image_rounded;
      color = Colors.teal;
    } else if (['xlsx', 'xls', 'csv'].contains(ext)) {
      icon = Icons.table_chart_rounded;
      color = Colors.green;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  // ── Info card ────────────────────────────────────────────
  Widget _buildInfoCard(BuildContext context, StudentModel student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460 ||
              Theme.of(context).platform == TargetPlatform.android;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryGreen,
                      child: Text(
                        '${student.firstName[0]}${student.lastName.isNotEmpty ? student.lastName[0] : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.profileDisplayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          _CopyableLrnButton(
                            lrn: student.lrn.toString(),
                            isDark: isDark,
                          ),
                          if (student.latestGradeLevel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Grade ${student.latestGradeLevel} • ${student.latestSection ?? 'Unassigned'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(student.status),
                  ],
                ),
                if (widget.onEditDetails != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: InkWell(
                      onTap: widget.onEditDetails,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen
                              .withValues(alpha: isDark ? 0.20 : 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primaryGreen
                                .withValues(alpha: isDark ? 0.45 : 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_rounded,
                                size: 13, color: AppColors.primaryGreen),
                            const SizedBox(width: 6),
                            const Text(
                              'Edit Details',
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryGreen,
                      child: Text(
                        '${student.firstName[0]}${student.lastName.isNotEmpty ? student.lastName[0] : ''}',
                        style: const TextStyle(
                          fontSize: 18,
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          _CopyableLrnButton(
                            lrn: student.lrn.toString(),
                            isDark: isDark,
                          ),
                          if (student.latestGradeLevel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Grade ${student.latestGradeLevel} • ${student.latestSection ?? 'Unassigned'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusBadge(student.status),
                        if (widget.onEditDetails != null) ...[
                          const SizedBox(height: 6),
                          Tooltip(
                            message: 'Edit Student Details',
                            child: InkWell(
                              onTap: widget.onEditDetails,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen
                                      .withValues(alpha: isDark ? 0.20 : 0.10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primaryGreen
                                        .withValues(alpha: isDark ? 0.45 : 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        size: 12, color: AppColors.primaryGreen),
                                    SizedBox(width: 4),
                                    Text(
                                      'Edit Details',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
              Divider(
                  height: 20,
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _buildInfoItem(
                      context,
                      'Sex',
                      (student.sex.isNotEmpty)
                          ? student.sex
                          : '-'),
                  _buildInfoItem(
                      context,
                      'Birth Date',
                      student.birthDate != null
                          ? _formatDate(student.birthDate!)
                          : '-'),
                  _build4psItem(context, student.is4ps),
                ],
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status ?? 'Unknown',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
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
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          displayValue,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
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
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                size: 13,
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
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
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
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400.withValues(alpha: 0.2),
                  Colors.blue.shade700.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
            ),
            child:
                const Icon(Icons.school_rounded, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Grade ${enrollment.gradeLevel}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${enrollment.sectionName ?? '-'} · ${enrollment.yearRange ?? '-'}',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (enrollment.trackStrand != null &&
                    enrollment.trackStrand.toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Track: ${enrollment.trackStrand}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.onEditEnrollment != null &&
              widget.userRole.toLowerCase() != 'teacher')
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primaryGreen,
              tooltip: 'Edit Enrollment',
              onPressed: widget.onEditEnrollment,
            ),
        ],
      ),
    );
  }

  // ── Requirements status ──────────────────────────────────
  Widget _buildRequirementsStatus(
    BuildContext context,
    MissingRequirements data, {
    void Function(DocumentRequirementModel req)? onUploadRequirement,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jhsMissing = data.missing.where((r) => r.category == 'JHS').toList();
    final shsMissing = data.missing.where((r) => r.category == 'SHS').toList();
    final jhsVerified =
        data.verified.where((r) => r.category == 'JHS').toList();
    final shsVerified =
        data.verified.where((r) => r.category == 'SHS').toList();

    final hasJhs = (jhsMissing.length + jhsVerified.length) > 0;
    final hasShs = (shsMissing.length + shsVerified.length) > 0;

    if (!hasJhs && !hasShs) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'No document requirements for this student.',
            style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
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
      final archivedCount =
          verified.where((r) => r.documentStatus == 'Archived').length;
      final activeCompletedCount =
          verified.where((r) => r.documentStatus != 'Archived').length;

      final isAllMandatoryDone = mandatoryMissing.isEmpty && mandatoryTotal > 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.4)),
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
                          archivedCount == mandatoryTotal
                              ? Icons.archive_outlined
                              : Icons.check_circle_rounded,
                          size: 14,
                          color: archivedCount == mandatoryTotal
                              ? (isDark
                                  ? Colors.blueGrey.shade200
                                  : Colors.blueGrey.shade700)
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
                                ? (isDark
                                    ? Colors.blueGrey.shade200
                                    : Colors.blueGrey.shade700)
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
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            // Body with stats & items
            Padding(
              padding: const EdgeInsets.all(12),
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
                        color: isAllMandatoryDone
                            ? AppColors.success
                            : Colors.orange,
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
                  const SizedBox(height: 12),

                  // ── Mandatory Requirements Group ──
                  if (mandatoryTotal > 0) ...[
                    Text(
                      'MANDATORY REQUIREMENTS',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...mandatoryVerified.map((r) => _buildRequirementCard(
                          context,
                          r,
                          r.documentStatus == 'Archived'
                              ? 'archived'
                              : 'completed',
                          isDark,
                        )),
                    ...mandatoryMissing.map((r) => _buildRequirementCard(
                          context,
                          r,
                          'missing_mandatory',
                          isDark,
                          onUpload: onUploadRequirement != null
                              ? () => onUploadRequirement(r)
                              : null,
                        )),
                  ],

                  // ── Optional Requirements Group ──
                  if ((optionalMissing.length + optionalVerified.length) > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'OPTIONAL REQUIREMENTS',
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...optionalVerified.map((r) => _buildRequirementCard(
                          context,
                          r,
                          r.documentStatus == 'Archived'
                              ? 'archived'
                              : 'completed',
                          isDark,
                        )),
                    ...optionalMissing.map((r) => _buildRequirementCard(
                          context,
                          r,
                          'missing_optional',
                          isDark,
                          onUpload: onUploadRequirement != null
                              ? () => onUploadRequirement(r)
                              : null,
                        )),
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

  Widget _buildCountBadge({
    required String label,
    required Color color,
    required bool isDark,
  }) {
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
    bool isDark, {
    VoidCallback? onUpload,
  }) {
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
        iconColor =
            isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700;
        icon = Icons.archive_outlined;
        statusLabel = 'Archived';
        statusColor =
            isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700;
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
        statusColor =
            isDark ? AppColors.darkTextSecondary : Colors.grey.shade600;
        break;
    }

    final isMobile = MediaQuery.of(context).size.width < 500;

    final typeBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: r.isMandatory
            ? (isDark
                ? Colors.indigo.withValues(alpha: 0.25)
                : Colors.indigo.shade50)
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
    );

    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );

    final uploadBtn = ((state == 'missing_mandatory' || state == 'missing_optional') &&
            onUpload != null)
        ? InkWell(
            onTap: onUpload,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen
                    .withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primaryGreen
                      .withValues(alpha: isDark ? 0.5 : 0.35),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file_rounded,
                      size: 11, color: AppColors.primaryGreen),
                  SizedBox(width: 3),
                  Text(
                    'Upload',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;

    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                statusBadge,
              ],
            ),
            if (r.description != null && r.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                r.description!.trim(),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                typeBadge,
                ?uploadBtn,
              ],
            ),
          ],
        ),
      );
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
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (r.description != null && r.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      r.description!.trim(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          typeBadge,
          const SizedBox(width: 6),
          statusBadge,
          if (uploadBtn != null) ...[
            const SizedBox(width: 6),
            uploadBtn,
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) return '${date.month}/${date.day}/${date.year}';
    final parsed = DateTime.tryParse(date.toString());
    if (parsed != null) return '${parsed.month}/${parsed.day}/${parsed.year}';
    return date.toString();
  }

  String _formatDateTime(dynamic dt) {
    if (dt == null) return 'N/A';
    final parsed = dt is DateTime ? dt : DateTime.tryParse(dt.toString());
    if (parsed != null) {
      final hour = parsed.hour > 12
          ? parsed.hour - 12
          : (parsed.hour == 0 ? 12 : parsed.hour);
      final amPm = parsed.hour >= 12 ? 'PM' : 'AM';
      final min = parsed.minute.toString().padLeft(2, '0');
      return '${parsed.month}/${parsed.day}/${parsed.year} $hour:$min $amPm';
    }
    return dt.toString();
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

