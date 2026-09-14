import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../shared/modals/custom_modal.dart';
import '../../../shared/widgets/app_button_loader.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/setup_provider.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../../domain/entities/student_model.dart';

class EditEnrollmentModal extends ConsumerStatefulWidget {
  final int studentId;
  final dynamic
  enrollment; // If null, it's an Add operation. If set, it's an Edit operation.

  const EditEnrollmentModal({
    super.key,
    required this.studentId,
    this.enrollment,
  });

  @override
  ConsumerState<EditEnrollmentModal> createState() =>
      _EditEnrollmentModalState();
}

class _EditEnrollmentModalState extends ConsumerState<EditEnrollmentModal> {
  final _formKey = GlobalKey<FormState>();

  dynamic _currentEnrollment;
  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _currentEnrollment = widget.enrollment;
    if (_currentEnrollment != null) {
      _selectedAcademicYearId = _currentEnrollment.academicYearId;
      _selectedGradeLevel = _currentEnrollment.gradeLevel;
      _selectedSectionId = _currentEnrollment.sectionId;
      _trackStrand = _currentEnrollment.trackStrand;
    } else {
      _selectedGradeLevel = 7;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(sectionsListProvider);
        ref.invalidate(studentDetailProvider(widget.studentId));
      }
    });
  }

  void _showValidationDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invalid Update'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _populateForEdit(dynamic enrollment) {
    setState(() {
      _currentEnrollment = enrollment;
      _selectedAcademicYearId = enrollment.academicYearId;
      _selectedGradeLevel = enrollment.gradeLevel;
      _selectedSectionId = enrollment.sectionId;
      _trackStrand = enrollment.trackStrand;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _currentEnrollment = null;
      _selectedGradeLevel = 7;
      _selectedSectionId = null;
      _trackStrand = null;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _handleDeleteEnrollment(dynamic enrollment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Enrollment'),
        content: Text(
          'Are you sure you want to delete Grade ${enrollment.gradeLevel} (${enrollment.sectionName ?? "Section"} · ${enrollment.yearRange ?? ""})? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref.read(studentMutationProvider.notifier).deleteEnrollment(
            studentId: widget.studentId,
            enrollmentId: enrollment.id,
          );
      if (_currentEnrollment?.id == enrollment.id) {
        _currentEnrollment = null;
        _selectedGradeLevel = 7;
        _selectedSectionId = null;
        _trackStrand = null;
      }
      ref.invalidate(studentDetailProvider(widget.studentId));
      ref.invalidate(studentPageProvider);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = 'Enrollment deleted successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAcademicYearId == null) {
      _showValidationDialog('Please select an academic year.');
      return;
    }
    if (_selectedGradeLevel == null) {
      _showValidationDialog('Please select a grade level.');
      return;
    }
    if (_selectedSectionId == null) {
      _showValidationDialog('Please select a valid section.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final notifier = ref.read(studentMutationProvider.notifier);
      if (_currentEnrollment == null) {
        // Add
        await notifier.addEnrollment(
          studentId: widget.studentId,
          academicYearId: _selectedAcademicYearId!,
          gradeLevel: _selectedGradeLevel!,
          sectionId: _selectedSectionId!,
          trackStrand: _trackStrand,
        );
      } else {
        // Update
        await notifier.updateEnrollment(
          studentId: widget.studentId,
          enrollmentId: _currentEnrollment.id,
          academicYearId: _selectedAcademicYearId!,
          gradeLevel: _selectedGradeLevel!,
          sectionId: _selectedSectionId!,
          trackStrand: _trackStrand,
        );
      }

      ref.invalidate(studentDetailProvider(widget.studentId));
      ref.invalidate(studentPageProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  Future<void> _handleAddMoreEnrollment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAcademicYearId == null) {
      _showValidationDialog('Please select an academic year.');
      return;
    }
    if (_selectedGradeLevel == null) {
      _showValidationDialog('Please select a grade level.');
      return;
    }
    if (_selectedSectionId == null) {
      _showValidationDialog('Please select a valid section.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add More Enrollment'),
        content: const Text(
          'Do you want to save this enrollment and add another record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('YES'),
          ),
        ],
      ),
    );

    if (confirmed == null) return;

    if (!confirmed) {
      setState(() {
        _selectedAcademicYearId = null;
        _selectedGradeLevel = 7;
        _selectedSectionId = null;
        _trackStrand = null;
        _errorMessage = null;
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final notifier = ref.read(studentMutationProvider.notifier);
      if (_currentEnrollment == null) {
        // Add
        await notifier.addEnrollment(
          studentId: widget.studentId,
          academicYearId: _selectedAcademicYearId!,
          gradeLevel: _selectedGradeLevel!,
          sectionId: _selectedSectionId!,
          trackStrand: _trackStrand,
        );
      } else {
        // Update
        await notifier.updateEnrollment(
          studentId: widget.studentId,
          enrollmentId: _currentEnrollment.id,
          academicYearId: _selectedAcademicYearId!,
          gradeLevel: _selectedGradeLevel!,
          sectionId: _selectedSectionId!,
          trackStrand: _trackStrand,
        );
      }

      ref.invalidate(studentDetailProvider(widget.studentId));
      ref.invalidate(studentPageProvider);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentEnrollment = null; // Switch to add mode for subsequent additions
        _selectedGradeLevel = 7; // Reset to default Grade 7
        _selectedSectionId = null; // Clear section for the next record
        _trackStrand = null;
        _errorMessage = null;
        _successMessage =
            'Enrollment record saved successfully. Initialized for next enrollment.';
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final studentDetailAsync =
        ref.watch(studentDetailProvider(widget.studentId));

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double maxDialogHeight = isMobile
        ? (screenHeight * 0.85)
        : (screenHeight * 0.85).clamp(520.0, 700.0);
    double dialogHeight = maxDialogHeight.clamp(
      200.0,
      screenHeight - viewInsets.bottom - 24.0,
    );

    final isAsyncLoading = yearsAsync.isLoading ||
        gradeLevelsAsync.isLoading ||
        sectionsAsync.isLoading;

    final years = yearsAsync.asData?.value ?? [];
    final allGrades =
        List<GradeLevelModel>.from(gradeLevelsAsync.asData?.value ?? [])
          ..sort((a, b) => a.level.compareTo(b.level));
    final allSections = sectionsAsync.asData?.value ?? [];

    final studentDetail = studentDetailAsync.asData?.value;
    final enrollments =
        studentDetail?.enrollments ?? <EnrollmentModel>[];
    final sortedEnrollments = List<EnrollmentModel>.from(enrollments)
      ..sort((a, b) => b.gradeLevel.compareTo(a.gradeLevel));

    // 1. Determine active/effective Academic Year
    final activeYears =
        years.where((y) => y.status.toLowerCase() == 'active').toList();
    final defaultYearId = (activeYears.isNotEmpty
        ? activeYears.last
        : (years.isNotEmpty ? years.last : null))?.id;

    final effectiveYearId = _selectedAcademicYearId != null &&
            years.any((y) => y.id == _selectedAcademicYearId)
        ? _selectedAcademicYearId
        : (_currentEnrollment != null ? null : defaultYearId);

    if (_selectedAcademicYearId == null && effectiveYearId != null) {
      _selectedAcademicYearId = effectiveYearId;
    }

    // 2. Determine available Grade Levels for the selected Academic Year based on sections in DB
    final sectionsInYear = effectiveYearId != null
        ? allSections.where((s) => s.academicYearId == effectiveYearId).toList()
        : <SectionModel>[];

    List<GradeLevelModel> availableGrades;
    if (sectionsInYear.isNotEmpty) {
      final gradesInYear = sectionsInYear.map((s) => s.gradeLevel).toSet();
      availableGrades =
          allGrades.where((g) => gradesInYear.contains(g.level)).toList();
      if (availableGrades.isEmpty) {
        availableGrades = allGrades;
      }
    } else {
      availableGrades = allGrades;
    }

    // 3. Determine effective Grade Level
    int? effectiveGradeLevel;
    if (_selectedGradeLevel != null &&
        availableGrades.any((g) => g.level == _selectedGradeLevel)) {
      effectiveGradeLevel = _selectedGradeLevel;
    } else {
      effectiveGradeLevel = availableGrades.any((g) => g.level == 7)
          ? 7
          : (availableGrades.isNotEmpty ? availableGrades.first.level : null);
      if (_currentEnrollment == null) {
        _selectedGradeLevel = effectiveGradeLevel;
      }
    }

    // 4. Determine available Sections for (effectiveYearId, effectiveGradeLevel)
    final filteredSections =
        (effectiveYearId != null && effectiveGradeLevel != null)
            ? allSections
                .where((sec) =>
                    sec.academicYearId == effectiveYearId &&
                    sec.gradeLevel == effectiveGradeLevel)
                .toList()
            : <SectionModel>[];
    filteredSections.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    // 5. Determine effective Section
    int? effectiveSectionId;
    if (_selectedSectionId != null &&
        filteredSections.any((s) => s.id == _selectedSectionId)) {
      effectiveSectionId = _selectedSectionId;
    } else {
      effectiveSectionId = null;
      if (_currentEnrollment == null) {
        _selectedSectionId = null;
      }
    }

    return CustomModal(
      title: _currentEnrollment == null ? 'Add Enrollment' : 'Edit Enrollment',
      icon: _currentEnrollment == null
          ? Icons.add_box_outlined
          : Icons.edit_document,
      maxWidth: 520,
      onClose: () => Navigator.of(context).pop(),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: dialogHeight),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_currentEnrollment != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Editing Grade ${_currentEnrollment.gradeLevel} Enrollment',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _cancelEdit,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: Colors.blue,
                              ),
                              child: const Text('Cancel Edit'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                    children: [
                      if (isAsyncLoading)
                        const Padding(
                          padding: EdgeInsets.all(AppSizes.p32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        // Academic Year
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                              'edit_enrollment_academic_dropdown_$effectiveYearId'),
                          initialValue: effectiveYearId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Academic Year',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          items: years
                              .map(
                                (y) => DropdownMenuItem<int>(
                                  value: y.id,
                                  child: Text(y.yearRange),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            ref.invalidate(academicYearsListProvider);
                            ref.invalidate(sectionsListProvider);
                            ref.invalidate(gradeLevelsListProvider);
                            setState(() {
                              _selectedAcademicYearId = val;
                              // Realtime refresh available grade levels for the new academic year
                              final yearSecs = val != null
                                  ? allSections
                                      .where((s) => s.academicYearId == val)
                                      .toList()
                                  : <SectionModel>[];
                              final validGrades = yearSecs.isNotEmpty
                                  ? allGrades
                                      .where((g) => yearSecs
                                          .any((s) => s.gradeLevel == g.level))
                                      .toList()
                                  : allGrades;
                              if (!validGrades
                                  .any((g) => g.level == _selectedGradeLevel)) {
                                _selectedGradeLevel = validGrades
                                        .any((g) => g.level == 7)
                                    ? 7
                                    : (validGrades.isNotEmpty
                                        ? validGrades.first.level
                                        : null);
                              }
                              _selectedSectionId = null;
                              if (_selectedGradeLevel != null &&
                                  _selectedGradeLevel! < 11) {
                                _trackStrand = null;
                              }
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                          validator: (v) =>
                              (v == null && effectiveYearId == null)
                                  ? 'Academic year is required.'
                                  : null,
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Grade Level
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                              'edit_enrollment_grade_dropdown_${effectiveYearId}_$effectiveGradeLevel'),
                          initialValue: effectiveGradeLevel,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Grade Level',
                            prefixIcon: Icon(Icons.grade),
                          ),
                          items: availableGrades
                              .map(
                                (g) => DropdownMenuItem<int>(
                                  value: g.level,
                                  child: Text(g.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedGradeLevel = val;
                              _selectedSectionId = null;
                              if (val != null && val < 11) {
                                _trackStrand = null;
                              }
                              _errorMessage = null;
                              _successMessage = null;
                            });
                          },
                          validator: (v) =>
                              (v == null && effectiveGradeLevel == null)
                                  ? 'Grade level is required.'
                                  : null,
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Section
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                              'edit_enrollment_section_dropdown_${effectiveYearId}_${effectiveGradeLevel}_$effectiveSectionId'),
                          initialValue: effectiveSectionId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Section',
                            prefixIcon: const Icon(Icons.segment),
                            hintText: filteredSections.isEmpty
                                ? 'No sections available'
                                : 'Select section',
                          ),
                          items: filteredSections
                              .map(
                                (s) => DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: filteredSections.isEmpty
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedSectionId = val;
                                    _errorMessage = null;
                                    _successMessage = null;
                                  });
                                },
                          validator: (v) {
                            if (v == null && effectiveSectionId == null) {
                              return 'Please select a valid section.';
                            }
                            return null;
                          },
                        ),

                        if (effectiveGradeLevel != null &&
                            effectiveGradeLevel >= 11) ...[
                          const SizedBox(height: AppSizes.p16),
                          TextFormField(
                            key: ValueKey(
                                'edit_enrollment_track_strand_${effectiveGradeLevel}_${_currentEnrollment?.id}'),
                            initialValue: _trackStrand,
                            decoration: const InputDecoration(
                              labelText: 'Track & Strand (for SHS)',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            onChanged: (val) => _trackStrand =
                                val.trim().isEmpty ? null : val.trim(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                // ── Current Enrollments List ────────────────────────────
                const SizedBox(height: AppSizes.p20),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current Enrollments (${sortedEnrollments.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (studentDetailAsync.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Refresh enrollments',
                        onPressed: () => ref.invalidate(
                          studentDetailProvider(widget.studentId),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (studentDetailAsync.isLoading && sortedEnrollments.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (sortedEnrollments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceCard
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: const Text(
                      'No enrollment records found for this student.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedEnrollments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final item = sortedEnrollments[index];
                      final isCurrentlyEditing =
                          _currentEnrollment?.id == item.id;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentlyEditing
                              ? AppColors.primaryGreen
                                  .withValues(alpha: 0.08)
                              : (isDark
                                  ? AppColors.darkSurfaceCard
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrentlyEditing
                                ? AppColors.primaryGreen
                                : (isDark
                                    ? AppColors.darkBorder
                                    : Colors.grey.shade200),
                            width: isCurrentlyEditing ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCurrentlyEditing
                                    ? AppColors.primaryGreen
                                        .withValues(alpha: 0.2)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.school,
                                color: isCurrentlyEditing
                                    ? AppColors.primaryGreen
                                    : Colors.blue,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Grade ${item.gradeLevel}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isCurrentlyEditing) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreen
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Editing',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppColors.primaryGreen,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.sectionName ?? 'N/A'} · ${item.yearRange ?? 'N/A'}',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (item.trackStrand != null &&
                                      item.trackStrand!.isNotEmpty)
                                    Text(
                                      'Track: ${item.trackStrand}',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.blue,
                              ),
                              tooltip: 'Edit Enrollment',
                              onPressed: _isLoading
                                  ? null
                                  : () => _populateForEdit(item),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.error,
                              ),
                              tooltip: 'Delete Enrollment',
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleDeleteEnrollment(item),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

            if (_successMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage!.toLowerCase().contains('downgrade') ||
                        _errorMessage!.toLowerCase().contains('lower')) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tip: To correct a grade level or downgrade a student, delete the higher enrollment record(s) first from the Enrollments tab.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final isMobile = constraints.maxWidth < 450;
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentEnrollment == null) ...[
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              key: const ValueKey('add_more_enrollment_button'),
                              onPressed: _isLoading ? null : _handleAddMoreEnrollment,
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text(
                                'Add More Enrollment',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(color: AppColors.primaryGreen),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMedium,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusMedium,
                                      ),
                                    ),
                                    side: BorderSide(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.borderLight,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1C8248),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radiusMedium,
                                      ),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const AppButtonLoader(
                                          color: Colors.white,
                                          size: 20,
                                          strokeWidth: 2,
                                        )
                                      : Text(
                                          _currentEnrollment == null
                                              ? 'SAVE'
                                              : 'UPDATE',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentEnrollment == null) ...[
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            key: const ValueKey('add_more_enrollment_button'),
                            onPressed: _isLoading ? null : _handleAddMoreEnrollment,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text(
                              'Add More Enrollment',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(color: AppColors.primaryGreen),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMedium,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      SizedBox(
                        width: 120,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMedium,
                              ),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.borderLight,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C8248),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMedium,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const AppButtonLoader(
                                  color: Colors.white,
                                  size: 20,
                                  strokeWidth: 2,
                                )
                              : Text(
                                  _currentEnrollment == null
                                      ? 'SAVE'
                                      : 'UPDATE',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
