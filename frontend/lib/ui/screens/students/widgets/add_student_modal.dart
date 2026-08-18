import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../../domain/entities/ocr_result_model.dart';
import '../../../../domain/repositories/student_repository.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/ocr_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/document_provider.dart';
import '../../documents/widgets/document_preview_modal.dart';
import '../../../shared/inputs/document_source_picker.dart';
import 'ocr_enrollment_validation_modal.dart';
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

  /// Enrollments accepted from the OCR review dialog; auto-fill the
  /// enrollment step and are created with the student on save.
  final List<OcrEnrollmentPrefill> _ocrSavedEnrollments = [];

  File? _ocrScannedFile;
  String _ocrScannedFileName = '';
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
        lower.contains('reportcard') ||
        lower.contains('student report card') ||
        lower.contains('form 138') ||
        lower.contains('form-138') ||
        lower.contains('form138') ||
        lower.contains('school form 9') ||
        lower.contains('school-form-9') ||
        lower.contains('sf1 for jhs') ||
        lower.contains('sf1') ||
        lower.contains('sf-1') ||
        lower.contains('sf 1')) {
      return 'SF9';
    }
    if (lower.contains('sf10') ||
        lower.contains('sf-10') ||
        lower.contains('sf 10') ||
        lower.contains('permanent record') ||
        lower.contains('permanentrecord') ||
        lower.contains('student permanent record') ||
        lower.contains('school form 10') ||
        lower.contains('school-form-10') ||
        lower.contains('form 137') ||
        lower.contains('form-137') ||
        lower.contains('form137') ||
        lower.contains('form 137-a') ||
        lower.contains('form 137a') ||
        lower.contains('form 10') ||
        lower.contains('form-10')) {
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
      _ocrScannedFileName = fileName;
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
        _middleNameController.text = ocrResult.middleName;
        _extController.text = ocrResult.extension;
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

      await _offerOcrEnrollment(ocrResult, docType);
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

  /// For SF9/SF10 scans with a Grade 7-12 level, let the user review and
  /// edit the detected enrollment(s) (academic year, grade level, section).
  /// Accepted enrollments are appended to [_ocrSavedEnrollments] and the
  /// enrollment step auto-fills with the last accepted one.
  Future<void> _offerOcrEnrollment(
    OcrResultModel ocrResult,
    String docType,
  ) async {
    if (docType != 'SF9' && docType != 'SF10') return;
    final gradeNum = int.tryParse(ocrResult.gradeLevel.replaceAll(RegExp(r'\D'), ''));
    if (gradeNum == null || gradeNum < 7 || gradeNum > 12) return;
    if (!mounted) return;

    final accepted = await OcrEnrollmentValidationModal.showForAddStudent(
      context,
      records: [
        OcrEnrollmentRecord(
          gradeLevel: gradeNum.toString(),
          section: ocrResult.section,
          schoolYear: ocrResult.schoolYear,
        ),
      ],
    );
    if (!mounted || accepted.isEmpty) return;

    setState(() {
      _ocrSavedEnrollments.clear();
      _ocrSavedEnrollments.addAll(accepted);
      final last = accepted.last;
      _selectedAcademicYearId = last.academicYearId;
      _selectedGradeLevel = last.gradeLevel;
      _selectedSectionId = last.sectionId;
      _trackStrand = ocrResult.trackStrand.trim().isEmpty
          ? null
          : ocrResult.trackStrand.trim();
    });
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
      final studentId = await notifier.createStudent(
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

      // After the student's directory is created, upload the scanned
      // SF9/SF10 document into it.
      String? uploadError;
      if (_ocrScannedFile != null) {
        try {
          final bytes = await _ocrScannedFile!.readAsBytes();
          await ref.read(documentRepositoryProvider).uploadDocumentBytes(
            studentId: studentId,
            documentType: _selectedOcrDocType ?? 'SF9',
            fileName: _ocrScannedFileName.isEmpty
                ? _ocrScannedFile!.path.split(RegExp(r'[\\/]')).last
                : _ocrScannedFileName,
            bytes: bytes,
          );
        } catch (e) {
          final raw = e.toString();
          uploadError = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
        }
      }

      if (!mounted) return;
      ref.invalidate(studentPageProvider);
      if (uploadError != null) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Student Created - Upload Failed'),
            content: Text(
              'The student was created successfully, but the scanned '
              'document could not be uploaded to their folder.\n\n'
              '$uploadError',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
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

  // ----------------------------------------------------------------
  // STEPS UI
  // ----------------------------------------------------------------
  Widget _buildOcrStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: AppSizes.p32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                color: AppColors.primaryGreen,
                backgroundColor:
                    isDark ? AppColors.darkSurface2 : const Color(0xFFE0E0E0),
                minHeight: 8,
              ),
            ),
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
              activeColor: AppColors.fourPs,
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
          if (_ocrSavedEnrollments.isNotEmpty) ...[
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
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ocrSavedEnrollments.length == 1
                          ? 'Enrollment saved from OCR scan: Grade '
                              '${_ocrSavedEnrollments.first.gradeLevel} · '
                              '${_ocrSavedEnrollments.first.sectionName} · '
                              'SY ${_ocrSavedEnrollments.first.schoolYear} — '
                              'verify before saving the student.'
                          : '${_ocrSavedEnrollments.length} enrollments saved '
                              'from OCR scans — verify before saving the '
                              'student.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (_ocrSavedEnrollments.length > 1) ...[
              const SizedBox(height: AppSizes.p8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _ocrSavedEnrollments)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'Grade ${e.gradeLevel} · ${e.sectionName} · '
                        'SY ${e.schoolYear}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSizes.p16),
          ],
          const SectionLabel(label: 'ENROLLMENT DETAILS'),
          const SizedBox(height: AppSizes.p16),
          yearsAsync.when(
            data: (years) {
              final active = years
                  .where((y) => y.status.toLowerCase() == 'active')
                  .toList();
              final defaultYearId = (active.isNotEmpty ? active.last : (years.isNotEmpty ? years.last : null))?.id;
              final currentYearId = _selectedAcademicYearId ?? defaultYearId;

              final selectedYearExists = years.any((y) => y.id == currentYearId);
              final effectiveValue = selectedYearExists ? currentYearId : null;

              return DropdownButtonFormField<int>(
                key: const ValueKey('academic_year_dropdown'),
                value: effectiveValue,
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
                  _selectedGradeLevel = 7;
                  _selectedSectionId = null;
                  _trackStrand = null;
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
              final selectedGradeExists =
                  grades.any((g) => g.level == _selectedGradeLevel);
              final effectiveGradeValue = selectedGradeExists
                  ? _selectedGradeLevel
                  : (grades.any((g) => g.level == 7)
                      ? 7
                      : (grades.isNotEmpty ? grades.first.level : null));

              return DropdownButtonFormField<int>(
                key: const ValueKey('grade_level_dropdown'),
                value: effectiveGradeValue,
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
                  if (val != null && val < 11) {
                    _trackStrand = null;
                  }
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
                key: ValueKey('section_autocomplete_${effectiveYearId}_$_selectedGradeLevel'),
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
                    decoration: InputDecoration(
                      labelText: 'Section (Type or Select)',
                      prefixIcon: const Icon(Icons.segment),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      hintText: filtered.isEmpty ? 'No sections available' : null,
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
              if (_isLoading && _currentStep != 0)
                const LinearProgressIndicator(
                  color: AppColors.primaryGreen,
                  backgroundColor: Color(0xFFE0E0E0),
                  minHeight: 3,
                ),
              Expanded(
                child: DropTarget(
                  onDragDone: (details) async {
                    if (details.files.isNotEmpty && _currentStep == 0) {
                      final path = details.files.first.path;
                      final droppedFile = File(path);
                      final fileName = path.split(RegExp(r'[\\/]')).last;
                      final length = await droppedFile.length();
                      final fileSize = '${(length / 1024).toStringAsFixed(1)} KB';
                      _handleOcrScan(droppedFile, fileName, fileSize);
                    }
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: stepContent,
                  ),
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
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
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
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1C8248),
                                      foregroundColor: isDark ? Colors.white : Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusMedium,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading && isLastStep
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            isLastStep ? 'ADD' : 'NEXT',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
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
                                    SizedBox(
                                      height: 44,
                                      width: 120,
                                      child: OutlinedButton.icon(
                                        onPressed: () => setState(() {
                                          _errorMessage = null;
                                          _currentStep -= 1;
                                        }),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
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
                                  SizedBox(
                                    height: 44,
                                    width: 120,
                                    child: ElevatedButton(
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
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1C8248),
                                        foregroundColor: isDark ? Colors.white : Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusMedium,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading && isLastStep
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              isLastStep ? 'ADD' : 'NEXT',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
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
