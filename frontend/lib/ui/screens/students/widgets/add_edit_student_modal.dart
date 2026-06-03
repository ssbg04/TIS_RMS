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
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ----------------------------------------------------------------
// Capitalizes the first letter of each word automatically
// ----------------------------------------------------------------
class _UpperCaseWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final capitalized = text.replaceAllMapped(
      RegExp(r'(^|\s)(\S)'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
    return newValue.copyWith(
      text: capitalized,
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

class _AddEditStudentModalState extends ConsumerState<AddEditStudentModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  late TabController _tabController;

  late TextEditingController _lrnController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _extController;

  final PdfViewerController _pdfViewerController = PdfViewerController();

  String _selectedSex = 'Male';
  String _selectedStatus = 'Enrolled';
  DateTime? _selectedDob;
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;
  bool _isEnrollmentInitialized = false;

  static const _statuses = ['Enrolled', 'Graduated', 'Transferred', 'Dropped'];

  bool _showOcrStep = false;
  String? _selectedOcrDocType;
  File? _ocrScannedFile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      _showOcrStep = false;
    } else {
      _showOcrStep = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lrnController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _extController.dispose();
    _pdfViewerController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // OCR PROCESSING
  // ----------------------------------------------------------------
  Future<void> _handleOcrScan(
    File file,
    String fileName,
    String fileSize,
  ) async {
    setState(() {
      _errorMessage = null;
      _ocrScannedFile = file;
    });
    try {
      final ocrResult = await ref
          .read(ocrProvider.notifier)
          .processDocument(
            file: file,
            fileName: fileName,
            docType: _selectedOcrDocType!,
          );
      if (!mounted || ocrResult == null) return;
      setState(() {
        if (ocrResult.lrn.isNotEmpty) _lrnController.text = ocrResult.lrn;
        if (ocrResult.firstName.isNotEmpty)
          _firstNameController.text = ocrResult.firstName;
        if (ocrResult.lastName.isNotEmpty)
          _lastNameController.text = ocrResult.lastName;
        if (ocrResult.middleName.isNotEmpty)
          _middleNameController.text = ocrResult.middleName;
        if (ocrResult.extension.isNotEmpty)
          _extController.text = ocrResult.extension;
        if (ocrResult.sex == 'Male' || ocrResult.sex == 'Female') {
          _selectedSex = ocrResult.sex;
        }
        if (ocrResult.dob != null && ocrResult.dob!.isNotEmpty) {
          try {
            _selectedDob = DateTime.parse(ocrResult.dob!);
          } catch (e) {
            print('Could not parse DOB: ${ocrResult.dob}');
          }
        } else {
          _selectedDob = null;
        }
        _showOcrStep = false;
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
    if (value.trim().length < 2)
      return '$fieldName must be at least 2 characters.';
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
            primary: AppColors.primaryGreen,
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
  // EXIT CONFIRMATION
  // ----------------------------------------------------------------
  bool get _hasAnyData =>
      _lrnController.text.isNotEmpty ||
      _firstNameController.text.isNotEmpty ||
      _middleNameController.text.isNotEmpty ||
      _lastNameController.text.isNotEmpty ||
      _selectedDob != null;

  Future<void> _confirmClose() async {
    // If editing or no data entered, just close
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
            child: const Text('KEEP EDITING', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DISCARD', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (shouldClose == true && mounted) Navigator.of(context).pop();
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
        lnErr != null ||
        _selectedDob == null) {
      _tabController.animateTo(0);
      _formKey.currentState!.validate();
      if (_selectedDob == null) {
        setState(() => _errorMessage = 'Please select a Date of Birth.');
      }
      return;
    }

    // Validate Tab 1: Enrollment Details
    if (_selectedAcademicYearId == null ||
        _selectedGradeLevel == null ||
        _selectedSectionId == null) {
      _tabController.animateTo(1);
      _formKey.currentState!.validate();
      setState(
        () => _errorMessage =
            'Academic Year, Grade Level, and Section are mandatory.',
      );
      return;
    }

    // Validate graduation restriction: status 'Graduated' is only allowed if grade is 10 or 12
    if (_selectedStatus == 'Graduated' &&
        _selectedGradeLevel != 10 &&
        _selectedGradeLevel != 12) {
      _tabController.animateTo(1);
      setState(
        () => _errorMessage =
            'Graduation status is only applicable for Grade 10 and Grade 12 students.',
      );
      return;
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
          birthDate: _selectedDob!,
          academicYearId: _selectedAcademicYearId!,
          gradeLevel: _selectedGradeLevel!,
          sectionId: _selectedSectionId!,
          trackStrand: _trackStrand,
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
          birthDate: _selectedDob!,
          status: _selectedStatus,
          academicYearId: _selectedAcademicYearId!,
          gradeLevel: _selectedGradeLevel!,
          sectionId: _selectedSectionId!,
          trackStrand: _trackStrand,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showSuccessDialog(
        context,
        message: widget.student == null
            ? 'Student added successfully!'
            : 'Student updated successfully!',
      );
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
  // BUILD — viewport-aware, keyboard-safe dialog
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    if (widget.student != null && !_isEnrollmentInitialized) {
      final detailsAsync = ref.watch(studentDetailProvider(widget.student!.id));
      detailsAsync.whenData((fullStudent) {
        if (fullStudent.enrollments != null &&
            fullStudent.enrollments!.isNotEmpty) {
          final latestEnrollment = fullStudent.enrollments!.reduce(
            (a, b) => a.gradeLevel > b.gradeLevel ? a : b,
          );
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

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    double maxDialogHeight = isMobile ? (screenHeight * 0.82) : 550;
    double dialogHeight = maxDialogHeight.clamp(
      200.0,
      screenHeight - viewInsets.bottom - 24.0,
    );

    bool showSideBySide = _ocrScannedFile != null && !isMobile && !_showOcrStep;
    double maxDialogWidth = isMobile ? 380 : (showSideBySide ? 1000 : 620);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12 + viewInsets.bottom * 0.05,
      ),
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : AppSizes.p24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showOcrStep
                ? _buildOcrStep()
                : (showSideBySide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                               child: _buildManualForm(
                                widget.student != null,
                                yearsAsync,
                                gradeLevelsAsync,
                                sectionsAsync,
                                isMobile,
                                viewInsets.bottom,
                              ),
                            ),
                            const VerticalDivider(width: 32),
                            Expanded(
                              flex: 4,
                              child: _buildLocalFilePreview(_ocrScannedFile!),
                            ),
                          ],
                        )
                      : _buildManualForm(
                          widget.student != null,
                          yearsAsync,
                          gradeLevelsAsync,
                          sectionsAsync,
                          isMobile,
                          viewInsets.bottom,
                        )),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalFilePreview(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.preview_rounded,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Document Preview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              child: isPdf
                  ? Stack(
                      children: [
                        SfPdfViewer.file(
                          file,
                          controller: _pdfViewerController,
                          canShowScrollHead: false,
                          canShowScrollStatus: false,
                          interactionMode: PdfInteractionMode.pan,
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FloatingActionButton.small(
                                heroTag: null,
                                backgroundColor: AppColors.primaryGreen,
                                onPressed: () {
                                  _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.5).clamp(1.0, 5.0);
                                },
                                child: const Icon(Icons.zoom_out, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              FloatingActionButton.small(
                                heroTag: null,
                                backgroundColor: AppColors.primaryGreen,
                                onPressed: () {
                                  _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.5).clamp(1.0, 5.0);
                                },
                                child: const Icon(Icons.zoom_in, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.file(file, fit: BoxFit.contain),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMobilePreviewDialog() {
    if (_ocrScannedFile == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scanned Document',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(child: _buildLocalFilePreview(_ocrScannedFile!)),
            ],
          ),
        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Auto-Fill with OCR',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 32),

          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: AppSizes.p16),
          ],

          const Text(
            'Select supported document format to extract data:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSizes.p8),

          DropdownButtonFormField<String>(
            value: _selectedOcrDocType,
            hint: const Text(
              'Choose SF9 (Report Card) or SF10 (Permanent Record)',
            ),
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: ['SF9', 'SF10']
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (val) => setState(() => _selectedOcrDocType = val),
          ),

          const SizedBox(height: AppSizes.p24),

          if (_selectedOcrDocType != null)
            DocumentSourcePicker(
              allowedExtensions: const ['pdf', 'jpg', 'png', 'jpeg'],
              onFileSelected: _handleOcrScan,
              onError: (err) => setState(() => _errorMessage = err),
            ),

          const SizedBox(height: AppSizes.p24),

          Center(
            child: TextButton.icon(
              onPressed: () => setState(() {
                _showOcrStep = false;
                _errorMessage = null;
              }),
              icon: const Icon(
                Icons.keyboard_alt_outlined,
                color: AppColors.textSecondary,
              ),
              label: const Text(
                'Skip OCR & Enter Manually',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STEP 2: MANUAL FORM UI
  // ================================================================
  Widget _buildManualForm(
    bool isEdit,
    AsyncValue<List<AcademicYearModel>> yearsAsync,
    AsyncValue<List<GradeLevelModel>> gradeLevelsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
    bool isMobile,
    double keyboardBottomInset,
  ) {
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isEdit
                        ? 'Update Student Record'
                        : 'Student Details Validation',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: _confirmClose,
                ),
              ],
            ),
            const Divider(height: 16),

            // ---- Tab Bar ----
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryGreen,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  text: 'Student Details',
                  icon: Icon(Icons.person, size: 18),
                ),
                Tab(
                  text: 'Enrollment Details',
                  icon: Icon(Icons.school, size: 18),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 36 : 12),

            // ---- Tab Bar View Content (Responsive Expanded) ----
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Student Details
                  SingleChildScrollView(
                    key: const ValueKey('student-details-tab'),
                    padding: const EdgeInsets.only(right: 6, bottom: 12),
                    child: Column(
                      children: [
                        // LRN
                        TextFormField(
                          controller: _lrnController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: _validateLRN,
                          decoration: const InputDecoration(
                            labelText: 'LRN (Learner Reference Number)',
                            hintText: '12-digit number',
                            prefixIcon: Icon(Icons.pin_outlined),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: AppSizes.p12),

                        // Names & Ext
                        LayoutBuilder(
                          builder: (ctx, c) {
                            final wide = c.maxWidth > 480;
                            if (wide) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _firstNameController,
                                          textCapitalization: TextCapitalization.words,
                                          inputFormatters: [_UpperCaseWordsFormatter()],
                                          validator: (v) => _validateRequired(
                                            v,
                                            'First name',
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: 'First Name',
                                            prefixIcon: Icon(
                                              Icons.badge_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.p12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _middleNameController,
                                          textCapitalization: TextCapitalization.words,
                                          inputFormatters: [_UpperCaseWordsFormatter()],
                                          decoration: const InputDecoration(
                                            labelText: 'Middle Name (optional)',
                                            prefixIcon: Icon(
                                              Icons.badge_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSizes.p12),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: _lastNameController,
                                          textCapitalization: TextCapitalization.words,
                                          inputFormatters: [_UpperCaseWordsFormatter()],
                                          validator: (v) =>
                                              _validateRequired(v, 'Last name'),
                                          decoration: const InputDecoration(
                                            labelText: 'Last Name',
                                            prefixIcon: Icon(
                                              Icons.badge_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.p12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _extController,
                                          textCapitalization: TextCapitalization.words,
                                          inputFormatters: [_UpperCaseWordsFormatter()],
                                          decoration: const InputDecoration(
                                            labelText: 'Ext.',
                                            hintText: 'Jr / III',
                                            prefixIcon: Icon(Icons.text_format),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _firstNameController,
                                    textCapitalization: TextCapitalization.words,
                                    inputFormatters: [_UpperCaseWordsFormatter()],
                                    validator: (v) =>
                                        _validateRequired(v, 'First name'),
                                    decoration: const InputDecoration(
                                      labelText: 'First Name',
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.p12),
                                  TextFormField(
                                    controller: _middleNameController,
                                    textCapitalization: TextCapitalization.words,
                                    inputFormatters: [_UpperCaseWordsFormatter()],
                                    decoration: const InputDecoration(
                                      labelText: 'Middle Name',
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.p12),
                                  TextFormField(
                                    controller: _lastNameController,
                                    textCapitalization: TextCapitalization.words,
                                    inputFormatters: [_UpperCaseWordsFormatter()],
                                    validator: (v) =>
                                        _validateRequired(v, 'Last name'),
                                    decoration: const InputDecoration(
                                      labelText: 'Last Name',
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.p12),
                                  TextFormField(
                                    controller: _extController,
                                    textCapitalization: TextCapitalization.words,
                                    inputFormatters: [_UpperCaseWordsFormatter()],
                                    decoration: const InputDecoration(
                                      labelText: 'Extension (Jr / III)',
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: AppSizes.p12),

                        // Sex
                        DropdownButtonFormField<String>(
                          value: _selectedSex,
                          validator: (v) =>
                              v == null ? 'Please select sex.' : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sex',
                            prefixIcon: Icon(Icons.wc),
                          ),
                          items: ['Male', 'Female']
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedSex = v!),
                        ),
                        const SizedBox(height: AppSizes.p12),

                        // DOB
                        GestureDetector(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              prefixIcon: const Icon(
                                Icons.calendar_today,
                                color: AppColors.textSecondary,
                              ),
                              errorText:
                                  (!_isLoading &&
                                      _errorMessage != null &&
                                      _selectedDob == null)
                                  ? ''
                                  : null,
                            ),
                            child: Text(
                              _selectedDob == null
                                  ? 'Select date…'
                                  : '${_selectedDob!.year}-'
                                        '${_selectedDob!.month.toString().padLeft(2, '0')}-'
                                        '${_selectedDob!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: _selectedDob == null
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 1: Enrollment Details
                  SingleChildScrollView(
                    key: const ValueKey('enrollment-details-tab'),
                    padding: const EdgeInsets.only(right: 6, bottom: 12),
                    child: Column(
                      children: [
                        yearsAsync.when(
                          data: (years) {
                            return DropdownButtonFormField<int>(
                              value: _selectedAcademicYearId,
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
                              validator: (v) => v == null
                                  ? 'Academic year is required.'
                                  : null,
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
                              value: _selectedGradeLevel,
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
                                      sec.academicYearId ==
                                          _selectedAcademicYearId &&
                                      sec.gradeLevel == _selectedGradeLevel,
                                )
                                .toList();

                            return DropdownButtonFormField<int>(
                              value: _selectedSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Section',
                                prefixIcon: Icon(Icons.segment),
                              ),
                              items: filtered
                                  .map(
                                    (s) => DropdownMenuItem<int>(
                                      value: s.id,
                                      child: Text(s.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedSectionId = val),
                              validator: (v) =>
                                  v == null ? 'Section is required.' : null,
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
                            onChanged: (val) => _trackStrand =
                                val.trim().isEmpty ? null : val.trim(),
                          ),
                        ],

                        if (isEdit) ...[
                          const SizedBox(height: AppSizes.p12),
                          DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              prefixIcon: Icon(Icons.info_outline),
                            ),
                            items: _statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedStatus = v!),
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
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (_errorMessage != null) ...[
              _ErrorBanner(message: _errorMessage!),
              const SizedBox(height: AppSizes.p12),
            ],

            // ---- Actions: hidden when keyboard is open on mobile ----
            if (!isMobile || keyboardBottomInset == 0)
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(
                      label: isEdit ? 'UPDATE' : 'SAVE',
                      isLoading: _isLoading,
                      onPressed: _handleSave,
                    ),
                    const SizedBox(height: 8),
                    if (!isEdit && _ocrScannedFile != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _lrnController.clear();
                          _firstNameController.clear();
                          _middleNameController.clear();
                          _lastNameController.clear();
                          _extController.clear();
                          _showOcrStep = true;
                        }),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('RE-SCAN', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _showMobilePreviewDialog,
                        icon: const Icon(Icons.preview_outlined, size: 16),
                        label: const Text('VIEW SCANNED DOCUMENT', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : _confirmClose,
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSizes.p12,
                runSpacing: AppSizes.p8,
                children: [
                  if (!isEdit && _ocrScannedFile != null)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _lrnController.clear();
                        _firstNameController.clear();
                        _middleNameController.clear();
                        _lastNameController.clear();
                        _extController.clear();
                        _showOcrStep = true;
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('RE-SCAN'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : _confirmClose,
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: PrimaryButton(
                      label: isEdit ? 'UPDATE' : 'SAVE',
                      isLoading: _isLoading,
                      onPressed: _handleSave,
                    ),
                  ),
                ],
              ),
          ],
        ),
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
