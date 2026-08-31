import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/student_model.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/setup_provider.dart';
import 'edit_enrollment_modal.dart';
import 'ocr_enrollment_validation_modal.dart';
import 'student_form_helpers.dart';
import '../../../shared/widgets/app_button_loader.dart';

class EditStudentModal extends ConsumerStatefulWidget {
  final StudentModel student;

  const EditStudentModal({
    super.key,
    required this.student,
  });

  @override
  ConsumerState<EditStudentModal> createState() => _EditStudentModalState();
}

class _EditStudentModalState extends ConsumerState<EditStudentModal> {
  final _studentFormKey = GlobalKey<FormState>();

  late TextEditingController _lrnController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _extController;

  late String _selectedSex;
  late String _selectedStatus;
  DateTime? _selectedDob;
  late bool _is4ps;

  bool _isLoading = false;
  bool _isOcrScanning = false;
  String? _errorMessage;

  late StudentModel _initialStudent;
  bool _isFetchingDetails = true;

  // Cache of all enrollments loaded for the student being edited
  List<EnrollmentModel>? _loadedEnrollments;
  int _statusDropdownKey = 0;

  static const _statuses = ['Enrolled', 'Graduated', 'Transferred', 'Dropped', 'Inactive'];
  static const _extSuggestions = [
    'JR.',
    'SR.',
    'II',
    'III',
    'IV',
    'V',
    'VI',
  ];

  @override
  void initState() {
    super.initState();
    _initialStudent = widget.student;

    _lrnController = TextEditingController(text: _initialStudent.lrn);
    _firstNameController = TextEditingController(text: _initialStudent.firstName);
    _middleNameController =
        TextEditingController(text: _initialStudent.middleName ?? '');
    _lastNameController = TextEditingController(text: _initialStudent.lastName);
    _extController = TextEditingController(text: _initialStudent.extension ?? '');

    _selectedSex = _initialStudent.sex;
    _selectedStatus = _initialStudent.status;
    _selectedDob = _initialStudent.birthDate;
    _is4ps = _initialStudent.is4ps;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(sectionsListProvider);
      }
    });

    Future.microtask(_fetchFullDetails);
  }

  Future<void> _fetchFullDetails() async {
    try {
      final fullStudent =
          await ref.read(studentDetailProvider(widget.student.id).future);
      if (mounted) {
        setState(() {
          // If the user hasn't made any edits yet, update the controllers
          if (!_hasChanges) {
            _lrnController.text = fullStudent.lrn;
            _firstNameController.text = fullStudent.firstName;
            _middleNameController.text = fullStudent.middleName ?? '';
            _lastNameController.text = fullStudent.lastName;
            _extController.text = fullStudent.extension ?? '';
            _selectedSex = fullStudent.sex;
            _selectedStatus = fullStudent.status;
            _selectedDob = fullStudent.birthDate;
            _is4ps = fullStudent.is4ps;
          }
          _initialStudent = fullStudent;
          _loadedEnrollments = fullStudent.enrollments;
          _isFetchingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingDetails = false);
      }
    }
  }

  @override
  void dispose() {
    _lrnController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _extController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _lrnController.text.trim() != _initialStudent.lrn ||
        _firstNameController.text.trim() != _initialStudent.firstName ||
        _lastNameController.text.trim() != _initialStudent.lastName ||
        (_middleNameController.text.trim().isEmpty
                ? null
                : _middleNameController.text.trim()) !=
            _initialStudent.middleName ||
        (_extController.text.trim().isEmpty
                ? null
                : _extController.text.trim()) !=
            _initialStudent.extension ||
        _selectedSex != _initialStudent.sex ||
        _selectedStatus != _initialStudent.status ||
        _selectedDob != _initialStudent.birthDate ||
        _is4ps != _initialStudent.is4ps;
  }

  void _confirmClose() {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes to this student. Are you sure you want to close this window?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );
  }

  String? _validateLRN(String? value) {
    if (value == null || value.trim().isEmpty) return 'LRN is required.';
    if (!RegExp(r'^\d{12}$').hasMatch(value.trim())) {
      return 'LRN must be exactly 12 digits (numbers only).';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  void _showValidationDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Missing Information'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasGraduationEligibleGrade() {
    if (_loadedEnrollments != null && _loadedEnrollments!.isNotEmpty) {
      return _loadedEnrollments!.any((e) => e.gradeLevel == 10 || e.gradeLevel == 12);
    }
    if (_initialStudent.enrollments != null && _initialStudent.enrollments!.isNotEmpty) {
      return _initialStudent.enrollments!.any((e) => e.gradeLevel == 10 || e.gradeLevel == 12);
    }
    final grade = widget.student.latestGradeLevel;
    return grade == 10 || grade == 12;
  }

  List<String> get _availableStatuses {
    if (_hasGraduationEligibleGrade() ||
        _selectedStatus == 'Graduated' ||
        _initialStudent.status == 'Graduated') {
      return _statuses;
    }
    return _statuses.where((s) => s != 'Graduated').toList();
  }

  int? _getLatestGradeLevel() {
    if (_loadedEnrollments != null && _loadedEnrollments!.isNotEmpty) {
      EnrollmentModel? best;
      for (final e in _loadedEnrollments!) {
        if (best == null) {
          best = e;
          continue;
        }
        if (e.gradeLevel > best.gradeLevel) {
          best = e;
        } else if (e.gradeLevel == best.gradeLevel) {
          final ya = e.yearRange ?? '';
          final yb = best.yearRange ?? '';
          final cmp = ya.compareTo(yb);
          if (cmp > 0) {
            best = e;
          }
        }
      }
      return best?.gradeLevel;
    }
    return widget.student.latestGradeLevel;
  }

  Future<void> _handleSaveDetails() async {
    setState(() => _errorMessage = null);

    final lrnErr = _validateLRN(_lrnController.text);
    final fnErr = _validateRequired(_firstNameController.text, 'First name');
    final lnErr = _validateRequired(_lastNameController.text, 'Last name');

    if (lrnErr != null || fnErr != null || lnErr != null) {
      _studentFormKey.currentState?.validate();
      final missing = <String>[];
      if (lrnErr != null) missing.add('LRN ($lrnErr)');
      if (fnErr != null) missing.add('First Name');
      if (lnErr != null) missing.add('Last Name');
      _showValidationDialog(
        'Please fill in all required fields:\n\n${missing.map((e) => '• $e').join('\n')}',
      );
      return;
    }

    if (_selectedStatus == 'Graduated') {
      if (!_hasGraduationEligibleGrade()) {
        final latestGrade = _getLatestGradeLevel();
        _showValidationDialog(
          'Graduation status is only applicable for Grade 10 and Grade 12 students.\n\n'
          'This student is currently ${latestGrade != null ? 'in Grade $latestGrade' : 'not enrolled in Grade 10 or 12'}.',
        );
        return;
      }
    }

    if (!_hasChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(studentMutationProvider.notifier);
      await notifier.updateStudent(
        id: widget.student.id,
        lrn: _lrnController.text.trim(),
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim().isEmpty
            ? null
            : _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        extension: _extController.text.trim().isEmpty
            ? null
            : _extController.text.trim(),
        sex: _selectedSex,
        birthDate: _selectedDob,
        status: _selectedStatus,
        is4ps: _is4ps,
      );
      if (!mounted) return;
      ref.invalidate(studentPageProvider);
      ref.invalidate(studentDetailProvider(widget.student.id));
      await showSuccessDialog(
        context,
        message: 'Student updated successfully!',
      );
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
      showErrorDialog(context, 'Update Failed', msg);
    }
  }

  Widget _buildStudentDetailsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isFetchingDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 500;

        final isEligibleForGraduation =
            _hasGraduationEligibleGrade() ||
            _initialStudent.status == 'Graduated';
        final currentGrade = _getLatestGradeLevel();

        final sexDropdown = DropdownButtonFormField<String>(
          key: const ValueKey('edit_sex_dropdown'),
          initialValue: _selectedSex,
          validator: (v) => v == null ? 'Please select sex.' : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'SEX',
            prefixIcon: Icon(Icons.wc),
          ),
          items: ['Male', 'Female']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _selectedSex = v);
            }
          },
        );

        final statusDropdown = DropdownButtonFormField<String>(
          key: ValueKey('edit_status_dropdown_${_selectedStatus}_$_statusDropdownKey'),
          initialValue: _selectedStatus,
          decoration: InputDecoration(
            labelText: 'STATUS',
            prefixIcon: const Icon(Icons.info_outline),
            helperText: !isEligibleForGraduation
                ? 'Graduation requires Grade 10 or 12 (${currentGrade != null ? 'Grade $currentGrade' : 'No Grade 10/12'})'
                : null,
          ),
          items: _availableStatuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            if (v == 'Graduated') {
              if (!_hasGraduationEligibleGrade()) {
                final grade = _getLatestGradeLevel();
                _showValidationDialog(
                  'Graduation status is only applicable for Grade 10 and Grade 12 students.\n\n'
                  'This student is currently ${grade != null ? 'in Grade $grade' : 'not enrolled in Grade 10 or 12'}.',
                );
                setState(() {
                  _statusDropdownKey++;
                });
                return;
              }
            }
            setState(() {
              _selectedStatus = v;
            });
          },
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _studentFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(label: 'LEARNER REFERENCE INFORMATION'),
                const SizedBox(height: AppSizes.p8),
                TextFormField(
                  controller: _lrnController,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validateLRN,
                  decoration: const InputDecoration(
                    labelText: 'LRN (Learner Reference Number)',
                    hintText: '12-digit number',
                    prefixIcon: Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                const SectionLabel(label: 'NAME'),
                const SizedBox(height: AppSizes.p8),
                if (wide)
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                UpperCaseWordsFormatter(),
                                FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                              ],
                              validator: (v) => _validateRequired(v, 'First name'),
                              decoration: const InputDecoration(
                                labelText: 'FIRST NAME',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.p12),
                          Expanded(
                            child: TextFormField(
                              controller: _middleNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                UpperCaseWordsFormatter(),
                                FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'MIDDLE NAME (Optional)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                UpperCaseWordsFormatter(),
                                FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                              ],
                              validator: (v) => _validateRequired(v, 'Last name'),
                              decoration: const InputDecoration(
                                labelText: 'LAST NAME',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.p12),
                          Expanded(
                            child: ExtensionNameField(
                              controller: _extController,
                              suggestions: _extSuggestions,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          UpperCaseWordsFormatter(),
                          FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                        ],
                        validator: (v) => _validateRequired(v, 'First name'),
                        decoration: const InputDecoration(labelText: 'FIRST NAME'),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      TextFormField(
                        controller: _middleNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          UpperCaseWordsFormatter(),
                          FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                        ],
                        decoration: const InputDecoration(labelText: 'MIDDLE NAME (Optional)'),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          UpperCaseWordsFormatter(),
                          FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                        ],
                        validator: (v) => _validateRequired(v, 'Last name'),
                        decoration: const InputDecoration(labelText: 'LAST NAME'),
                      ),
                      const SizedBox(height: AppSizes.p12),
                      ExtensionNameField(
                        controller: _extController,
                        suggestions: _extSuggestions,
                      ),
                    ],
                  ),
                const SizedBox(height: AppSizes.p16),
                const SectionLabel(label: 'PERSONAL INFORMATION'),
                const SizedBox(height: AppSizes.p8),
                if (wide)
                  Row(
                    children: [
                      Expanded(child: sexDropdown),
                      const SizedBox(width: AppSizes.p12),
                      Expanded(child: statusDropdown),
                    ],
                  )
                else
                  Column(
                    children: [
                      sexDropdown,
                      const SizedBox(height: AppSizes.p12),
                      statusDropdown,
                    ],
                  ),
                const SizedBox(height: AppSizes.p12),
                DobPicker(
                  initialDate: _selectedDob,
                  onChanged: (val) {
                    setState(() => _selectedDob = val);
                  },
                ),
                const SizedBox(height: AppSizes.p16),
                const SectionLabel(label: 'GOVERNMENT AID STATUS'),
                const SizedBox(height: AppSizes.p8),
                Container(
                  decoration: BoxDecoration(
                    color: _is4ps
                        ? AppColors.fourPs.withValues(alpha: 0.06)
                        : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    border: Border.all(
                      color: _is4ps
                          ? AppColors.fourPs.withValues(alpha: 0.3)
                          : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                    ),
                  ),
                  child: SwitchListTile(
                    value: _is4ps,
                    onChanged: (val) {
                      setState(() => _is4ps = val);
                    },
                    activeThumbColor: AppColors.fourPs,
                    title: const Text('4Ps Beneficiary',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      _is4ps
                          ? 'Student is a 4Ps (Pantawid Pamilyang Pilipino Program) beneficiary'
                          : 'Student is NOT a 4Ps beneficiary',
                      style: TextStyle(
                        fontSize: 11,
                        color: _is4ps
                            ? (isDark ? const Color(0xFF8B8ED8) : AppColors.fourPs)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                    secondary: Icon(Icons.family_restroom,
                        color: _is4ps ? AppColors.fourPs : Colors.grey.shade400),
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
                const SizedBox(height: AppSizes.p16),
                if (_errorMessage != null) ...[
                  ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: AppSizes.p16),
                ],
                Builder(
                  builder: (ctx) {
                    final isKeyboardOpen = MediaQuery.of(ctx).viewInsets.bottom > 50;
                    if (isKeyboardOpen) return const SizedBox.shrink();
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PrimaryButton(
                            label: 'UPDATE',
                            isLoading: _isLoading,
                            onPressed: _handleSaveDetails,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _confirmClose,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                              ),
                            ),
                            child: const Text('CANCEL'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _confirmClose,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            ),
                          ),
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSaveDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            ),
                          ),
                          child: _isLoading
                              ? const AppButtonLoader(
                                  color: Colors.white,
                                  size: 18,
                                  strokeWidth: 2,
                                )
                              : const Text(
                                  'UPDATE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleScanEnrollmentFromSF() async {
    setState(() => _isOcrScanning = true);
    try {
      final records = await ref
          .read(studentMutationProvider.notifier)
          .scanEnrollmentFromSF(widget.student.id);

      if (!mounted) return;

      if (records.isEmpty) {
        showErrorDialog(
          context,
          'OCR Scan Failed',
          'No Grade 7-12 enrollment records were detected from the '
          'SF9/SF10 documents.',
        );
        return;
      }

      final accepted = await OcrEnrollmentValidationModal.show(
        context,
        studentId: widget.student.id,
        records: records,
      );

      if (!mounted) return;

      ref.invalidate(studentDetailProvider(widget.student.id));
      ref.invalidate(studentPageProvider);

      if (accepted > 0) {
        await showSuccessDialog(
          context,
          message: '$accepted enrollment record(s) added.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      showErrorDialog(context, 'OCR Scan Failed', msg);
    } finally {
      if (mounted) setState(() => _isOcrScanning = false);
    }
  }

  Widget _buildEnrollmentsTab() {
    final detailAsync = ref.watch(studentDetailProvider(widget.student.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return detailAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading enrollments: $e')),
      data: (detailStudent) {
        final enrollments = detailStudent.enrollments ?? [];
        _loadedEnrollments = enrollments;

        final sorted = List.from(enrollments);
        sorted.sort(
          (a, b) => (b.gradeLevel ?? 0).compareTo(a.gradeLevel ?? 0),
        );

        final isMobile = MediaQuery.of(context).size.width < 600;

        Widget buildHeaderButtons({required bool expanded}) {
          final ocrButton = OutlinedButton.icon(
            onPressed: _isOcrScanning ? null : _handleScanEnrollmentFromSF,
            icon: _isOcrScanning
                ? const AppButtonLoader(
                    color: AppColors.primaryGreen,
                    size: 16,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.document_scanner, size: 18),
            label: Text(
              isMobile
                  ? (_isOcrScanning ? 'Scanning...' : 'OCR Scan')
                  : (_isOcrScanning
                      ? 'Scanning...'
                      : 'OCR Scan (SF9/SF10)'),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 14,
                vertical: 10,
              ),
            ),
          );

          final addButton = ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.45),
                builder: (ctx) => EditEnrollmentModal(
                  studentId: widget.student.id,
                  enrollment: null,
                ),
              ).then((_) {
                if (mounted) {
                  ref.invalidate(studentDetailProvider(widget.student.id));
                  ref.invalidate(studentPageProvider);
                }
              });
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Add Enrollment',
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 14,
                vertical: 10,
              ),
            ),
          );

          if (expanded) {
            return Row(
              children: [
                Expanded(child: ocrButton),
                const SizedBox(width: 8),
                Expanded(child: addButton),
              ],
            );
          } else {
            return Row(
              children: [
                ocrButton,
                const SizedBox(width: 8),
                addButton,
              ],
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile) ...[
                Text(
                  'Academic History (${sorted.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                buildHeaderButtons(expanded: true),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Academic History (${sorted.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    buildHeaderButtons(expanded: false),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // ── Downgrade / Correction Guidance Note ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.12)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF1E293B),
                          ),
                          children: [
                            TextSpan(
                              text: 'Note on Downgrading: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade700,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  'To correct a mistake or downgrade a student\'s grade level, delete the higher enrollment record(s) first to bypass downgrading restrictions.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (sorted.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 48, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No enrollments recorded yet.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final enrollment = sorted[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
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
                              child: const Icon(
                                Icons.school,
                                color: Colors.blue,
                                size: 20,
                              ),
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
                                    '${enrollment.sectionName ?? 'N/A'} · ${enrollment.yearRange ?? 'N/A'}',
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
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  size: 18, color: Colors.blue),
                              tooltip: 'Edit Enrollment',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  barrierColor:
                                      Colors.black.withValues(alpha: 0.45),
                                  builder: (ctx) => EditEnrollmentModal(
                                    studentId: widget.student.id,
                                    enrollment: enrollment,
                                  ),
                                ).then((_) {
                                  if (mounted) {
                                    ref.invalidate(
                                        studentDetailProvider(widget.student.id));
                                    ref.invalidate(studentPageProvider);
                                  }
                                });
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
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text('CANCEL'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          ref
                                              .read(studentMutationProvider
                                                  .notifier)
                                              .deleteEnrollment(
                                                studentId: widget.student.id,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: AppColors.primaryGreen,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              onPressed: _confirmClose,
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
            automaticallyImplyLeading: false,
            title: Text(
              'Edit Student: ${widget.student.fullName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: [
                Tab(
                    icon: (!kIsWeb && Platform.isAndroid) ? null : const Icon(Icons.person_outline, size: 20),
                    text: 'Student Details'),
                Tab(
                    icon: (!kIsWeb && Platform.isAndroid) ? null : const Icon(Icons.school_outlined, size: 20),
                    text: 'Enrollments'),
              ],
            ),
          ),
          body: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            behavior: HitTestBehavior.translucent,
            child: SafeArea(
              child: Column(
                children: [
                  if (_isLoading)
                    const LinearProgressIndicator(
                      color: AppColors.primaryGreen,
                      backgroundColor: Color(0xFFE0E0E0),
                      minHeight: 3,
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildStudentDetailsTab(),
                        _buildEnrollmentsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
