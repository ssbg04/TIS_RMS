import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/student_model.dart';

import '../../../shared/buttons/primary_button.dart';
import '../../../providers/student_provider.dart';

class AddEditStudentModal extends ConsumerStatefulWidget {
  final StudentModel? student; // null → Add mode, non-null → Edit mode

  const AddEditStudentModal({super.key, this.student});

  @override
  ConsumerState<AddEditStudentModal> createState() => _AddEditStudentModalState();
}

class _AddEditStudentModalState extends ConsumerState<AddEditStudentModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _lrnController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _extController;

  String    _selectedSex    = 'Male';
  String    _selectedStatus = 'Enrolled';
  DateTime? _selectedDob;
  bool      _isLoading      = false;
  String?   _errorMessage;

  static const _statuses = ['Enrolled', 'Graduated', 'Transferred Out', 'Dropped'];

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _lrnController        = TextEditingController(text: s?.lrn ?? '');
    _firstNameController  = TextEditingController(text: s?.firstName ?? '');
    _middleNameController = TextEditingController(text: s?.middleName ?? '');
    _lastNameController   = TextEditingController(text: s?.lastName ?? '');
    _extController        = TextEditingController(text: s?.extension ?? '');
    if (s != null) {
      _selectedSex    = s.sex;
      _selectedDob    = s.birthDate;
      _selectedStatus = s.status;
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

  // ----------------------------------------------------------------
  // VALIDATION HELPERS
  // ----------------------------------------------------------------
  String? _validateLRN(String? value) {
    if (value == null || value.trim().isEmpty) return 'LRN is required.';
    if (!RegExp(r'^\d{12}$').hasMatch(value.trim())) {
      return 'LRN must be exactly 12 digits (numbers only).';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    if (value.trim().length < 2) return '$fieldName must be at least 2 characters.';
    return null;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2010),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   AppColors.primaryGreen,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  // ----------------------------------------------------------------
  // SUBMIT
  // ----------------------------------------------------------------
  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);

    // 1. Form validation
    if (!_formKey.currentState!.validate()) return;

    // 2. DOB required check
    if (_selectedDob == null) {
      setState(() => _errorMessage = 'Please select a Date of Birth.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(studentMutationProvider.notifier);

      if (widget.student == null) {
        // ---- CREATE ----
        await notifier.createStudent(
          lrn:        _lrnController.text.trim(),
          firstName:  _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim().isEmpty
              ? null
              : _middleNameController.text.trim(),
          lastName:   _lastNameController.text.trim(),
          extension:  _extController.text.trim().isEmpty
              ? null
              : _extController.text.trim(),
          sex:        _selectedSex,
          birthDate:  _selectedDob!,
        );
      } else {
        // ---- UPDATE ----
        await notifier.updateStudent(
          id:         widget.student!.id,
          lrn:        _lrnController.text.trim(),
          firstName:  _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim().isEmpty
              ? null
              : _middleNameController.text.trim(),
          lastName:   _lastNameController.text.trim(),
          extension:  _extController.text.trim().isEmpty
              ? null
              : _extController.text.trim(),
          sex:        _selectedSex,
          birthDate:  _selectedDob!,
          status:     _selectedStatus,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      _showSuccessSnack();
    } catch (e) {
      if (!mounted) return;
      // Extract clean message from "Exception: ..." string
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      setState(() {
        _isLoading    = false;
        _errorMessage = msg;
      });
    }
  }

  void _showSuccessSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.student == null
              ? 'Student added successfully!'
              : 'Student updated successfully!',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ----------------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.student != null;

    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:     MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Header ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Update Student Record' : 'Add New Student',
                        style: const TextStyle(
                          fontSize:   22,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.primaryGreen,
                        ),
                      ),
                      IconButton(
                        icon:      const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // ---- Error Banner ----
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: AppSizes.p16),
                  ],

                  // ---- LRN ----
                  TextFormField(
                    controller:        _lrnController,
                    keyboardType:      TextInputType.number,
                    maxLength:         12,
                    inputFormatters:   [FilteringTextInputFormatter.digitsOnly],
                    validator:         _validateLRN,
                    decoration: const InputDecoration(
                      labelText:   'LRN (Learner Reference Number)',
                      hintText:    '12-digit number',
                      prefixIcon:  Icon(Icons.pin_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // ---- Name fields ----
                  LayoutBuilder(builder: (ctx, c) {
                    final wide = c.maxWidth > 400;
                    if (wide) {
                      return Column(children: [
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              validator: (v) => _validateRequired(v, 'First name'),
                              decoration: const InputDecoration(
                                labelText:  'First Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.p16),
                          Expanded(
                            child: TextFormField(
                              controller: _middleNameController,
                              decoration: const InputDecoration(
                                labelText:  'Middle Name (optional)',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: AppSizes.p16),
                        Row(children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _lastNameController,
                              validator: (v) => _validateRequired(v, 'Last name'),
                              decoration: const InputDecoration(
                                labelText:  'Last Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.p16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _extController,
                              decoration: const InputDecoration(
                                labelText:  'Ext.',
                                hintText:   'Jr / III',
                                prefixIcon: Icon(Icons.text_format),
                              ),
                            ),
                          ),
                        ]),
                      ]);
                    } else {
                      return Column(children: [
                        TextFormField(
                          controller: _firstNameController,
                          validator: (v) => _validateRequired(v, 'First name'),
                          decoration: const InputDecoration(labelText: 'First Name'),
                        ),
                        const SizedBox(height: AppSizes.p12),
                        TextFormField(
                          controller: _middleNameController,
                          decoration: const InputDecoration(labelText: 'Middle Name'),
                        ),
                        const SizedBox(height: AppSizes.p12),
                        TextFormField(
                          controller: _lastNameController,
                          validator: (v) => _validateRequired(v, 'Last name'),
                          decoration: const InputDecoration(labelText: 'Last Name'),
                        ),
                        const SizedBox(height: AppSizes.p12),
                        TextFormField(
                          controller: _extController,
                          decoration: const InputDecoration(labelText: 'Extension (Jr / III)'),
                        ),
                      ]);
                    }
                  }),
                  const SizedBox(height: AppSizes.p16),

                  // ---- Sex + DOB ----
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSex,
                        validator: (v) => v == null ? 'Please select sex.' : null,
                        decoration: const InputDecoration(
                          labelText:  'Sex',
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: ['Male', 'Female']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSex = v!),
                      ),
                    ),
                    const SizedBox(width: AppSizes.p16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText:  'Date of Birth',
                            prefixIcon: const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                            errorText:  (_isLoading == false && _errorMessage != null && _selectedDob == null)
                                        ? '' : null,
                          ),
                          child: Text(
                            _selectedDob == null
                                ? 'Select date…'
                                : '${_selectedDob!.year}-'
                                  '${_selectedDob!.month.toString().padLeft(2, '0')}-'
                                  '${_selectedDob!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color:    _selectedDob == null
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSizes.p16),

                  // ---- Status (edit only) ----
                  if (isEdit) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText:  'Status',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: _statuses
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                    ),
                    const SizedBox(height: AppSizes.p16),
                  ],

                  const SizedBox(height: AppSizes.p16),

                  // ---- Actions ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color:      AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.p16),
                      SizedBox(
                        width: 180,
                        child: PrimaryButton(
                          label:     isEdit ? 'UPDATE RECORD' : 'SAVE STUDENT',
                          isLoading: _isLoading,
                          onPressed: _handleSave,
                        ),
                      ),
                    ],
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

/// A clean inline error banner
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        AppColors.error.withValues(alpha: 0.08),
        border:       Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:    AppColors.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}