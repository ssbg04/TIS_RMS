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
import '../../../providers/student_provider.dart';
import 'edit_enrollment_modal.dart';
import 'student_form_helpers.dart';

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
  String? _errorMessage;

  late StudentModel _initialStudent;
  bool _isFetchingDetails = true;

  // Cache of all enrollments loaded for the student being edited
  List<dynamic>? _loadedEnrollments;

  static const _statuses = ['Enrolled', 'Graduated', 'Transferred', 'Dropped', 'Inactive'];
  static const _extSuggestions = [
    'N/A',
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
      int? latestGrade;
      if (_loadedEnrollments != null && _loadedEnrollments!.isNotEmpty) {
        final latestEnrollment = _loadedEnrollments!.reduce((a, b) {
          final ya = a.yearRange ?? '';
          final yb = b.yearRange ?? '';
          final cmp = ya.compareTo(yb);
          if (cmp != 0) return cmp > 0 ? a : b;
          return (a.gradeLevel ?? 0) > (b.gradeLevel ?? 0) ? a : b;
        });
        latestGrade = latestEnrollment.gradeLevel;
      }
      if (latestGrade != 10 && latestGrade != 12) {
        _showValidationDialog(
          'Graduation status is only applicable for Grade 10 and Grade 12 students.',
        );
        return;
      }
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
    }
  }

  Widget _buildStudentDetailsTab() {
    if (_isFetchingDetails) {
      return const Center(child: CircularProgressIndicator());
    }

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
            LayoutBuilder(
              builder: (ctx, c) {
                final wide = c.maxWidth > 480;

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
                  key: const ValueKey('edit_status_dropdown'),
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'STATUS',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  items: _statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedStatus = v);
                    }
                  },
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide)
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
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
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSizes.p12),
                              Expanded(
                                flex: 2,
                                child: ExtensionNameField(
                                  controller: _extController,
                                  suggestions: _extSuggestions,
                                ),
                              ),
                              const SizedBox(width: AppSizes.p12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _middleNameController,
                                  textCapitalization: TextCapitalization.characters,
                                  inputFormatters: [
                                    UpperCaseWordsFormatter(),
                                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'MIDDLE NAME (Optional)',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                              ),
                            ],
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
                            decoration: const InputDecoration(
                              labelText: 'LAST NAME',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
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
                          ExtensionNameField(
                            controller: _extController,
                            suggestions: _extSuggestions,
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
                  ],
                );
              },
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
                    ? Colors.deepPurple.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(
                  color: _is4ps
                      ? Colors.deepPurple.withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: SwitchListTile(
                value: _is4ps,
                onChanged: (val) {
                  setState(() => _is4ps = val);
                },
                activeColor: Colors.deepPurple,
                title: const Text('4Ps Beneficiary',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _is4ps
                      ? 'Student is a 4Ps (Pantawid Pamilyang Pilipino Program) beneficiary'
                      : 'Student is NOT a 4Ps beneficiary',
                  style: TextStyle(
                    fontSize: 11,
                    color: _is4ps
                        ? Colors.deepPurple.shade600
                        : AppColors.textSecondary,
                  ),
                ),
                secondary: Icon(Icons.family_restroom,
                    color: _is4ps ? Colors.deepPurple : Colors.grey.shade400),
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSizes.p16),
              ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: AppSizes.p24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _confirmClose,
                  child: const Text('CANCEL'),
                ),
                PrimaryButton(
                  label: 'UPDATE',
                  isLoading: _isLoading,
                  onPressed: _handleSaveDetails,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentsTab() {
    final detailAsync = ref.watch(studentDetailProvider(widget.student.id));

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

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Academic History (${sorted.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ElevatedButton.icon(
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
                    label: const Text('Add Enrollment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (sorted.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text(
                        'No enrollments recorded yet.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
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
                          color: Colors.white,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
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
          body: SafeArea(
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
    );
  }
}
