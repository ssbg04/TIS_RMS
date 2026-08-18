import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../shared/modals/custom_modal.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/setup_provider.dart';
import '../../../../domain/entities/setup_models.dart';

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

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    double maxDialogHeight = isMobile ? (screenHeight * 0.85) : 520;
    double dialogHeight = maxDialogHeight.clamp(
      200.0,
      screenHeight - viewInsets.bottom - 24.0,
    );

    return CustomModal(
      title: _currentEnrollment == null ? 'Add Enrollment' : 'Edit Enrollment',
      icon: _currentEnrollment == null
          ? Icons.add_box_outlined
          : Icons.edit_document,
      maxWidth: 480,
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Academic Year
                      yearsAsync.when(
                        data: (years) {
                          final selectedYearExists = years.any(
                            (y) => y.id == _selectedAcademicYearId,
                          );
                          final currentYearValue = selectedYearExists
                              ? _selectedAcademicYearId
                              : null;

                          return DropdownButtonFormField<int>(
                            key: const ValueKey('edit_enrollment_academic_dropdown'),
                            value: currentYearValue,
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
                              setState(() {
                                _selectedAcademicYearId = val;
                                // Reset Grade Level to default value of Grade 7
                                _selectedGradeLevel = 7;
                                // Clear section selection
                                _selectedSectionId = null;
                                _trackStrand = null;
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Academic year is required.' : null,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text(
                          'Error: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Grade Level
                      gradeLevelsAsync.when(
                        data: (grades) {
                          final selectedGradeExists = grades.any(
                            (g) => g.level == _selectedGradeLevel,
                          );
                          final currentGradeValue = selectedGradeExists
                              ? _selectedGradeLevel
                              : (grades.any((g) => g.level == 7)
                                  ? 7
                                  : (grades.isNotEmpty ? grades.first.level : null));

                          return DropdownButtonFormField<int>(
                            key: const ValueKey('edit_enrollment_grade_dropdown'),
                            value: currentGradeValue,
                            decoration: const InputDecoration(
                              labelText: 'Grade Level',
                              prefixIcon: Icon(Icons.grade),
                            ),
                            items: grades
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
                                // Clear section selection
                                _selectedSectionId = null;
                                if (val != null && val < 11) {
                                  _trackStrand = null;
                                }
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Grade level is required.' : null,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text(
                          'Error: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Section
                      sectionsAsync.when(
                        data: (sections) {
                          final filtered = sections
                              .where(
                                (sec) =>
                                    sec.academicYearId ==
                                        _selectedAcademicYearId &&
                                    sec.gradeLevel == _selectedGradeLevel,
                              )
                              .toList();

                          final matches = filtered.where(
                            (s) => s.id == _selectedSectionId,
                          );
                          final initialSectionName = matches.isNotEmpty
                              ? matches.first.name
                              : '';

                          final autocompleteKey = ValueKey(
                            'edit_enrollment_section_autocomplete_${_selectedAcademicYearId}_$_selectedGradeLevel',
                          );

                          return Autocomplete<SectionModel>(
                            key: autocompleteKey,
                            initialValue: TextEditingValue(
                              text: initialSectionName,
                            ),
                            displayStringForOption: (sec) => sec.name,
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return filtered;
                              }
                              return filtered.where(
                                (sec) => sec.name.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase(),
                                ),
                              );
                            },
                            onSelected: (sec) {
                              setState(() => _selectedSectionId = sec.id);
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Section (Type or Select)',
                                      prefixIcon: const Icon(Icons.segment),
                                      suffixIcon: const Icon(Icons.arrow_drop_down),
                                      hintText: filtered.isEmpty
                                          ? 'No sections available'
                                          : null,
                                    ),
                                    onChanged: (val) {
                                      if (val.isEmpty) {
                                        setState(
                                          () => _selectedSectionId = null,
                                        );
                                      } else {
                                        final exactMatches = filtered.where(
                                          (s) =>
                                              s.name.toLowerCase() ==
                                              val.toLowerCase(),
                                        );
                                        setState(
                                          () => _selectedSectionId =
                                              exactMatches.isNotEmpty
                                              ? exactMatches.first.id
                                              : null,
                                        );
                                      }
                                    },
                                    validator: (v) {
                                      if (v == null ||
                                          v.isEmpty ||
                                          _selectedSectionId == null) {
                                        return 'Please select a valid section.';
                                      }
                                      return null;
                                    },
                                  );
                                },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text(
                          'Error: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                      if (_selectedGradeLevel != null &&
                          _selectedGradeLevel! >= 11) ...[
                        const SizedBox(height: AppSizes.p16),
                        TextFormField(
                          initialValue: _trackStrand,
                          decoration: const InputDecoration(
                            labelText: 'Track & Strand (for SHS)',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          onChanged: (val) => _trackStrand = val.trim().isEmpty
                              ? null
                              : val.trim(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            if (_successMessage != null) ...[
              const SizedBox(height: 8),
              Container(
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
                child: Row(
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
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 450;
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentEnrollment == null) ...[
                          OutlinedButton.icon(
                            key: const ValueKey('add_more_enrollment_button'),
                            onPressed: _isLoading ? null : _handleAddMoreEnrollment,
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text(
                              'Add More Enrollment',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(color: AppColors.primaryGreen),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  'CANCEL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PrimaryButton(
                                label: 'SAVE',
                                isLoading: _isLoading,
                                onPressed: _handleSave,
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
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_currentEnrollment == null) ...[
                        OutlinedButton.icon(
                          key: const ValueKey('add_more_enrollment_button'),
                          onPressed: _isLoading ? null : _handleAddMoreEnrollment,
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: const Text(
                            'Add More Enrollment',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(color: AppColors.primaryGreen),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      SizedBox(
                        width: 130,
                        child: PrimaryButton(
                          label: 'SAVE',
                          isLoading: _isLoading,
                          onPressed: _handleSave,
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
