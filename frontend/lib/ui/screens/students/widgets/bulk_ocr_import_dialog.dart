import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../providers/ocr_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/setup_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/widgets/app_button_loader.dart';
import 'package:flutter/services.dart';

class _UpperCaseAllTextFormatter extends TextInputFormatter {
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

// ---------------------------------------------------------------------------
// Data model for a queued file and its OCR result
// ---------------------------------------------------------------------------
enum _FileStatus { pending, processing, done, error }

class _OcrItem {
  final String filePath;
  final String fileName;
  _FileStatus status;
  String? errorMsg;

  // editable fields
  String lrn;
  String firstName;
  String middleName;
  String lastName;
  String extension;
  String sex;
  String dob; // 'YYYY-MM-DD' or ''
  bool is4ps;

  // enrollment
  int? academicYearId;
  int? sectionId;
  int? gradeLevel;
  String? trackStrand;

  _OcrItem({
    required this.filePath,
    required this.fileName,
    this.status = _FileStatus.pending,
    this.errorMsg,
    this.lrn = '',
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.extension = '',
    this.sex = 'Male',
    this.dob = '',
    this.is4ps = false,
    this.academicYearId,
    this.sectionId,
    this.gradeLevel,
    this.trackStrand,
  });

  bool get hasRequiredFields =>
      lrn.isNotEmpty &&
      RegExp(r'^\d{12}$').hasMatch(lrn) &&
      firstName.isNotEmpty &&
      lastName.isNotEmpty &&
      (sex == 'Male' || sex == 'Female');
}

// ---------------------------------------------------------------------------
// Dialog
// ---------------------------------------------------------------------------
class BulkOcrImportDialog extends ConsumerStatefulWidget {
  const BulkOcrImportDialog({super.key, this.preloadedFiles});

  final List<File>? preloadedFiles;

  @override
  ConsumerState<BulkOcrImportDialog> createState() =>
      _BulkOcrImportDialogState();
}

class _BulkOcrImportDialogState extends ConsumerState<BulkOcrImportDialog> {
  int _step = 0; // 0=Upload  1=Review  2=Summary

  final List<_OcrItem> _items = [];
  bool _isDragOver = false;
  Timer? _dragResetTimer;
  bool _isProcessing = false;

  @override
  void dispose() {
    _dragResetTimer?.cancel();
    super.dispose();
  }
  int _processingIndex = -1;

  @override
  void initState() {
    super.initState();
    final preloaded = widget.preloadedFiles;
    if (preloaded != null) {
      for (final f in preloaded) {
        final name = f.path.split(Platform.pathSeparator).last;
        _items.add(_OcrItem(filePath: f.path, fileName: name));
      }
    }
  }

  // Shared enrollment selection
  int? _sharedAcademicYearId;
  int? _sharedSectionId;
  int? _sharedGradeLevel;
  String? _sharedTrackStrand;

  // Import summary
  Map<String, dynamic>? _importResult;
  bool _isImporting = false;

  static const _allowedExtensions = [
    'pdf', 'jpg', 'jpeg', 'png', 'xlsx', 'xls', 'csv',
  ];

  // ── file picking ──────────────────────────────────────────────────────────
  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
    );
    if (result == null) return;
    _addFiles(result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList());
  }

  void _addFiles(List<File> files) {
    setState(() {
      for (final f in files) {
        final name = f.path.split(Platform.pathSeparator).last;
        if (!_items.any((i) => i.filePath == f.path)) {
          _items.add(_OcrItem(filePath: f.path, fileName: name));
        }
      }
    });
  }

  void _removeItem(int index) {
    if (_isProcessing) return;
    setState(() => _items.removeAt(index));
  }

  // ── doc-type detection ────────────────────────────────────────────────────
  String? _detectDocType(String name) {
    final l = name.toLowerCase();
    if (l.contains('sf9') ||
        l.contains('sf-9') ||
        l.contains('sf 9') ||
        l.contains('report card') ||
        l.contains('reportcard') ||
        l.contains('student report card') ||
        l.contains('form 138') ||
        l.contains('form-138') ||
        l.contains('form138') ||
        l.contains('school form 9') ||
        l.contains('school-form-9') ||
        l.contains('sf1 for jhs') ||
        l.contains('sf1') ||
        l.contains('sf-1') ||
        l.contains('sf 1')) {
      return 'SF9';
    }
    if (l.contains('sf10') ||
        l.contains('sf-10') ||
        l.contains('sf 10') ||
        l.contains('permanent record') ||
        l.contains('permanentrecord') ||
        l.contains('student permanent record') ||
        l.contains('school form 10') ||
        l.contains('school-form-10') ||
        l.contains('form 137') ||
        l.contains('form-137') ||
        l.contains('form137') ||
        l.contains('form 137-a') ||
        l.contains('form 137a') ||
        l.contains('form 10') ||
        l.contains('form-10')) {
      return 'SF10';
    }
    return null;
  }

  Future<String?> _askDocType(String fileName) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.help_outline_rounded,
            color: AppColors.primaryGreen, size: 36),
        title: const Text('Select Document Type',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'Could not auto-detect the type for:\n"$fileName"\n\nPlease select:',
          textAlign: TextAlign.center,
          style:
              const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actionsPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop('SF9'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('SF9\nReport Card',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop('SF10'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('SF10\nPermanent Record',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── OCR processing ────────────────────────────────────────────────────────
  Future<void> _processAll() async {
    if (_items.isEmpty) return;
    setState(() {
      _isProcessing = true;
      for (final item in _items) {
        if (item.status != _FileStatus.done) {
          item.status = _FileStatus.pending;
          item.errorMsg = null;
        }
      }
    });

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.status == _FileStatus.done) continue;

      setState(() {
        _processingIndex = i;
        item.status = _FileStatus.processing;
      });

      String? docType = _detectDocType(item.fileName);
      if (docType == null && mounted) {
        docType = await _askDocType(item.fileName);
      }
      if (docType == null) {
        setState(() {
          item.status = _FileStatus.error;
          item.errorMsg = 'Document type not selected.';
        });
        continue;
      }

      try {
        final result = await ref.read(ocrProvider.notifier).processDocument(
              file: File(item.filePath),
              fileName: item.fileName,
              docType: docType,
            );
        if (result != null) {
          setState(() {
            if (result.lrn.isNotEmpty) {
              item.lrn = result.lrn;
            }
            if (result.firstName.isNotEmpty) {
              item.firstName = result.firstName.toUpperCase();
            }
            if (result.lastName.isNotEmpty) {
              item.lastName = result.lastName.toUpperCase();
            }
            item.middleName = result.middleName.toUpperCase();
            item.extension = result.extension.toUpperCase();
            if (result.sex == 'Male' || result.sex == 'Female') {
              item.sex = result.sex;
            }
            if (result.dob != null && result.dob!.isNotEmpty) {
              item.dob = result.dob!;
            }
            // Apply shared enrollment defaults
            item.academicYearId ??= _sharedAcademicYearId;
            item.sectionId ??= _sharedSectionId;
            item.gradeLevel ??= _sharedGradeLevel;
            item.trackStrand ??= _sharedTrackStrand;
            item.status = _FileStatus.done;
          });
        }
      } catch (e) {
        setState(() {
          item.status = _FileStatus.error;
          item.errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    }

    setState(() {
      _isProcessing = false;
      _processingIndex = -1;
      if (_items.any((i) => i.status == _FileStatus.done)) _step = 1;
    });
  }

  // ── import ────────────────────────────────────────────────────────────────
  Future<void> _importAll() async {
    // Push shared enrollment down to rows that still lack it
    for (final item in _items.where((i) => i.status == _FileStatus.done)) {
      item.academicYearId ??= _sharedAcademicYearId;
      item.sectionId ??= _sharedSectionId;
      item.gradeLevel ??= _sharedGradeLevel;
      item.trackStrand ??= _sharedTrackStrand;
    }

    // Validate enrollment completeness & grade level bounds (7-12)
    final missingEnr = _items
        .where((i) =>
            i.status == _FileStatus.done &&
            (i.academicYearId == null ||
                i.gradeLevel == null ||
                i.gradeLevel! < 7 ||
                i.gradeLevel! > 12 ||
                i.sectionId == null))
        .toList();
    if (missingEnr.isNotEmpty && mounted) {
      showErrorDialog(context, 'Invalid Enrollment',
          'Please select a valid Academic Year, Grade Level (Grades 7–12), and Section before importing.');
      return;
    }

    final validItems = _items
        .where((i) =>
            i.status == _FileStatus.done && i.hasRequiredFields)
        .toList();
    if (validItems.isEmpty && mounted) {
      showErrorDialog(context, 'Nothing to Import',
          'No valid student records found. Each row needs LRN (12 digits), First Name, Last Name, and Sex.');
      return;
    }

    setState(() => _isImporting = true);

    final payload = validItems.map((item) {
      return <String, dynamic>{
        'lrn': item.lrn.trim(),
        'firstName': item.firstName.trim(),
        'middleName':
            item.middleName.trim().isEmpty ? null : item.middleName.trim(),
        'lastName': item.lastName.trim(),
        'extension':
            item.extension.trim().isEmpty ? null : item.extension.trim(),
        'sex': item.sex,
        'birthDate': item.dob.isNotEmpty ? item.dob : null,
        'academicYearId': item.academicYearId,
        'gradeLevel': item.gradeLevel,
        'sectionId': item.sectionId,
        'trackStrand': item.trackStrand,
        'is4ps': item.is4ps,
      };
    }).toList();

    try {
      final result = await ref
          .read(studentMutationProvider.notifier)
          .bulkCreateStudents(payload);
      setState(() {
        _importResult = result;
        _isImporting = false;
        _step = 2;
      });
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        showErrorDialog(context, 'Import Failed',
            e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Bulk OCR Student Import',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepper(),
            if (_isProcessing || _isImporting)
              const LinearProgressIndicator(
                color: AppColors.primaryGreen,
                backgroundColor: Color(0xFFE0E0E0),
                minHeight: 3,
              ),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── stepper ───────────────────────────────────────────────────────────────
  Widget _buildStepper() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const totalSteps = 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
      child: Row(
        children: List.generate(totalSteps, (idx) {
          final activeOrDone = _step >= idx;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: idx < totalSteps - 1 ? 6 : 0),
              decoration: BoxDecoration(
                color: activeOrDone
                    ? AppColors.primaryGreen
                    : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildUploadStep();
      case 1:
        return _buildReviewStep();
      case 2:
        return _buildSummaryStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 0: UPLOAD ────────────────────────────────────────────────────────
  Widget _buildUploadStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    Widget dropZone = GestureDetector(
      onTap: _isProcessing ? null : _pickFiles,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: _isDragOver
              ? AppColors.primaryGreen.withValues(alpha: 0.12)
              : AppColors.primaryGreen.withValues(alpha: 0.04),
          border: Border.all(
            color: _isDragOver
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withValues(alpha: 0.3),
            width: _isDragOver ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isDragOver
                  ? Icons.file_download_outlined
                  : Icons.document_scanner_outlined,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isWindows
                ? (_isDragOver
                    ? 'Drop Files Here'
                    : 'Drag & Drop or Click to Select Files')
                : 'Tap to Select Files',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Supports PDF, JPG, PNG, JPEG, XLSX, XLS, CSV\nNo file limit — one file per student',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                height: 1.6),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _pickFiles,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Browse Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ]),
      ),
    );

    if (isWindows) {
      dropZone = DropTarget(
        onDragEntered: (_) {
          _dragResetTimer?.cancel();
          if (mounted) setState(() => _isDragOver = true);
          _dragResetTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && _isDragOver) {
              setState(() => _isDragOver = false);
            }
          });
        },
        onDragExited: (_) {
          _dragResetTimer?.cancel();
          if (mounted) setState(() => _isDragOver = false);
        },
        onDragDone: (detail) {
          _dragResetTimer?.cancel();
          if (mounted) setState(() => _isDragOver = false);
          if (detail.files.isNotEmpty) {
            final valid = detail.files
                .where((f) => _allowedExtensions
                    .contains(f.path.split('.').last.toLowerCase()))
                .map((f) => File(f.path))
                .toList();
            _addFiles(valid);
          }
        },
        child: dropZone,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        dropZone,
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(children: [
            Text('Queued Files (${_items.length})',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
            const Spacer(),
            if (!_isProcessing)
              TextButton.icon(
                onPressed: () => setState(() => _items.clear()),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.error, iconSize: 16),
              ),
          ]),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, _s) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _buildFileQueueTile(_items[i], i),
          ),
        ],
      ]),
    );
  }

  Widget _buildFileQueueTile(_OcrItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (item.status) {
      case _FileStatus.processing:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = _processingIndex == index
            ? 'Processing ${_processingIndex + 1} / ${_items.length}…'
            : 'Queued';
        break;
      case _FileStatus.done:
        statusColor = AppColors.primaryGreen;
        statusIcon = Icons.check_circle_outline_rounded;
        statusLabel = 'Done';
        break;
      case _FileStatus.error:
        statusColor = AppColors.error;
        statusIcon = Icons.error_outline_rounded;
        statusLabel = item.errorMsg ?? 'Error';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(Icons.insert_drive_file_outlined,
            size: 20,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary)),
                if (item.status != _FileStatus.pending)
                  Row(children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: statusColor)),
                    ),
                  ]),
              ]),
        ),
        if (!_isProcessing)
          IconButton(
            onPressed: () => _removeItem(index),
            icon: const Icon(Icons.close, size: 16),
            color: isDark ? AppColors.darkTextMuted : Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    );
  }

  // ── STEP 1: REVIEW ────────────────────────────────────────────────────────
  Widget _buildReviewStep() {
    final academicYearsAsync = ref.watch(academicYearsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final doneItems = _items.where((i) => i.status == _FileStatus.done).toList();

    return Column(children: [
      _buildSharedEnrollmentPicker(academicYearsAsync, sectionsAsync),
      Expanded(
        child: doneItems.isEmpty
            ? const Center(
                child: Text('No successfully scanned records.',
                    style: TextStyle(color: AppColors.textSecondary)))
            : _buildReviewList(doneItems),
      ),
    ]);
  }

  Widget _buildSharedEnrollmentPicker(
    AsyncValue<List<AcademicYearModel>> academicYearsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final academicYears = academicYearsAsync.asData?.value ?? <AcademicYearModel>[];
    final allSections = sectionsAsync.asData?.value ?? <SectionModel>[];
    final filteredSections = _sharedGradeLevel != null
        ? allSections.where((s) => s.gradeLevel == _sharedGradeLevel).toList()
        : allSections;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? AppColors.primaryGreen.withValues(alpha: 0.12) : const Color(0xFFF0FAF4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryGreen),
          SizedBox(width: 6),
          Text('Apply enrollment to all rows:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primaryGreen)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int>(
              initialValue: _sharedAcademicYearId,
              isExpanded: true,
              decoration: _compactDeco(context, 'Academic Year'),
              items: academicYears
                  .map((y) => DropdownMenuItem<int>(
                      value: y.id, child: Text(y.yearRange)))
                  .toList(),
              onChanged: (v) => setState(() {
                _sharedAcademicYearId = v;
                _sharedSectionId = null;
                for (final item in _items) {
                  item.academicYearId = v;
                  item.sectionId = null;
                }
              }),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              initialValue: _sharedGradeLevel,
              isExpanded: true,
              decoration: _compactDeco(context, 'Grade Level'),
              items: [7, 8, 9, 10, 11, 12]
                  .map((g) => DropdownMenuItem<int>(
                      value: g, child: Text('Grade $g')))
                  .toList(),
              onChanged: (v) => setState(() {
                _sharedGradeLevel = v;
                _sharedSectionId = null;
                for (final item in _items) {
                  item.gradeLevel = v;
                  item.sectionId = null;
                }
              }),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: filteredSections.any((s) => s.id == _sharedSectionId)
                  ? _sharedSectionId
                  : null,
              isExpanded: true,
              decoration: _compactDeco(context, 'Section'),
              items: filteredSections
                  .map((s) =>
                      DropdownMenuItem<int>(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() {
                _sharedSectionId = v;
                for (final item in _items) {
                  item.sectionId = v;
                }
              }),
            ),
          ),
        ]),
      ]),
    );
  }

  InputDecoration _compactDeco(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface2 : Colors.white,
    );
  }

  Widget _buildReviewList(List<_OcrItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = items[i];
        final rowIndex = _items.indexOf(item);
        final isValid = item.hasRequiredFields;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isValid
                  ? AppColors.primaryGreen.withValues(alpha: 0.4)
                  : AppColors.error.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(children: [
            // row header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isValid
                    ? AppColors.primaryGreen.withValues(alpha: 0.07)
                    : AppColors.error.withValues(alpha: 0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(children: [
                Icon(
                  isValid
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: isValid ? AppColors.primaryGreen : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isValid
                              ? AppColors.primaryGreen
                              : AppColors.warning)),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _items.removeAt(rowIndex)),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove row',
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildRowEditFields(item),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildRowEditFields(_OcrItem item) => Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          _editField('LRN', item.lrn, (v) => item.lrn = v,
              width: 160, keyboardType: TextInputType.number),
          _editField('Last Name', item.lastName, (v) => item.lastName = v,
              width: 160, toUpperCase: true),
          _editField('First Name', item.firstName,
              (v) => item.firstName = v, width: 160, toUpperCase: true),
          _editField('Middle Name', item.middleName,
              (v) => item.middleName = v, width: 140, toUpperCase: true),
          _editField('Extension', item.extension,
              (v) => item.extension = v, width: 90, toUpperCase: true),
          _sexDropdown(item),
          _editField('Date of Birth', item.dob, (v) => item.dob = v,
              width: 130, hint: 'YYYY-MM-DD'),
          _is4psCheckbox(item),
        ],
      );

  Widget _editField(
    String label,
    String value,
    void Function(String) onChanged, {
    double width = 150,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    bool toUpperCase = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: value,
        keyboardType: keyboardType,
        textCapitalization: toUpperCase
            ? TextCapitalization.characters
            : TextCapitalization.none,
        inputFormatters: toUpperCase
            ? [
                _UpperCaseAllTextFormatter(),
              ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F9FA),
        ),
        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        onChanged: (v) =>
            setState(() => onChanged(toUpperCase ? v.toUpperCase() : v)),
      ),
    );
  }

  Widget _sexDropdown(_OcrItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 110,
      child: DropdownButtonFormField<String>(
        initialValue: item.sex,
        isExpanded: true,
        decoration: _compactDeco(context, 'Sex'),
        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
        items: ['Male', 'Female']
            .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) => setState(() => item.sex = v ?? 'Male'),
      ),
    );
  }

  Widget _is4psCheckbox(_OcrItem item) => SizedBox(
        width: 100,
        child: CheckboxListTile(
          value: item.is4ps,
          onChanged: (v) => setState(() => item.is4ps = v ?? false),
          title: const Text('4Ps', style: TextStyle(fontSize: 13)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppColors.primaryGreen,
        ),
      );

  // ── STEP 2: SUMMARY ───────────────────────────────────────────────────────
  Widget _buildSummaryStep() {
    final result = _importResult;
    if (result == null) return const SizedBox.shrink();

    final created = (result['created'] as num?)?.toInt() ?? 0;
    final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
    final failed = (result['failed'] as num?)?.toInt() ?? 0;
    final rows = (result['results'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _summaryCard('Created', created, AppColors.primaryGreen,
              Icons.check_circle_outline),
          const SizedBox(width: 12),
          _summaryCard(
              'Skipped', skipped, Colors.orange, Icons.skip_next_rounded),
          const SizedBox(width: 12),
          _summaryCard('Failed', failed, AppColors.error, Icons.error_outline),
        ]),
        const SizedBox(height: 20),
        const Text('Import Details',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, _s) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final row = rows[i] as Map<String, dynamic>;
            final status = row['status'] as String? ?? 'failed';
            late Color statusColor;
            late IconData statusIcon;
            switch (status) {
              case 'created':
                statusColor = AppColors.primaryGreen;
                statusIcon = Icons.check_circle_outline;
                break;
              case 'skipped':
                statusColor = Colors.orange;
                statusIcon = Icons.skip_next_rounded;
                break;
              default:
                statusColor = AppColors.error;
                statusIcon = Icons.error_outline;
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['name']?.toString() ??
                              row['lrn']?.toString() ??
                              '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (row['reason'] != null)
                          Text(row['reason'].toString(),
                              style: TextStyle(fontSize: 11, color: statusColor)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor)),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _summaryCard(String label, int count, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text('$count',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ]),
        ),
      );

  // ── footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.zero,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (_step < 2) ...[
          OutlinedButton(
            onPressed: _isProcessing || _isImporting
                ? null
                : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(color: isDark ? Colors.white : Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12)),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
        ],

        // Step 0 — Process All
        if (_step == 0 && _items.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processAll,
            icon: _isProcessing
                ? AppButtonLoader(
                    size: 16,
                    color: isDark ? Colors.white : Colors.black,
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(_isProcessing
                ? 'Processing…'
                : 'Process All (${_items.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: isDark ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),

        // Step 1 — Back + Import
        if (_step == 1) ...[
          OutlinedButton.icon(
            onPressed: _isImporting ? null : () => setState(() => _step = 0),
            icon: Icon(Icons.arrow_back, size: 16, color: isDark ? Colors.white : Colors.black),
            label: Text('Back', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(color: isDark ? Colors.white : Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _importAll,
            icon: _isImporting
                ? AppButtonLoader(
                    size: 16,
                    color: isDark ? Colors.white : Colors.black,
                  )
                : const Icon(Icons.upload_rounded, size: 20),
            label: Text(_isImporting
                ? 'Importing…'
                : 'Import All (${_items.where((i) => i.status == _FileStatus.done && i.hasRequiredFields).length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: isDark ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],

        // Step 2 — Done
        if (_step == 2)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: isDark ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
          ),
      ]),
    );
  }
}
