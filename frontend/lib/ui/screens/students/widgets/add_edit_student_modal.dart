import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/student_model.dart';

import '../../../shared/buttons/primary_button.dart';
import '../../../providers/ocr_provider.dart';
import '../../../shared/inputs/document_source_picker.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/setup_provider.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/dialogs/info_dialog.dart';
import '../../documents/widgets/document_preview_modal.dart';
import 'edit_enrollment_modal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/api_constants.dart';
import '../../../shared/dialogs/error_dialog.dart';

// ---------------------------------------------------------------
// Auto-capitalises the first letter of every word (works on paste)
// ---------------------------------------------------------------
class _UpperCaseWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class AddEditStudentModal extends ConsumerStatefulWidget {
  final StudentModel? student;

  const AddEditStudentModal({super.key, this.student});

  @override
  ConsumerState<AddEditStudentModal> createState() =>
      _AddEditStudentModalState();
}

class _AddEditStudentModalState extends ConsumerState<AddEditStudentModal> {
  // ---- Form & Stepper State ----
  final _studentFormKey = GlobalKey<FormState>();
  final _enrollmentFormKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  late TextEditingController _lrnController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _extController;

  String _selectedSex = 'Male';
  String _selectedStatus = 'Enrolled';
  DateTime? _selectedDob;
  bool _is4ps = false;
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;
  bool _isEnrollmentInitialized = false;
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

  int _currentStep = 0;
  String? _selectedOcrDocType;
  File? _ocrScannedFile;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _lrnController = TextEditingController(text: s?.lrn ?? '');
    _firstNameController = TextEditingController(text: s?.firstName ?? '');
    _middleNameController = TextEditingController(text: s?.middleName ?? '');
    _lastNameController = TextEditingController(text: s?.lastName ?? '');
    _extController = TextEditingController(text: s?.extension ?? '');
    if (s != null) {
      _selectedSex = s.sex;
      _selectedDob = s.birthDate;
      _selectedStatus = s.status;
      _is4ps = s.is4ps;
      _currentStep = 0;
    } else {
      _currentStep = 0;
    }
    // Refresh enrollment data every time the modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(sectionsListProvider);
      }
    });
  }

  @override
  void dispose() {
    _lrnController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _extController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // EXIT CONFIRMATION
  // ----------------------------------------------------------------
  bool get _hasAnyData =>
      _lrnController.text.isNotEmpty ||
      _firstNameController.text.isNotEmpty ||
      _middleNameController.text.isNotEmpty ||
      _lastNameController.text.isNotEmpty;

  Future<void> _confirmClose() async {
    // If editing, or nothing entered yet — close immediately
    if (widget.student != null || !_hasAnyData) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Discard Changes?'),
          ],
        ),
        content: const Text(
          'You have unsaved data. Are you sure you want to close without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'KEEP EDITING',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'DISCARD',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldClose == true && mounted) Navigator.of(context).pop();
  }

  // ----------------------------------------------------------------
  // OCR PROCESSING
  // ----------------------------------------------------------------

  /// Tries to detect SF9 or SF10 from the filename.
  /// Returns 'SF9', 'SF10', or null if undetectable.
  String? _detectDocType(String fileName) {
    final lower = fileName.toLowerCase();
    // SF9 patterns: sf9, sf-9, sf 9, report card, reportcard
    if (lower.contains('sf9') ||
        lower.contains('sf-9') ||
        lower.contains('sf 9') ||
        lower.contains('report card') ||
        lower.contains('reportcard')) {
      return 'SF9';
    }
    // SF10 patterns: sf10, sf-10, sf 10, permanent record, permanentrecord
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

  /// Shows a dialog asking the user to confirm the document type.
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

    // Auto-detect the doc type from the filename
    String? docType = _detectDocType(fileName);

    // If detection failed, ask the user
    if (docType == null) {
      if (!mounted) return;
      docType = await _askDocType();
    }

    // User cancelled the dialog
    if (docType == null || !mounted) return;

    setState(() => _selectedOcrDocType = docType);

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
        _isLoading = false;
        _ocrScannedFile = file;
        _selectedOcrDocType = docType;
        _currentStep = 1; // switch to manual form
      });
      if (!mounted) return;
      showInfoDialog(
        context,
        title: 'Scan Complete',
        icon: Icons.document_scanner_outlined,
        iconColor: AppColors.info,
        buttonLabel: 'Review Data',
        message:
            'OCR extracted the data from your document.\n\n'
            'Please review and correct all fields before saving — '
            'auto-filled values may contain errors.',
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      setState(() => _errorMessage = msg);
    }
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
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters.';
    }
    return null;
  }

  // ----------------------------------------------------------------
  // VALIDATION DIALOG
  // ----------------------------------------------------------------
  void _showValidationDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 36,
        ),
        title: const Text(
          'Incomplete Details',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              minimumSize: const Size(120, 40),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // SUBMIT
  // ----------------------------------------------------------------
  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);

    // Validate Tab 0: Student Details
    final lrnErr = _validateLRN(_lrnController.text);
    final fnErr = _validateRequired(_firstNameController.text, 'First name');
    final lnErr = _validateRequired(_lastNameController.text, 'Last name');

    if (lrnErr != null ||
        fnErr != null ||
        lnErr != null) {
      setState(() => _currentStep = widget.student != null ? 0 : 1);
      _studentFormKey.currentState?.validate();
      // Build a descriptive message listing all missing fields
      final missing = <String>[];
      if (lrnErr != null) missing.add('LRN ($lrnErr)');
      if (fnErr != null) missing.add('First Name');
      if (lnErr != null) missing.add('Last Name');
      _showValidationDialog(
        'Please fill in all required fields:\n\n${missing.map((e) => '• $e').join('\n')}',
      );
      return;
    }

    // Validate Tab 1: Enrollment Details
    if (_selectedAcademicYearId == null ||
        _selectedGradeLevel == null ||
        _selectedSectionId == null) {
      setState(() => _currentStep = widget.student != null ? 1 : 2);
      _enrollmentFormKey.currentState?.validate();
      final missing = <String>[];
      if (_selectedAcademicYearId == null) missing.add('Academic Year');
      if (_selectedGradeLevel == null) missing.add('Grade Level');
      if (_selectedSectionId == null) missing.add('Section');
      _showValidationDialog(
        'Please select all required enrollment fields:\n\n${missing.map((e) => '• $e').join('\n')}',
      );
      return;
    }

    // Validate graduation restriction: status 'Graduated' is only allowed if grade is 10 or 12
    if (_selectedStatus == 'Graduated' &&
        _selectedGradeLevel != 10 &&
        _selectedGradeLevel != 12) {
      setState(() => _currentStep = widget.student != null ? 1 : 2);
      _showValidationDialog(
        'Graduation status is only applicable for Grade 10 and Grade 12 students.',
      );
      return;
    }

    // Validate enrollment academic year downgrade restriction (edit only)
    // A student cannot be updated to a lower grade level within the same academic year.
    if (widget.student != null) {
      // Use _loadedEnrollments (fetched via studentDetailProvider) which is always
      // populated in edit mode, unlike widget.student!.enrollments which may be null.
      final enrollments = _loadedEnrollments;
      if (enrollments != null && enrollments.isNotEmpty) {
        final sameYearEnrollments = enrollments
            .where((e) => e.academicYearId == _selectedAcademicYearId)
            .toList();
        if (sameYearEnrollments.isNotEmpty) {
          final existingMaxGrade = sameYearEnrollments
              .map((e) => e.gradeLevel as int)
              .reduce((a, b) => a > b ? a : b);
          if (_selectedGradeLevel! < existingMaxGrade) {
            setState(() => _currentStep = widget.student != null ? 1 : 2);
            _showValidationDialog(
              'Cannot downgrade enrollment. This student is already '
              'in Grade $existingMaxGrade for this academic year. '
              'You cannot change it to Grade $_selectedGradeLevel '
              'in the same academic year.',
            );
            return;
          }
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(studentMutationProvider.notifier);
      if (widget.student == null) {
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
      } else {
        await notifier.updateStudent(
          id: widget.student!.id,
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
          academicYearId: _selectedAcademicYearId!,
          gradeLevel: _selectedGradeLevel!,
          sectionId: _selectedSectionId!,
          trackStrand: _trackStrand,
          is4ps: _is4ps,
        );
      }
      if (!mounted) return;
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
  // UPDATE DETAILS FOR EDIT TAB MODAL
  // ----------------------------------------------------------------
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
      int? latestGrade = _selectedGradeLevel;
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
        id: widget.student!.id,
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
      ref.invalidate(studentDetailProvider(widget.student!.id));
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
  // OCR SCAN FOR ENROLLMENTS TAB
  // ----------------------------------------------------------------
  Future<void> _scanSF10SF9(
      BuildContext context, WidgetRef ref, int studentId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryGreen),
                SizedBox(height: 16),
                Text('Scanning SF10/SF9 document...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final dio = ApiConstants.createDio();
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      dio.options.baseUrl = ApiConstants.baseUrl;
      final res = await dio.post(
        '/students/$studentId/ocr-enrollment',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (context.mounted) Navigator.pop(context);

      final data = res.data?['data'] ?? {};
      final allRecords = data['allRecords'];
      String summaryMsg = 'SF10/SF9 Scanned Successfully!';
      if (allRecords is List && allRecords.isNotEmpty) {
        summaryMsg += '\n\nProcessed ${allRecords.length} enrollment record(s):';
        for (final rec in allRecords) {
          if (rec is Map) {
            final gr = rec['gradeLevel'] ?? '?';
            final sy = rec['schoolYear'] ?? '?';
            final sec = rec['section'] ?? '?';
            summaryMsg += '\n• Grade $gr ($sy) - Sec: $sec';
          }
        }
      } else {
        final sy = data['schoolYear'] ?? 'N/A';
        final gr = data['gradeLevel'] ?? 'N/A';
        final sec = data['section'] ?? 'N/A';
        summaryMsg += '\n\nExtracted Academic Year: $sy\nGrade Level: $gr\nSection: $sec';
      }

      ref.invalidate(studentPageProvider);
      ref.invalidate(studentDetailProvider(studentId));

      if (context.mounted) {
        showSuccessDialog(
          context,
          message: summaryMsg,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      String errMsg = 'Failed to scan SF10/SF9.';
      if (e is DioException && e.response?.data != null) {
        final resData = e.response?.data;
        if (resData is Map && resData['message'] != null) {
          errMsg = resData['message'].toString();
        }
      }
      if (context.mounted) {
        showErrorDialog(context, 'OCR Scan Failed', errMsg);
      }
    }
  }

  Widget _buildStudentDetailsTabContent(
    bool isMobile,
    double keyboardInset,
  ) {
    return Form(
      key: _studentFormKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSizes.p16),
                      padding: const EdgeInsets.all(AppSizes.p12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: AppSizes.p8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _SectionLabel(label: "LEARNER REFERENCE INFORMATION"),
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
                  _SectionLabel(label: 'NAME'),
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
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      _UpperCaseWordsFormatter(),
                                    ],
                                    validator: (v) =>
                                        _validateRequired(v, 'First name'),
                                    decoration: const InputDecoration(
                                      labelText: 'FIRST NAME',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p12),
                                Expanded(
                                  flex: 2,
                                  child: _ExtensionNameField(
                                    controller: _extController,
                                    suggestions: _extSuggestions,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p12),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _middleNameController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      _UpperCaseWordsFormatter(),
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
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              validator: (v) =>
                                  _validateRequired(v, 'Last name'),
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
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              validator: (v) =>
                                  _validateRequired(v, 'First name'),
                              decoration: const InputDecoration(
                                labelText: 'FIRST NAME',
                              ),
                            ),
                            const SizedBox(height: AppSizes.p12),
                            _ExtensionNameField(
                              controller: _extController,
                              suggestions: _extSuggestions,
                            ),
                            const SizedBox(height: AppSizes.p12),
                            TextFormField(
                              controller: _middleNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'MIDDLE NAME (Optional)',
                              ),
                            ),
                            const SizedBox(height: AppSizes.p12),
                            TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              validator: (v) =>
                                  _validateRequired(v, 'Last name'),
                              decoration: const InputDecoration(
                                labelText: 'LAST NAME',
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _SectionLabel(label: 'PERSONAL INFORMATION'),
                  const SizedBox(height: AppSizes.p8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('sex_$_selectedSex'),
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
                    onChanged: (v) => setState(() => _selectedSex = v!),
                  ),
                  const SizedBox(height: AppSizes.p12),
                  _DobPicker(
                    initialDate: _selectedDob,
                    onChanged: (val) {
                      setState(() {
                        _selectedDob = val;
                      });
                    },
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _SectionLabel(label: 'STUDENT STATUS'),
                  const SizedBox(height: AppSizes.p8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('status_$_selectedStatus'),
                    initialValue: _selectedStatus,
                    validator: (v) => v == null ? 'Please select a status.' : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'STATUS',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStatus = v!),
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _SectionLabel(label: 'GOVERNMENT AID STATUS'),
                  const SizedBox(height: AppSizes.p8),
                  Container(
                    decoration: BoxDecoration(
                      color: _is4ps
                          ? Colors.deepPurple.withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                      border: Border.all(
                        color: _is4ps
                            ? Colors.deepPurple.withValues(alpha: 0.3)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: SwitchListTile(
                      value: _is4ps,
                      onChanged: (val) => setState(() => _is4ps = val),
                      activeColor: Colors.deepPurple,
                      title: const Text(
                        '4Ps Beneficiary',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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
                      secondary: Icon(
                        Icons.family_restroom,
                        color: _is4ps
                            ? Colors.deepPurple
                            : Colors.grey.shade400,
                      ),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'UPDATE DETAILS',
              isLoading: _isLoading,
              onPressed: _handleSaveDetails,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentsTabContent(bool isMobile) {
    final studentDetailAsync = ref.watch(studentDetailProvider(widget.student!.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isStacked = constraints.maxWidth < 420 ||
                Theme.of(ctx).platform == TargetPlatform.android;

            final buttons = [
              OutlinedButton.icon(
                onPressed: () => _scanSF10SF9(context, ref, widget.student!.id),
                icon: const Icon(Icons.document_scanner, size: 18),
                label: const Text('Scan SF10 / SF9'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              if (isStacked)
                const SizedBox(height: 8)
              else
                const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.45),
                    builder: (ctx) => EditEnrollmentModal(
                      studentId: widget.student!.id,
                      enrollment: null,
                    ),
                  ).then((_) {
                    if (mounted) {
                      ref.invalidate(studentDetailProvider(widget.student!.id));
                      ref.invalidate(studentPageProvider);
                    }
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Enrollment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ];

            if (isStacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: buttons,
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: buttons,
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: studentDetailAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error loading enrollments: $e',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (student) {
              final enrollments = student.enrollments;
              if (enrollments == null || enrollments.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No enrollments found for this student.\nAdd an enrollment or scan an SF10/SF9 document.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final sorted = List.from(enrollments);
              sorted.sort(
                (a, b) => (b.gradeLevel ?? 0).compareTo(a.gradeLevel ?? 0),
              );

              return ListView.separated(
                itemCount: sorted.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final enrollment = sorted[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
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
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          tooltip: 'Edit Enrollment',
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black.withValues(alpha: 0.45),
                              builder: (ctx) => EditEnrollmentModal(
                                studentId: widget.student!.id,
                                enrollment: enrollment,
                              ),
                            ).then((_) {
                              if (mounted) {
                                ref.invalidate(studentDetailProvider(widget.student!.id));
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
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('CANCEL'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      ref
                                          .read(studentMutationProvider.notifier)
                                          .deleteEnrollment(
                                            studentId: widget.student!.id,
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
              );
            },
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------  // BUILD — full-screen Scaffold with under-header line stepper
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    if (widget.student != null && !_isEnrollmentInitialized) {
      final detailsAsync = ref.watch(studentDetailProvider(widget.student!.id));
      detailsAsync.whenData((fullStudent) {
        // Cache the enrollment list for use in validation
        if (_loadedEnrollments == null && fullStudent.enrollments != null) {
          Future.microtask(() {
            if (mounted) {
              setState(() => _loadedEnrollments = fullStudent.enrollments);
            }
          });
        }
        if (fullStudent.enrollments != null &&
            fullStudent.enrollments!.isNotEmpty) {
          final latestEnrollment = fullStudent.enrollments!.reduce((a, b) {
            final ya = a.yearRange ?? '';
            final yb = b.yearRange ?? '';
            final cmp = ya.compareTo(yb);
            if (cmp != 0) {
              return cmp > 0 ? a : b;
            }
            return a.gradeLevel > b.gradeLevel ? a : b;
          });
          Future.microtask(() {
            if (mounted && !_isEnrollmentInitialized) {
              setState(() {
                _selectedAcademicYearId = latestEnrollment.academicYearId;
                _selectedGradeLevel = latestEnrollment.gradeLevel;
                _selectedSectionId = latestEnrollment.sectionId;
                _trackStrand = latestEnrollment.trackStrand;
                _isEnrollmentInitialized = true;
              });
            }
          });
        }
      });
    }

    final isEdit = widget.student != null;
    final totalSteps = isEdit ? 2 : 3;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirmClose();
      },
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
            isEdit ? 'Update Student Record' : 'Add New Student',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildLineStepper(totalSteps),
              if (_isLoading)
                const LinearProgressIndicator(
                  color: AppColors.primaryGreen,
                  backgroundColor: Color(0xFFE0E0E0),
                  minHeight: 3,
                ),
              Expanded(
                child: isEdit
                    ? _buildEditTabBody(yearsAsync, gradeLevelsAsync, sectionsAsync)
                    : _buildAddStepBody(yearsAsync, gradeLevelsAsync, sectionsAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineStepper(int totalSteps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: const Color(0xFFF8F9FA),
      child: Row(
        children: List.generate(totalSteps, (idx) {
          final activeOrDone = _currentStep >= idx;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: idx < totalSteps - 1 ? 6 : 0),
              decoration: BoxDecoration(
                color: activeOrDone ? AppColors.primaryGreen : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEditTabBody(
    AsyncValue<List<AcademicYearModel>> yearsAsync,
    AsyncValue<List<GradeLevelModel>> gradeLevelsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
  ) {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentStep,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              onTap: (i) => setState(() => _currentStep = i),
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryGreen,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Student Details'),
                Tab(icon: Icon(Icons.school_outlined, size: 20), text: 'Enrollments'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStudentDetailsTabContent(false, 0),
                _buildEnrollmentsTabContent(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddStepBody(
    AsyncValue<List<AcademicYearModel>> yearsAsync,
    AsyncValue<List<GradeLevelModel>> gradeLevelsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
  ) {
    final ocrState = ref.watch(ocrProvider);
    final isLastStep = _currentStep == 2;
    final isOcrStep = _currentStep == 0;

    Widget stepContent;
    switch (_currentStep) {
      case 0:
        stepContent = _buildOcrStep();
      case 1:
        stepContent = _buildAddStudentDetailsStep();
      case 2:
        stepContent = _buildAddEnrollmentStep(yearsAsync, gradeLevelsAsync, sectionsAsync);
      default:
        stepContent = _buildOcrStep();
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: stepContent,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _currentStep -= 1),
                  child: const Text('BACK'),
                ),
              const Spacer(),
              if (isOcrStep && !ocrState.isLoading)
                OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  child: const Text('Skip OCR & Enter Manually'),
                ),
              if (!isOcrStep) ...[
                if (_ocrScannedFile != null) ...[
                  TextButton(
                    onPressed: () => setState(() {
                      _lrnController.clear();
                      _firstNameController.clear();
                      _middleNameController.clear();
                      _lastNameController.clear();
                      _extController.clear();
                      _currentStep = 0;
                    }),
                    child: const Text('RE-SCAN',
                        style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_ocrScannedFile != null) {
                        showDocumentPreview(
                          context: context,
                          localFile: _ocrScannedFile!,
                          localFileName: _ocrScannedFile!.path.split('/').last,
                        );
                      }
                    },
                    child: const Text('VIEW DOC',
                        style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(width: 8),
                PrimaryButton(
                  label: isLastStep ? 'SAVE' : 'NEXT',
                  isLoading: _isLoading && isLastStep,
                  onPressed: () {
                    if (_currentStep == 1) {
                      if (!(_studentFormKey.currentState?.validate() ?? false)) {
                        return;
                      }
                    }
                    if (isLastStep) {
                      _handleSave();
                    } else {
                      setState(() => _currentStep += 1);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddStudentDetailsStep() {
    return Form(
      key: _studentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'LEARNER REFERENCE INFORMATION'),
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
          _SectionLabel(label: 'NAME'),
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
                            inputFormatters: [_UpperCaseWordsFormatter()],
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
                          child: _ExtensionNameField(
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
                            inputFormatters: [_UpperCaseWordsFormatter()],
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
                      inputFormatters: [_UpperCaseWordsFormatter()],
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
                      inputFormatters: [_UpperCaseWordsFormatter()],
                      validator: (v) => _validateRequired(v, 'First name'),
                      decoration: const InputDecoration(labelText: 'FIRST NAME'),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _ExtensionNameField(
                      controller: _extController,
                      suggestions: _extSuggestions,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    TextFormField(
                      controller: _middleNameController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [_UpperCaseWordsFormatter()],
                      decoration: const InputDecoration(labelText: 'MIDDLE NAME (Optional)'),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [_UpperCaseWordsFormatter()],
                      validator: (v) => _validateRequired(v, 'Last name'),
                      decoration: const InputDecoration(labelText: 'LAST NAME'),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: AppSizes.p16),
          _SectionLabel(label: 'PERSONAL INFORMATION'),
          const SizedBox(height: AppSizes.p8),
          DropdownButtonFormField<String>(
            key: ValueKey('sex_$_selectedSex'),
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
            onChanged: (v) => setState(() => _selectedSex = v!),
          ),
          const SizedBox(height: AppSizes.p12),
          _DobPicker(
            initialDate: _selectedDob,
            onChanged: (val) => setState(() => _selectedDob = val),
          ),
          const SizedBox(height: AppSizes.p16),
          _SectionLabel(label: 'GOVERNMENT AID STATUS'),
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
              onChanged: (val) => setState(() => _is4ps = val),
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
            _ErrorBanner(message: _errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildAddEnrollmentStep(
    AsyncValue<List<AcademicYearModel>> yearsAsync,
    AsyncValue<List<GradeLevelModel>> gradeLevelsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
  ) {
    return Form(
      key: _enrollmentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'ENROLLMENT DETAILS'),
          const SizedBox(height: AppSizes.p16),
          yearsAsync.when(
            data: (years) {
              if (_selectedAcademicYearId == null && years.isNotEmpty) {
                final active = years
                    .where((y) => y.status.toLowerCase() == 'active')
                    .toList();
                final candidate = active.isNotEmpty ? active.last : years.last;
                Future.microtask(() {
                  if (mounted && _selectedAcademicYearId == null) {
                    setState(() => _selectedAcademicYearId = candidate.id);
                  }
                });
              }
              return DropdownButtonFormField<int>(
                key: ValueKey('academic_$_selectedAcademicYearId'),
                initialValue: _selectedAcademicYearId,
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
                key: ValueKey('grade_$_selectedGradeLevel'),
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
              final filtered = sections
                  .where((sec) =>
                      sec.academicYearId == _selectedAcademicYearId &&
                      sec.gradeLevel == _selectedGradeLevel)
                  .toList();
              final matches = filtered.where((s) => s.id == _selectedSectionId);
              final initialSectionName =
                  matches.isNotEmpty ? matches.first.name : '';
              return Autocomplete<SectionModel>(
                key: ValueKey(
                    'section_${_selectedGradeLevel}_$_selectedAcademicYearId'),
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
        ],
      ),
    );
  }

  // ================================================================
  // STEP 1: OCR SELECTION UI
  // ================================================================
  Widget _buildOcrStep() {
    final ocrState = ref.watch(ocrProvider);

    if (ocrState.isLoading) {
      return _OcrProgressLoader(docType: _selectedOcrDocType ?? 'Document');
    }

    return SingleChildScrollView(
      key: const ValueKey('ocr-step'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: AppSizes.p16),
          ],

          // Info card: auto-detect notice
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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
      ),
    );
  }

  // ================================================================
  // STEP 2: MANUAL FORM UI (legacy - replaced by _buildAddStudentDetailsStep and _buildAddEnrollmentStep)
  // ================================================================
  // ignore: unused_element
  Widget _buildManualForm(
    bool isEdit,
    AsyncValue<List<AcademicYearModel>> yearsAsync,
    AsyncValue<List<GradeLevelModel>> gradeLevelsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
    bool isMobile,
    double keyboardInset,
  ) {
    final ocrState = ref.watch(ocrProvider);
    final compactTheme = Theme.of(context).copyWith(
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 8 : 16,
        ),
        labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
        hintStyle: TextStyle(fontSize: isMobile ? 11 : 14),
      ),
    );

    return Theme(
      data: compactTheme,
      child: Stepper(
        type: isMobile ? StepperType.vertical : StepperType.horizontal,
        currentStep: _currentStep,
        onStepTapped: (step) {
          final isEdit = widget.student != null;
          if (step > _currentStep) {
            final detailsStepIndex = isEdit ? 0 : 1;
            if (_currentStep == detailsStepIndex) {
              if (!(_studentFormKey.currentState?.validate() ?? false)) return;
            }
          }
          setState(() {
            _currentStep = step;
          });
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          } else {
            _confirmClose();
          }
        },
        onStepContinue: () {
          final isEdit = widget.student != null;
          final isLastStep = _currentStep == (isEdit ? 1 : 2);
          final detailsStepIndex = isEdit ? 0 : 1;
          if (isLastStep) {
            _handleSave();
          } else {
            if (_currentStep == detailsStepIndex) {
              if (!(_studentFormKey.currentState?.validate() ?? false)) return;
            }
            setState(() {
              _currentStep += 1;
            });
          }
        },
        controlsBuilder: (context, details) {
          final isEdit = widget.student != null;
          final isLastStep = _currentStep == (isEdit ? 1 : 2);
          final isOcrStep = !isEdit && _currentStep == 0;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel ?? () {},
                    child: const Text('BACK'),
                  ),
                if (isOcrStep && !ocrState.isLoading)
                  OutlinedButton(
                    onPressed: details.onStepContinue ?? () {},
                    child: const Text('Skip OCR & Enter Manually'),
                  )
                else if (!isOcrStep)
                  PrimaryButton(
                    label: isLastStep ? (isEdit ? 'UPDATE' : 'SAVE') : 'NEXT',
                    isLoading: _isLoading && isLastStep,
                    onPressed: details.onStepContinue ?? () {},
                  ),
                if (!isEdit && _ocrScannedFile != null && !isOcrStep) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() {
                      _lrnController.clear();
                      _firstNameController.clear();
                      _middleNameController.clear();
                      _lastNameController.clear();
                      _extController.clear();
                      _currentStep = 0;
                    }),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'RE-SCAN',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      if (_ocrScannedFile != null) {
                        showDocumentPreview(
                          context: context,
                          localFile: _ocrScannedFile!,
                          localFileName: _ocrScannedFile!.path.split('/').last,
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'VIEW DOC',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          if (widget.student == null)
            Step(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    size: isMobile ? 14 : 18,
                    color: AppColors.primaryGreen,
                  ),
                  if (!isMobile) const SizedBox(width: 4),
                  Text(
                    'OCR',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: _buildOcrStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
          Step(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  size: isMobile ? 14 : 18,
                  color: AppColors.primaryGreen,
                ),
                if (!isMobile) const SizedBox(width: 4),
                Text(
                  'Student',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            isActive: _currentStep >= (widget.student != null ? 0 : 1),
            state: _currentStep > (widget.student != null ? 0 : 1)
                ? StepState.complete
                : StepState.indexed,
            content: Form(
              key: _studentFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Learner Reference Information section label ──
                  _SectionLabel(label: "LEARNER REFERENCE INFORMATION"),
                  const SizedBox(height: AppSizes.p8),

                  // LRN
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

                  // ── NAME section label ──
                  _SectionLabel(label: 'NAME'),
                  const SizedBox(height: AppSizes.p8),

                  // Names & Ext — order: First Name | Ext | Middle Name (row 1), Last Name (row 2)
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final wide = c.maxWidth > 480;
                      if (wide) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First Name
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      _UpperCaseWordsFormatter(),
                                    ],
                                    validator: (v) =>
                                        _validateRequired(v, 'First name'),
                                    decoration: const InputDecoration(
                                      labelText: 'FIRST NAME',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p12),
                                // Extension (right after first name)
                                Expanded(
                                  flex: 2,
                                  child: _ExtensionNameField(
                                    controller: _extController,
                                    suggestions: _extSuggestions,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p12),
                                // Middle Name
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _middleNameController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    inputFormatters: [
                                      _UpperCaseWordsFormatter(),
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
                            // Last Name — full width
                            TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              validator: (v) =>
                                  _validateRequired(v, 'Last name'),
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
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              validator: (v) =>
                                  _validateRequired(v, 'First name'),
                              decoration: const InputDecoration(
                                labelText: 'FIRST NAME',
                              ),
                            ),
                            const SizedBox(height: AppSizes.p12),
                            _ExtensionNameField(
                              controller: _extController,
                              suggestions: _extSuggestions,
                            ),
                            const SizedBox(height: AppSizes.p12),
                            TextFormField(
                              controller: _middleNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'MIDDLE NAME (Optional)',
                              ),
                            ),
                            const SizedBox(height: AppSizes.p12),
                            TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [_UpperCaseWordsFormatter()],
                              validator: (v) =>
                                  _validateRequired(v, 'Last name'),
                              decoration: const InputDecoration(
                                labelText: 'LAST NAME',
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // ── PERSONAL INFORMATION section label ──
                  _SectionLabel(label: 'PERSONAL INFORMATION'),
                  const SizedBox(height: AppSizes.p8),

                  // Sex
                  DropdownButtonFormField<String>(
                    key: ValueKey('sex_$_selectedSex'),
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
                    onChanged: (v) => setState(() => _selectedSex = v!),
                  ),
                  const SizedBox(height: AppSizes.p12),

                  // DOB
                  _DobPicker(
                    initialDate: _selectedDob,
                    onChanged: (val) {
                      setState(() {
                        _selectedDob = val;
                      });
                    },
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // ── 4Ps STATUS section label ──
                  _SectionLabel(label: 'GOVERNMENT AID STATUS'),
                  const SizedBox(height: AppSizes.p8),

                  // 4Ps Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: _is4ps
                          ? Colors.deepPurple.withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                      border: Border.all(
                        color: _is4ps
                            ? Colors.deepPurple.withValues(alpha: 0.3)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: SwitchListTile(
                      value: _is4ps,
                      onChanged: (val) => setState(() => _is4ps = val),
                      activeColor: Colors.deepPurple,
                      title: const Text(
                        '4Ps Beneficiary',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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
                      secondary: Icon(
                        Icons.family_restroom,
                        color: _is4ps
                            ? Colors.deepPurple
                            : Colors.grey.shade400,
                      ),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school,
                  size: isMobile ? 14 : 18,
                  color: AppColors.primaryGreen,
                ),
                if (!isMobile) const SizedBox(width: 4),
                Text(
                  'Enrollment',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            isActive: _currentStep >= (widget.student != null ? 1 : 2),
            state: _currentStep > (widget.student != null ? 1 : 2)
                ? StepState.complete
                : StepState.indexed,
            content: Form(
              key: _enrollmentFormKey,
              child: Column(
                children: [
                  yearsAsync.when(
                    data: (years) {
                      // Auto-default: pick current/most-recent active academic year for new students
                      if (!isEdit &&
                          _selectedAcademicYearId == null &&
                          years.isNotEmpty) {
                        final active = years
                            .where((y) => y.status.toLowerCase() == 'active')
                            .toList();
                        final candidate = active.isNotEmpty
                            ? active.last
                            : years.last;
                        Future.microtask(() {
                          if (mounted && _selectedAcademicYearId == null) {
                            setState(
                              () => _selectedAcademicYearId = candidate.id,
                            );
                          }
                        });
                      }
                      return DropdownButtonFormField<int>(
                        key: ValueKey('academic_$_selectedAcademicYearId'),
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
                  const SizedBox(height: AppSizes.p12),

                  gradeLevelsAsync.when(
                    data: (grades) {
                      return DropdownButtonFormField<int>(
                        key: ValueKey('grade_$_selectedGradeLevel'),
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
                  const SizedBox(height: AppSizes.p12),

                  sectionsAsync.when(
                    data: (sections) {
                      final filtered = sections
                          .where(
                            (sec) =>
                                sec.academicYearId == _selectedAcademicYearId &&
                                sec.gradeLevel == _selectedGradeLevel,
                          )
                          .toList();

                      final matches = filtered.where(
                        (s) => s.id == _selectedSectionId,
                      );
                      final initialSectionName = matches.isNotEmpty
                          ? matches.first.name
                          : '';

                      // Key based on grade+year ensures Autocomplete fully rebuilds
                      // when grade level or academic year changes — fixes the bug
                      // where user had to type and erase before dropdown refreshed.
                      final autocompleteKey = ValueKey(
                        'section_${_selectedGradeLevel}_${_selectedAcademicYearId}',
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

                  if (isEdit) ...[
                    const SizedBox(height: AppSizes.p12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('status_$_selectedStatus'),
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: _statuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                      validator: (v) {
                        if (v == 'Graduated' &&
                            _selectedGradeLevel != 10 &&
                            _selectedGradeLevel != 12) {
                          return 'Graduation only allowed for Grade 10 and Grade 12.';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// OCR PROGRESS LOADER — simulated progress bar with estimated time
// ================================================================
class _OcrProgressLoader extends StatefulWidget {
  final String docType;
  const _OcrProgressLoader({required this.docType});

  @override
  State<_OcrProgressLoader> createState() => _OcrProgressLoaderState();
}

class _OcrProgressLoaderState extends State<_OcrProgressLoader> {
  static const int _maxSeconds = 30;

  double _progress = 0.0;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = (_elapsed + 1).clamp(0, _maxSeconds);
        _progress = 0.85 * (1 - (1 / (1 + _elapsed / 8)));
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _etaLabel {
    final remaining = (_maxSeconds - _elapsed).clamp(0, _maxSeconds);
    if (remaining <= 0) return 'Almost done…';
    return 'Est. ~$remaining s remaining';
  }

  String get _phaseLabel {
    if (_progress < 0.25) return 'Uploading document…';
    if (_progress < 0.55) return 'Running OCR engine…';
    if (_progress < 0.78) return 'Parsing extracted text…';
    return 'Finalizing data…';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.p24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: AppSizes.p16),

          Text(
            'Scanning ${widget.docType}…',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.p4),

          Text(
            _phaseLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSizes.p24),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    backgroundColor: AppColors.primaryGreen.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              SizedBox(
                width: 38,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p8),

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

                  if (isEdit) ...[
                    const SizedBox(height: AppSizes.p12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('status_$_selectedStatus'),
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: _statuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                      validator: (v) {
                        if (v == 'Graduated' &&
                            _selectedGradeLevel != 10 &&
                            _selectedGradeLevel != 12) {
                          return 'Graduation only allowed for Grade 10 and Grade 12.';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// OCR PROGRESS LOADER — simulated progress bar with estimated time
// ================================================================
class _OcrProgressLoader extends StatefulWidget {
  final String docType;
  const _OcrProgressLoader({required this.docType});

  @override
  State<_OcrProgressLoader> createState() => _OcrProgressLoaderState();
}

class _OcrProgressLoaderState extends State<_OcrProgressLoader> {
  static const int _maxSeconds = 30;

  double _progress = 0.0;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = (_elapsed + 1).clamp(0, _maxSeconds);
        _progress = 0.85 * (1 - (1 / (1 + _elapsed / 8)));
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _etaLabel {
    final remaining = (_maxSeconds - _elapsed).clamp(0, _maxSeconds);
    if (remaining <= 0) return 'Almost done…';
    return 'Est. ~$remaining s remaining';
  }

  String get _phaseLabel {
    if (_progress < 0.25) return 'Uploading document…';
    if (_progress < 0.55) return 'Running OCR engine…';
    if (_progress < 0.78) return 'Parsing extracted text…';
    return 'Finalizing data…';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.p24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: AppSizes.p16),

          Text(
            'Scanning ${widget.docType}…',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.p4),

          Text(
            _phaseLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSizes.p24),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    backgroundColor: AppColors.primaryGreen.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              SizedBox(
                width: 38,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p8),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _etaLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
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
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SECTION LABEL — thin divider with a bold label
// ================================================================
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1, thickness: 1)),
      ],
    );
  }
}

// ================================================================
// EXTENSION NAME FIELD — text field with autocomplete suggestions
// Selecting 'N/A' clears the field so the stored value is null.
// ================================================================
class _ExtensionNameField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;

  const _ExtensionNameField({
    Key? key,
    required this.controller,
    required this.suggestions,
  }) : super(key: key);

  @override
  State<_ExtensionNameField> createState() => _ExtensionNameFieldState();
}

class _ExtensionNameFieldState extends State<_ExtensionNameField> {
  TextEditingController? _fieldController;

  void _onFieldControllerChanged() {
    if (_fieldController == null) return;
    final upper = _fieldController!.text.toUpperCase();
    if (widget.controller.text != upper) {
      widget.controller.text = upper;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: upper.length),
      );
    }
  }

  @override
  void dispose() {
    _fieldController?.removeListener(_onFieldControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toUpperCase();
        if (query.isEmpty) return widget.suggestions;
        return widget.suggestions.where((s) => s.toUpperCase().startsWith(query));
      },
      fieldViewBuilder: (ctx, fieldController, focusNode, onSubmit) {
        if (_fieldController != fieldController) {
          _fieldController?.removeListener(_onFieldControllerChanged);
          _fieldController = fieldController;
          _fieldController?.addListener(_onFieldControllerChanged);
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_UpperCaseWordsFormatter()],
          decoration: const InputDecoration(
            labelText: 'SUFFIX (Optional)',
            hintText: 'Jr. / III',
          ),
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
      onSelected: (selection) {
        if (selection == 'N/A') {
          widget.controller.clear();
          _fieldController?.clear();
        } else {
          final upper = selection.toUpperCase();
          widget.controller.text = upper;
          _fieldController?.text = upper;
        }
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final opt = options.elementAt(index);
                  final isNa = opt == 'N/A';
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isNa ? AppColors.textSecondary : null,
                          fontStyle: isNa ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// DOB MASKED INPUT FORMATTER
// Accepts digits only. Auto-inserts dashes: MM-DD-YYYY
// ================================================================
class _DobInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.trim();
    // Try YYYY-MM-DD or YYYY/MM/DD
    final isoMatch = RegExp(r'^(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})$').firstMatch(text);
    if (isoMatch != null) {
      final yyyy = isoMatch.group(1)!;
      final mm = isoMatch.group(2)!.padLeft(2, '0');
      final dd = isoMatch.group(3)!.padLeft(2, '0');
      text = '$mm$dd$yyyy';
    } else {
      // Try M/D/YYYY, MM/DD/YYYY, M-D-YYYY, or M/D/YY
      final sepMatch = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})$').firstMatch(text);
      if (sepMatch != null) {
        int m = int.parse(sepMatch.group(1)!);
        int d = int.parse(sepMatch.group(2)!);
        int y = int.parse(sepMatch.group(3)!);
        if (y < 100) y += (y <= 30 ? 2000 : 1900);
        if (m > 12 && d <= 12) {
          final tmp = m;
          m = d;
          d = tmp;
        }
        final mm = m.toString().padLeft(2, '0');
        final dd = d.toString().padLeft(2, '0');
        text = '$mm$dd$y';
      }
    }

    // Strip everything that's not a digit
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    // Limit to 8 raw digits (MMDDYYYY)
    final d = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buf = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      buf.write(d[i]);
      if (i == 1 || i == 3) buf.write('-'); // after MM and DD
    }
    final result = buf.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ================================================================
// DOB PICKER — MM-DD-YYYY typed field (no suggestion dropdown)
// ================================================================
class _DobPicker extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onChanged;

  const _DobPicker({Key? key, this.initialDate, required this.onChanged})
      : super(key: key);

  @override
  State<_DobPicker> createState() => _DobPickerState();
}

class _DobPickerState extends State<_DobPicker> {
  late final TextEditingController _ctrl;
  DateTime? _lastParsedDate;

  static String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.year}';

  @override
  void initState() {
    super.initState();
    _lastParsedDate = widget.initialDate;
    _ctrl = TextEditingController(
      text: widget.initialDate != null ? _fmt(widget.initialDate!) : '',
    );
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _DobPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External update (e.g. OCR fill or modal reset)
    if (widget.initialDate != _lastParsedDate) {
      _lastParsedDate = widget.initialDate;
      final newText = widget.initialDate != null ? _fmt(widget.initialDate!) : '';
      if (_ctrl.text != newText) {
        _ctrl.removeListener(_onTextChanged);
        _ctrl.text = newText;
        _ctrl.addListener(_onTextChanged);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() => _parseAndNotify();

  // ── Parse & notify parent ───────────────────────────────────────

  String get _rawDigits => _ctrl.text.replaceAll('-', '');

  int _maxDayForMonth(int month, int? year) {
    if (month == 2) {
      if (year != null && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))) {
        return 29;
      }
      return 28;
    }
    if ([4, 6, 9, 11].contains(month)) return 30;
    return 31;
  }

  void _parseAndNotify() {
    final raw = _rawDigits;
    DateTime? parsed;
    if (raw.length == 8) {
      final mm   = int.tryParse(raw.substring(0, 2));
      final dd   = int.tryParse(raw.substring(2, 4));
      final yyyy = int.tryParse(raw.substring(4, 8));
      final now  = DateTime.now().year;
      if (mm != null && dd != null && yyyy != null &&
          mm >= 1 && mm <= 12 &&
          dd >= 1 && dd <= _maxDayForMonth(mm, yyyy) &&
          yyyy >= 1900 && yyyy <= now) {
        parsed = DateTime(yyyy, mm, dd);
      }
    }
    _lastParsedDate = parsed;
    widget.onChanged(parsed);
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [_DobInputFormatter()],
      style: const TextStyle(fontSize: 14, letterSpacing: 0.5),
      decoration: InputDecoration(
        labelText: 'DATE OF BIRTH (Optional)',
        hintText: 'MM-DD-YYYY',
        prefixIcon: const Icon(
          Icons.cake_outlined,
          color: AppColors.textSecondary,
        ),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged(null);
                },
              )
            : null,
      ),
    );
  }
}




