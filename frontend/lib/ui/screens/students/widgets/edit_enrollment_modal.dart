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
    Key? key,
    required this.studentId,
    this.enrollment,
  }) : super(key: key);

  @override
  ConsumerState<EditEnrollmentModal> createState() =>
      _EditEnrollmentModalState();
}

class _EditEnrollmentModalState extends ConsumerState<EditEnrollmentModal> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.enrollment != null) {
      _selectedAcademicYearId = widget.enrollment.academicYearId;
      _selectedGradeLevel = widget.enrollment.gradeLevel;
      _selectedSectionId = widget.enrollment.sectionId;
      _trackStrand = widget.enrollment.trackStrand;
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
    if (_selectedSectionId == null) {
      _showValidationDialog('Please select a valid section.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(studentMutationProvider.notifier);
      if (widget.enrollment == null) {
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
          enrollmentId: widget.enrollment.id,
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

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    double maxDialogHeight = isMobile ? (screenHeight * 0.8) : 480;
    double dialogHeight = maxDialogHeight.clamp(
      200.0,
      screenHeight - viewInsets.bottom - 24.0,
    );

    return CustomModal(
      title: widget.enrollment == null ? 'Add Enrollment' : 'Edit Enrollment',
      icon: widget.enrollment == null
          ? Icons.add_box_outlined
          : Icons.edit_document,
      maxWidth: 450,
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
                          return DropdownButtonFormField<int>(
                            key: const ValueKey('edit_enrollment_academic_dropdown'),
                            initialValue: _selectedAcademicYearId,
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
                                _selectedSectionId = null;
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
                          return DropdownButtonFormField<int>(
                            key: const ValueKey('edit_enrollment_grade_dropdown'),
                            initialValue: _selectedGradeLevel,
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
                                _selectedSectionId = null;
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

                          const autocompleteKey = ValueKey(
                            'edit_enrollment_section_autocomplete',
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
                                    decoration: const InputDecoration(
                                      labelText: 'Section (Type or Select)',
                                      prefixIcon: Icon(Icons.segment),
                                      suffixIcon: Icon(Icons.arrow_drop_down),
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
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSizes.p12,
                runSpacing: AppSizes.p8,
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
                  SizedBox(
                    width: 150,
                    child: PrimaryButton(
                      label: 'SAVE',
                      isLoading: _isLoading,
                      onPressed: _handleSave,
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
}
