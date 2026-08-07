import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/ocr_provider.dart';
import '../../../providers/student_provider.dart';
import '../../documents/widgets/document_preview_modal.dart';
import '../../../shared/inputs/document_source_picker.dart';
import 'student_form_helpers.dart';

class AddStudentModal extends ConsumerStatefulWidget {
  const AddStudentModal({super.key});

  @override
  ConsumerState<AddStudentModal> createState() => _AddStudentModalState();
}

class _AddStudentModalState extends ConsumerState<AddStudentModal> {
  final _studentFormKey = GlobalKey<FormState>();
  final _enrollmentFormKey = GlobalKey<FormState>();

  late TextEditingController _lrnController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _extController;

  int _currentStep = 0;
  String _selectedSex = 'Male';
  DateTime? _selectedDob;
  bool _is4ps = false;
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;

  File? _ocrScannedFile;
  String? _selectedOcrDocType;

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
    _lrnController = TextEditingController();
    _firstNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _extController = TextEditingController();
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

  bool get _hasAnyData {
    return _lrnController.text.isNotEmpty ||
        _firstNameController.text.isNotEmpty ||
        _lastNameController.text.isNotEmpty;
  }

  void _confirmClose() {
    if (!_hasAnyData) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved information. Are you sure you want to close this window?',
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

  String? _detectDocType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('sf9') ||
        lower.contains('sf-9') ||
        lower.contains('sf 9') ||
        lower.contains('report card') ||
        lower.contains('reportcard')) {
      return 'SF9';
    }
    if (lower.contains('sf10') ||
        lower.contains('sf-10') ||
        lower.contains('sf 10') ||
        lower.contains('permanent record') ||
        lower.contains('permanentrecord') ||
        lower.contains('school form 10') ||
        lower.contains('school-form-10')) {
      return 'SF10';
    }
    return null;
  }

  Future<String?> _askDocType() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        icon: const Icon(
          Icons.help_outline_rounded,
          color: AppColors.primaryGreen,
          size: 36,
        ),
        title: const Text(
          'Select Document Type',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          "Couldn't auto-detect the document type from the filename.\n"
          'Please select the correct type:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 20,
          top: 8,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop('SF9'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'SF9\nReport Card',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop('SF10'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'SF10\nPermanent Record',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseFlexibleDob(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final str = input.trim();
    try {
      return DateTime.parse(str);
    } catch (_) {}
    final slash = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})$').firstMatch(str);
    if (slash != null) {
      int m = int.parse(slash.group(1)!);
      int d = int.parse(slash.group(2)!);
      int y = int.parse(slash.group(3)!);
      if (y < 100) y += (y <= 30 ? 2000 : 1900);
      if (m > 12 && d <= 12) {
        final tmp = m;
        m = d;
        d = tmp;
      }
      return DateTime(y, m, d);
    }
    return null;
  }

  Future<void> _handleOcrScan(
    File file,
    String fileName,
    String fileSize,
  ) async {
    setState(() {
      _errorMessage = null;
      _ocrScannedFile = file;
    });

    String? docType = _detectDocType(fileName);
    if (docType == null) {
      if (!mounted) return;
      docType = await _askDocType();
    }

    if (docType == null || !mounted) return;
    setState(() {
      _selectedOcrDocType = docType;
      _isLoading = true;
    });

    try {
      final ocrResult = await ref
          .read(ocrProvider.notifier)
          .processDocument(file: file, fileName: fileName, docType: docType);
      if (!mounted || ocrResult == null) return;
      setState(() {
        if (ocrResult.lrn.isNotEmpty) _lrnController.text = ocrResult.lrn;
        if (ocrResult.firstName.isNotEmpty) {
          _firstNameController.text = ocrResult.firstName;
        }
        if (ocrResult.lastName.isNotEmpty) {
          _lastNameController.text = ocrResult.lastName;
        }
        if (ocrResult.middleName.isNotEmpty) {
          _middleNameController.text = ocrResult.middleName;
        }
        if (ocrResult.extension.isNotEmpty) {
          _extController.text = ocrResult.extension;
        }
        if (ocrResult.sex == 'Male' || ocrResult.sex == 'Female') {
          _selectedSex = ocrResult.sex;
        }
        if (ocrResult.dob != null && ocrResult.dob!.isNotEmpty) {
          _selectedDob = _parseFlexibleDob(ocrResult.dob);
        }
        _ocrScannedFile = file;
        _selectedOcrDocType = docType;
        _currentStep = 1;
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    if (!(_enrollmentFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedAcademicYearId == null) {
      setState(() => _errorMessage = 'Please select an Academic Year.');
      return;
    }
    if (_selectedGradeLevel == null) {
      setState(() => _errorMessage = 'Please select a Grade Level.');
      return;
    }
    if (_selectedSectionId == null) {
      setState(() => _errorMessage = 'Please select a Section.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(studentMutationProvider.notifier);
      await notifier.createStudent(
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
        academicYearId: _selectedAcademicYearId!,
        gradeLevel: _selectedGradeLevel!,
        sectionId: _selectedSectionId!,
        trackStrand: _trackStrand,
        is4ps: _is4ps,
      );
      if (!mounted) return;
      ref.invalidate(studentPageProvider);
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

  // ----------------------------------------------------------------
  // STEPS UI
  // ----------------------------------------------------------------
  Widget _buildOcrStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.p32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSizes.p16),
              Text(
                'Processing document with OCR... Please wait',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          ErrorBanner(message: _errorMessage!),
          const SizedBox(height: AppSizes.p16),
        ],
        Container(
          padding: const EdgeInsets.all(AppSizes.p12),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pick a file — the document type (SF9 or SF10) will be '
                  'detected automatically from the filename. If it cannot '
                  'be detected, you will be asked to confirm.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.p16),
        DocumentSourcePicker(
          allowedExtensions: const ['pdf', 'jpg', 'png', 'jpeg', 'xlsx', 'xls', 'csv'],
          onFileSelected: _handleOcrScan,
          onError: (err) => setState(() => _errorMessage = err),
        ),
        const SizedBox(height: AppSizes.p24),
      ],
    );
  }

  Widget _buildStudentDetailsStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
      key: _studentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_ocrScannedFile != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSizes.p12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scan complete! OCR extracted data from your document. Please review and verify all auto-filled fields before proceeding.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p16),
          ],
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
              if (wide) {
                return Column(
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
                );
              } else {
                return Column(
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
                );
              }
            },
          ),
          const SizedBox(height: AppSizes.p16),
          const SectionLabel(label: 'PERSONAL INFORMATION'),
          const SizedBox(height: AppSizes.p8),
          DropdownButtonFormField<String>(
            key: const ValueKey('sex_dropdown'),
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
                  : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              border: Border.all(
                color: _is4ps
                    ? Colors.deepPurple.withValues(alpha: 0.3)
                    : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
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
                      ? (isDark ? Colors.deepPurple[200] : Colors.deepPurple.shade600)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
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
        ],
      ),
    );
  }

  Widget _buildEnrollmentStep(
    AsyncValue<List<AcademicYearModel>> yearsAsync,
    AsyncValue<List<GradeLevelModel>> gradeLevelsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
  ) {
    return Form(
      key: _enrollmentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'ENROLLMENT DETAILS'),
          const SizedBox(height: AppSizes.p16),
          yearsAsync.when(
            data: (years) {
              final active = years
                  .where((y) => y.status.toLowerCase() == 'active')
                  .toList();
              final defaultYearId = (active.isNotEmpty ? active.last : (years.isNotEmpty ? years.last : null))?.id;
              final currentYearId = _selectedAcademicYearId ?? defaultYearId;

              return DropdownButtonFormField<int>(
                key: const ValueKey('academic_year_dropdown'),
                initialValue: currentYearId,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: years
                    .map((y) => DropdownMenuItem<int>(
                        value: y.id, child: Text(y.yearRange)))
                    .toList(),
                onChanged: (val) => setState(() {
                  _selectedAcademicYearId = val;
                  _selectedSectionId = null;
                }),
                validator: (v) => v == null ? 'Academic year is required.' : null,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                Text('Error: $err', style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: AppSizes.p12),
          gradeLevelsAsync.when(
            data: (grades) {
              return DropdownButtonFormField<int>(
                key: const ValueKey('grade_level_dropdown'),
                initialValue: _selectedGradeLevel,
                decoration: const InputDecoration(
                  labelText: 'Grade Level',
                  prefixIcon: Icon(Icons.grade),
                ),
                items: grades
                    .map((g) => DropdownMenuItem<int>(
                        value: g.level, child: Text(g.name)))
                    .toList(),
                onChanged: (val) => setState(() {
                  _selectedGradeLevel = val;
                  _selectedSectionId = null;
                }),
                validator: (v) => v == null ? 'Grade level is required.' : null,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                Text('Error: $err', style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: AppSizes.p12),
          sectionsAsync.when(
            data: (sections) {
              final activeYears = yearsAsync.value?.where((y) => y.status.toLowerCase() == 'active').toList();
              final defaultYearId = (activeYears != null && activeYears.isNotEmpty ? activeYears.last : (yearsAsync.value != null && yearsAsync.value!.isNotEmpty ? yearsAsync.value!.last : null))?.id;
              final effectiveYearId = _selectedAcademicYearId ?? defaultYearId;

              final filtered = sections
                  .where((sec) =>
                      sec.academicYearId == effectiveYearId &&
                      sec.gradeLevel == _selectedGradeLevel)
                  .toList();
              final matches = filtered.where((s) => s.id == _selectedSectionId);
              final initialSectionName =
                  matches.isNotEmpty ? matches.first.name : '';
              return Autocomplete<SectionModel>(
                key: const ValueKey('section_autocomplete'),
                initialValue: TextEditingValue(text: initialSectionName),
                displayStringForOption: (sec) => sec.name,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return filtered;
                  return filtered.where(
                    (sec) => sec.name
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()),
                  );
                },
                onSelected: (sec) => setState(() => _selectedSectionId = sec.id),
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
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
                        setState(() => _selectedSectionId = null);
                      } else {
                        final exactMatches = filtered.where(
                          (s) => s.name.toLowerCase() == val.toLowerCase(),
                        );
                        setState(() => _selectedSectionId =
                            exactMatches.isNotEmpty
                                ? exactMatches.first.id
                                : null);
                      }
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty || _selectedSectionId == null) {
                        return 'Please select a valid section.';
                      }
                      return null;
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                Text('Error: $err', style: const TextStyle(color: Colors.red)),
          ),
          if (_selectedGradeLevel != null && _selectedGradeLevel! >= 11) ...[
            const SizedBox(height: AppSizes.p12),
            TextFormField(
              initialValue: _trackStrand,
              decoration: const InputDecoration(
                labelText: 'Track & Strand (for SHS)',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              onChanged: (val) =>
                  _trackStrand = val.trim().isEmpty ? null : val.trim(),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSizes.p16),
            ErrorBanner(message: _errorMessage!),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    final isLastStep = _currentStep == 2;
    final isOcrStep = _currentStep == 0;

    Widget stepContent;
    switch (_currentStep) {
      case 0:
        stepContent = _buildOcrStep();
      case 1:
        stepContent = _buildStudentDetailsStep();
      case 2:
        stepContent = _buildEnrollmentStep(yearsAsync, gradeLevelsAsync, sectionsAsync);
      default:
        stepContent = _buildOcrStep();
    }

    return PopScope(
      canPop: !_hasAnyData,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
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
          title: const Text(
            'Add New Student',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
              ColorLineStepper(
                totalSteps: 3,
                currentStep: _currentStep,
              ),
              if (_isLoading)
                const LinearProgressIndicator(
                  color: AppColors.primaryGreen,
                  backgroundColor: Color(0xFFE0E0E0),
                  minHeight: 3,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: stepContent,
                ),
              ),
              Builder(
                builder: (ctx) {
                  final isKeyboardOpen = MediaQuery.of(ctx).viewInsets.bottom > 100;
                  if (isKeyboardOpen) return const SizedBox.shrink();
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmallScreen = constraints.maxWidth < 480;

                        if (isSmallScreen && !isOcrStep) {
                          return Row(
                            children: [
                              if (_currentStep > 0) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _errorMessage = null;
                                      _currentStep -= 1;
                                    }),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: BorderSide(color: isDark ? Colors.white : Colors.black),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusMedium,
                                        ),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.arrow_back,
                                      size: 16,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    label: Text(
                                      'BACK',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: PrimaryButton(
                                  label: isLastStep ? 'ADD' : 'NEXT',
                                  isLoading: _isLoading && isLastStep,
                                  onPressed: () {
                                    if (_currentStep == 1) {
                                      final isValid = _studentFormKey.currentState?.validate() ?? false;
                                      if (!isValid) {
                                        setState(() {
                                          _errorMessage =
                                              'Please complete all required fields in red before proceeding to Enrollment.';
                                        });
                                        return;
                                      }
                                    }
                                    if (isLastStep) {
                                      _handleSave();
                                    } else {
                                      setState(() {
                                        _errorMessage = null;
                                        _currentStep += 1;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        }

                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            // Left side items
                            if (!isOcrStep && _ocrScannedFile != null)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => setState(() {
                                      _lrnController.clear();
                                      _firstNameController.clear();
                                      _middleNameController.clear();
                                      _lastNameController.clear();
                                      _extController.clear();
                                      _currentStep = 0;
                                    }),
                                    icon: const Icon(
                                      Icons.refresh,
                                      size: 16,
                                      color: AppColors.primaryGreen,
                                    ),
                                    label: const Text(
                                      'Scan Another',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      if (_ocrScannedFile != null) {
                                        showDocumentPreview(
                                          context: context,
                                          localFile: _ocrScannedFile!,
                                          localFileName: _ocrScannedFile!.path.split('/').last,
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      Icons.visibility_outlined,
                                      size: 16,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                    label: Text(
                                      'Preview Document',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),

                            // Right side items
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                if (isOcrStep) ...[
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _errorMessage = null;
                                      _currentStep = 1;
                                    }),
                                    icon: Icon(Icons.edit_note, size: 16, color: isDark ? Colors.white : Colors.black),
                                    label: Text('MANUAL INPUT', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      side: BorderSide(color: isDark ? Colors.white : Colors.black),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusMedium,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  if (_currentStep > 0)
                                    OutlinedButton.icon(
                                      onPressed: () => setState(() {
                                        _errorMessage = null;
                                        _currentStep -= 1;
                                      }),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        side: BorderSide(color: isDark ? Colors.white : Colors.black),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusMedium,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.arrow_back,
                                        size: 16,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                      label: Text(
                                        'BACK',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  PrimaryButton(
                                    label: isLastStep ? 'ADD' : 'NEXT',
                                    isLoading: _isLoading && isLastStep,
                                    onPressed: () {
                                      if (_currentStep == 1) {
                                        final isValid = _studentFormKey.currentState?.validate() ?? false;
                                        if (!isValid) {
                                          setState(() {
                                            _errorMessage =
                                                'Please complete all required fields in red before proceeding to Enrollment.';
                                          });
                                          return;
                                        }
                                      }
                                      if (isLastStep) {
                                        _handleSave();
                                      } else {
                                        setState(() {
                                          _errorMessage = null;
                                          _currentStep += 1;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                );
                },
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
