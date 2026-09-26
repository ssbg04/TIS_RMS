import 'dart:async';
import 'dart:convert';
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
import 'student_form_helpers.dart';

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
    this.lrn = '308035',
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

class _ParsedStudentRow {
  final int rowIndex;
  String lrn;
  String firstName;
  String middleName;
  String lastName;
  String extension;
  String sex;
  String dob;
  bool is4ps;
  final List<String> errors;

  bool get isValid => errors.isEmpty;

  String get fullName {
    final parts = [lastName, firstName, middleName, extension]
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Unnamed';
    final name = '$lastName, $firstName';
    final extra =
        [middleName, extension].where((p) => p.trim().isNotEmpty).join(' ');
    return extra.isNotEmpty ? '$name $extra' : name;
  }

  _ParsedStudentRow({
    required this.rowIndex,
    required this.lrn,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.extension,
    required this.sex,
    required this.dob,
    required this.is4ps,
    required this.errors,
  });
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
  int _activeInputTab = 0; // 0=Document Files/Scan, 1=Live Type/Paste CSV

  final List<_OcrItem> _items = [];
  bool _isDragOver = false;
  Timer? _dragResetTimer;
  bool _isProcessing = false;
  int _processingIndex = -1;

  // CSV Live Input & Validation
  final TextEditingController _csvTextController = TextEditingController();
  List<_ParsedStudentRow> _parsedStudentRows = [];
  bool _hasParsedCsv = false;

  static const String _sampleCsvTemplate =
      'LRN,First Name,Middle Name,Last Name,Extension,Sex,Birth Date,4Ps\n'
      '308035123456,Juan,Protacio,Rizal,Jr.,Male,2008-06-19,Yes\n'
      '308035654321,Maria,Clara,Santos,,Female,2009-11-23,No\n'
      '308035987654,Andres,Castro,Bonifacio,,Male,2008-11-30,No\n'
      '308035112233,Gabriela,Silang,Cariño,,Female,2009-03-19,Yes';

  @override
  void dispose() {
    _dragResetTimer?.cancel();
    _csvTextController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final preloaded = widget.preloadedFiles;
    if (preloaded != null) {
      File? preloadedCsv;
      for (final f in preloaded) {
        final name = f.path.split(Platform.pathSeparator).last;
        if (name.toLowerCase().endsWith('.csv')) {
          preloadedCsv ??= f;
        } else {
          _items.add(_OcrItem(filePath: f.path, fileName: name));
        }
      }
      if (preloadedCsv != null) {
        _loadCsvFromFile(preloadedCsv);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(sectionsListProvider);
      }
    });
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
    final csvFiles =
        files.where((f) => f.path.toLowerCase().endsWith('.csv')).toList();
    final otherFiles =
        files.where((f) => !f.path.toLowerCase().endsWith('.csv')).toList();

    if (csvFiles.isNotEmpty) {
      _loadCsvFromFile(csvFiles.first);
    }

    if (otherFiles.isNotEmpty) {
      setState(() {
        for (final f in otherFiles) {
          final name = f.path.split(Platform.pathSeparator).last;
          if (!_items.any((i) => i.filePath == f.path)) {
            _items.add(_OcrItem(filePath: f.path, fileName: name));
          }
        }
      });
    }
  }

  Future<void> _loadCsvFromFile(File file) async {
    try {
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          _activeInputTab = 1;
          _csvTextController.text = content;
        });
        _parseCsvInput();
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'CSV Read Error', 'Failed to read CSV file: $e');
      }
    }
  }

  void _copyTemplate() {
    Clipboard.setData(const ClipboardData(text: _sampleCsvTemplate));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV student template copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _loadSampleData() {
    setState(() {
      _csvTextController.text = _sampleCsvTemplate;
    });
    _parseCsvInput();
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        await _loadCsvFromFile(File(result.files.single.path!));
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'File Error', 'Failed to read file: $e');
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _csvTextController.text = data.text!;
      });
      _parseCsvInput();
    }
  }

  void _clearCsvInput() {
    setState(() {
      _csvTextController.clear();
      _parsedStudentRows = [];
      _hasParsedCsv = false;
    });
  }

  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer sb = StringBuffer();
    bool inQuotes = false;
    final String delimiter = line.contains('\t')
        ? '\t'
        : (line.contains(';') && !line.contains(',') ? ';' : ',');

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  bool _isHeaderLine(List<String> parts) {
    if (parts.isEmpty) return false;
    final first = parts[0].toLowerCase();
    final joined = parts.join(' ').toLowerCase();
    return first.contains('lrn') ||
        first.contains('student') ||
        joined.contains('first name') ||
        joined.contains('last name') ||
        joined.contains('birth date');
  }

  void _parseCsvInput() {
    final text = _csvTextController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedStudentRows = [];
        _hasParsedCsv = false;
      });
      return;
    }

    final lines = const LineSplitter().convert(text);
    final List<_ParsedStudentRow> parsed = [];
    final Set<String> batchLrns = {};
    int rowCounter = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _parseCsvLine(line);
      if (i == 0 && _isHeaderLine(parts)) {
        continue;
      }

      rowCounter++;
      final List<String> errors = [];

      final rawLrn = parts.isNotEmpty
          ? parts[0].replaceAll(RegExp(r'\D'), '')
          : '';
      final rawFirstName = parts.length > 1 ? parts[1].trim() : '';
      final rawMiddleName = parts.length > 2 ? parts[2].trim() : '';
      final rawLastName = parts.length > 3 ? parts[3].trim() : '';
      final rawExtension = parts.length > 4 ? parts[4].trim() : '';
      final rawSex = parts.length > 5 ? parts[5].trim() : '';
      final rawDob = parts.length > 6 ? parts[6].trim() : '';
      final raw4ps = parts.length > 7 ? parts[7].trim() : '';

      // Validate LRN
      if (rawLrn.isEmpty) {
        errors.add('LRN is required.');
      } else if (rawLrn.length != 12) {
        errors.add('LRN must be exactly 12 digits (got ${rawLrn.length}).');
      } else if (batchLrns.contains(rawLrn)) {
        errors.add('Duplicate LRN ($rawLrn) within this batch.');
      } else {
        batchLrns.add(rawLrn);
      }

      // Validate Names
      if (rawFirstName.isEmpty) {
        errors.add('First name is required.');
      }
      if (rawLastName.isEmpty) {
        errors.add('Last name is required.');
      }

      // Validate Sex
      String normSex = '';
      final sexLower = rawSex.toLowerCase();
      if (sexLower == 'male' || sexLower == 'm') {
        normSex = 'Male';
      } else if (sexLower == 'female' || sexLower == 'f') {
        normSex = 'Female';
      } else if (rawSex.isEmpty) {
        errors.add('Sex is required (Male/Female).');
      } else {
        errors.add('Invalid sex "$rawSex" (must be Male or Female).');
      }

      // Validate Birth Date
      String normDob = '';
      if (rawDob.isNotEmpty) {
        final parsedDate = _parseFlexibleDob(rawDob);
        if (parsedDate == null) {
          errors.add('Invalid date "$rawDob" (use YYYY-MM-DD or MM/DD/YYYY).');
        } else if (parsedDate.isAfter(DateTime.now())) {
          errors.add('Birth date cannot be in the future.');
        } else {
          normDob =
              '${parsedDate.year.toString().padLeft(4, '0')}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
        }
      }

      // Parse 4Ps
      final s4ps = raw4ps.toLowerCase();
      final is4ps =
          s4ps == 'yes' || s4ps == 'y' || s4ps == 'true' || s4ps == '1';

      parsed.add(_ParsedStudentRow(
        rowIndex: rowCounter,
        lrn: rawLrn,
        firstName: rawFirstName,
        middleName: rawMiddleName,
        lastName: rawLastName,
        extension: rawExtension,
        sex: normSex.isNotEmpty ? normSex : rawSex,
        dob: normDob.isNotEmpty ? normDob : rawDob,
        is4ps: is4ps,
        errors: errors,
      ));
    }

    setState(() {
      _parsedStudentRows = parsed;
      _hasParsedCsv = true;
    });
  }

  void _applyValidCsvRowsToQueue() {
    final validRows = _parsedStudentRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      showErrorDialog(
        context,
        'No Valid Students',
        'Please correct or add at least one valid student row before proceeding.',
      );
      return;
    }

    setState(() {
      // Remove previously applied CSV items to avoid duplication if re-applying
      _items.removeWhere((i) => i.filePath.startsWith('csv_row_'));

      for (final row in validRows) {
        _items.add(
          _OcrItem(
            filePath: 'csv_row_${row.rowIndex}',
            fileName:
                '${row.lastName}, ${row.firstName} (CSV Row #${row.rowIndex})',
            status: _FileStatus.done,
            lrn: row.lrn,
            firstName: row.firstName.toUpperCase(),
            middleName: row.middleName.toUpperCase(),
            lastName: row.lastName.toUpperCase(),
            extension: row.extension.toUpperCase(),
            sex: row.sex,
            dob: row.dob,
            is4ps: row.is4ps,
            academicYearId: _sharedAcademicYearId,
            gradeLevel: _sharedGradeLevel,
            sectionId: _sharedSectionId,
            trackStrand: _sharedTrackStrand,
          ),
        );
      }

      _step = 1; // Advance to Step 1 Review
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
              final parsed = _parseFlexibleDob(result.dob);
              item.dob = parsed != null
                  ? '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}'
                  : result.dob!;
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
    // Push shared enrollment down to rows
    for (final item in _items.where((i) => i.status == _FileStatus.done)) {
      if (_sharedAcademicYearId != null) item.academicYearId = _sharedAcademicYearId;
      if (_sharedSectionId != null) item.sectionId = _sharedSectionId;
      if (_sharedGradeLevel != null) item.gradeLevel = _sharedGradeLevel;
      item.trackStrand = _sharedTrackStrand;
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
      backgroundColor:
          isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Row(
          children: [
            Icon(Icons.group_add_outlined, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Bulk Student Import (OCR & CSV)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
    const stepLabels = [
      '1. Select / Input Students',
      '2. Review & Assign Section',
      '3. Import Results',
    ];
    const totalSteps = 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: isDark ? AppColors.darkPageBackground : const Color(0xFFF8F9FA),
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalSteps, (idx) {
              final isCurrent = _step == idx;
              final isDone = _step > idx;
              return Text(
                stepLabels[idx],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent || isDone
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isCurrent
                      ? AppColors.primaryGreen
                      : (isDone
                          ? (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary)
                          : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted)),
                ),
              );
            }),
          ),
        ],
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

  // ── STEP 0: UPLOAD & CSV INPUT ────────────────────────────────────────────
  Widget _buildUploadStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStep0ModeSelector(isDark),
          if (_activeInputTab == 0)
            _buildFilesTab(isDark, isWindows)
          else
            _buildLiveCsvStep(isDark),
        ],
      ),
    );
  }

  Widget _buildStep0ModeSelector(bool isDark) {
    final fileCount =
        _items.where((i) => !i.filePath.startsWith('csv_row_')).length;
    final csvValidCount = _parsedStudentRows.where((r) => r.isValid).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTabButton(
              index: 0,
              icon: Icons.document_scanner_outlined,
              label: 'Document Files & Scan (OCR)',
              badgeCount: fileCount,
              badgeColor: AppColors.primaryGreen,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeTabButton(
              index: 1,
              icon: Icons.table_chart_outlined,
              label: 'Live Type / Paste CSV',
              badgeCount: csvValidCount,
              badgeColor: Colors.blue.shade600,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required int index,
    required IconData icon,
    required String label,
    required int badgeCount,
    required Color badgeColor,
    required bool isDark,
  }) {
    final isSelected = _activeInputTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _activeInputTab = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkSurfaceCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: isSelected
                ? Border.all(
                    color: isDark
                        ? AppColors.primaryGreen.withValues(alpha: 0.6)
                        : AppColors.primaryGreen,
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primaryGreen
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary)
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 0: Files Upload & OCR ──
  Widget _buildFilesTab(bool isDark, bool isWindows) {
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
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Supports PDF, JPG, PNG, JPEG, XLSX, XLS, CSV\nNo file limit — one file per student',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

    final fileItems =
        _items.where((i) => !i.filePath.startsWith('csv_row_')).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      dropZone,
      if (fileItems.isNotEmpty) ...[
        const SizedBox(height: 20),
        Row(children: [
          Text('Queued Files (${fileItems.length})',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary)),
          const Spacer(),
          if (!_isProcessing)
            TextButton.icon(
              onPressed: () => setState(() {
                _items.removeWhere(
                    (i) => !i.filePath.startsWith('csv_row_'));
              }),
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
          itemCount: fileItems.length,
          separatorBuilder: (_, unused) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _buildFileQueueTile(fileItems[i], i),
        ),
      ],
    ]);
  }

  // ── Tab 1: Live Type / Paste CSV ──
  Widget _buildLiveCsvStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCsvFormatGuide(isDark),
        const SizedBox(height: 20),
        _buildCsvInputArea(isDark),
        if (_hasParsedCsv) ...[
          const SizedBox(height: 24),
          _buildCsvValidationTable(isDark),
        ],
      ],
    );
  }

  Widget _buildCsvFormatGuide(bool isDark) {
    final cardBg = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryGreen.withValues(alpha: 0.12)
                  : const Color(0xFFF0FAF4),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.primaryGreen.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 20,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CSV Format Reference & Sample Template',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '8 Columns: LRN, First Name, Middle Name, Last Name, Extension, Sex, Birth Date, 4Ps',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadSampleData,
                      icon: const Icon(Icons.flash_on_rounded, size: 15),
                      label: const Text('Fill Example',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: BorderSide(
                          color: AppColors.primaryGreen.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _copyTemplate,
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copy Template',
                          style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column definitions badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildColumnBadge(
                        '1. LRN', '12 Digits (Req.)', true, isDark),
                    _buildColumnBadge(
                        '2. First Name', 'Required', true, isDark),
                    _buildColumnBadge(
                        '3. Middle Name', 'Optional', false, isDark),
                    _buildColumnBadge(
                        '4. Last Name', 'Required', true, isDark),
                    _buildColumnBadge(
                        '5. Extension', 'Jr, Sr, III (Opt.)', false, isDark),
                    _buildColumnBadge(
                        '6. Sex', 'Male / Female (Req.)', true, isDark),
                    _buildColumnBadge(
                        '7. Birth Date', 'YYYY-MM-DD (Opt.)', false, isDark),
                    _buildColumnBadge('8. 4Ps', 'Yes / No (Opt.)', false, isDark),
                  ],
                ),
                const SizedBox(height: 14),

                // Sample CSV code box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: SelectableText(
                    _sampleCsvTemplate,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: isDark
                          ? Colors.green.shade300
                          : const Color(0xFF2E7D32),
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

  Widget _buildColumnBadge(
      String title, String subtitle, bool isRequired, bool isDark) {
    final badgeColor = isRequired ? AppColors.primaryGreen : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: isDark ? 0.4 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color:
                  isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isRequired ? FontWeight.w600 : FontWeight.normal,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCsvInputArea(bool isDark) {
    final cardBg = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : Colors.grey.shade300;
    final lineCount = _csvTextController.text.trim().isEmpty
        ? 0
        : const LineSplitter()
            .convert(_csvTextController.text.trim())
            .where((l) => l.trim().isNotEmpty)
            .length;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 22,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Type / Paste CSV Input',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (lineCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$lineCount line${lineCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _pickCsvFile,
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Browse File',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.white : AppColors.textPrimary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Paste', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.white : AppColors.textPrimary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (_csvTextController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _clearCsvInput,
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvTextController,
              maxLines: 8,
              minLines: 5,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText:
                    'Paste or type CSV lines here...\nExample:\n308035123456, Juan, Protacio, Rizal, Jr., Male, 2008-06-19, Yes\n308035654321, Maria, Clara, Santos, , Female, 2009-11-23, No',
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : Colors.grey.shade400,
                ),
                filled: true,
                fillColor:
                    isDark ? AppColors.darkSurface2 : const Color(0xFFFAFAFA),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1.8,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_hasParsedCsv) {
                  setState(() => _hasParsedCsv = false);
                } else {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _csvTextController.text.trim().isEmpty
                      ? null
                      : _parseCsvInput,
                  icon: const Icon(Icons.table_view_rounded, size: 18),
                  label: const Text(
                    'Parse & Preview Students',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark
                        ? AppColors.darkSurface2
                        : Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                if (_hasParsedCsv) ...[
                  const Icon(Icons.check_circle_outline,
                      size: 18, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Parsed ${_parsedStudentRows.length} row(s)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCsvValidationTable(bool isDark) {
    final validRows = _parsedStudentRows.where((r) => r.isValid).toList();
    final errorRows = _parsedStudentRows.where((r) => !r.isValid).toList();
    final validCount = validRows.length;
    final errorCount = errorRows.length;
    final cardBg = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface2
                  : const Color(0xFFF8F9FA),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 20,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 10),
                Text(
                  'Validation Table & Live Preview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                // Pill badges
                _buildSummaryPill(
                  label: 'Total: ${_parsedStudentRows.length}',
                  color: Colors.blueGrey,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildSummaryPill(
                  label: 'Valid: $validCount',
                  color: AppColors.primaryGreen,
                  isDark: isDark,
                ),
                if (errorCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildSummaryPill(
                    label: 'Errors: $errorCount',
                    color: AppColors.error,
                    isDark: isDark,
                  ),
                ],
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _parsedStudentRows.clear();
                      _hasParsedCsv = false;
                    });
                  },
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss Preview',
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),

          if (errorCount > 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$errorCount row(s) contain validation errors and cannot be imported until corrected. You can delete problematic rows using the trash icon.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            isDark ? Colors.red.shade200 : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_parsedStudentRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No rows found in CSV input.',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 58,
                horizontalMargin: 16,
                columnSpacing: 18,
                headingTextStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('LRN')),
                  DataColumn(label: Text('Student Name')),
                  DataColumn(label: Text('Sex')),
                  DataColumn(label: Text('Birth Date')),
                  DataColumn(label: Text('4Ps')),
                  DataColumn(label: Text('Validation Details')),
                  DataColumn(label: Text('Action')),
                ],
                rows: List.generate(_parsedStudentRows.length, (i) {
                  final row = _parsedStudentRows[i];
                  final isValid = row.isValid;
                  final rowColor = isValid
                      ? Colors.transparent
                      : AppColors.error.withValues(alpha: isDark ? 0.08 : 0.04);

                  return DataRow(
                    color: WidgetStateProperty.all(rowColor),
                    cells: [
                      DataCell(
                        Text(
                          '${row.rowIndex}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isValid
                                    ? AppColors.primaryGreen
                                    : AppColors.error)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isValid
                                      ? AppColors.primaryGreen
                                      : AppColors.error)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isValid
                                    ? Icons.check_circle_rounded
                                    : Icons.error_rounded,
                                size: 12,
                                color: isValid
                                    ? AppColors.primaryGreen
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isValid ? 'VALID' : 'ERROR',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isValid
                                      ? AppColors.primaryGreen
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.lrn.isNotEmpty ? row.lrn : '—',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: row.lrn.length == 12
                                ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary)
                                : AppColors.error,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.fullName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.sex.isNotEmpty ? row.sex : '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: (row.sex == 'Male' || row.sex == 'Female')
                                ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary)
                                : AppColors.error,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.dob.isNotEmpty ? row.dob : '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: row.is4ps
                                ? AppColors.primaryGreen
                                    .withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            row.is4ps ? 'Yes' : 'No',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: row.is4ps
                                  ? AppColors.primaryGreen
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: isValid
                              ? Row(
                                  children: [
                                    const Icon(Icons.check,
                                        size: 14,
                                        color: AppColors.primaryGreen),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Ready for review',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.primaryGreen,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  row.errors.join(' • '),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _parsedStudentRows.removeAt(i);
                            });
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppColors.error,
                          tooltip: 'Remove row',
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),

          // Bottom action banner inside table
          if (validCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(
                  top: BorderSide(
                    color: AppColors.primaryGreen.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$validCount student record(s) ready to queue',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Proceed to Step 2 to configure Academic Year, Grade, Section, and finalize import.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _applyValidCsvRowsToQueue,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      'Proceed to Review ($validCount Students)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildSummaryPill({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
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
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final doneItems = _items.where((i) => i.status == _FileStatus.done).toList();

    return Column(children: [
      _buildSharedEnrollmentPicker(academicYearsAsync, gradeLevelsAsync, sectionsAsync),
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
    AsyncValue<List<GradeLevelModel>> gradeLevelsAsync,
    AsyncValue<List<SectionModel>> sectionsAsync,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (academicYearsAsync.isLoading ||
        gradeLevelsAsync.isLoading ||
        sectionsAsync.isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: isDark ? AppColors.primaryGreen.withValues(alpha: 0.12) : const Color(0xFFF0FAF4),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    final years = academicYearsAsync.value ?? [];
    final allGrades =
        List<GradeLevelModel>.from(gradeLevelsAsync.value ?? [])
          ..sort((a, b) => a.level.compareTo(b.level));
    final allSections = sectionsAsync.value ?? [];

    // 1. Determine active/effective Academic Year
    final activeYears =
        years.where((y) => y.status.toLowerCase() == 'active').toList();
    final defaultYearId = (activeYears.isNotEmpty
        ? activeYears.last
        : (years.isNotEmpty ? years.last : null))?.id;

    final effectiveYearId = _sharedAcademicYearId != null &&
            years.any((y) => y.id == _sharedAcademicYearId)
        ? _sharedAcademicYearId
        : defaultYearId;

    if (_sharedAcademicYearId != effectiveYearId && effectiveYearId != null) {
      _sharedAcademicYearId = effectiveYearId;
      for (final item in _items) {
        item.academicYearId = effectiveYearId;
      }
    }

    // 2. Determine available Grade Levels for the selected Academic Year based on sections in DB
    final sectionsInYear = effectiveYearId != null
        ? allSections.where((s) => s.academicYearId == effectiveYearId).toList()
        : <SectionModel>[];

    List<GradeLevelModel> availableGrades;
    if (sectionsInYear.isNotEmpty) {
      final gradesInYear = sectionsInYear.map((s) => s.gradeLevel).toSet();
      availableGrades =
          allGrades.where((g) => gradesInYear.contains(g.level)).toList();
      if (availableGrades.isEmpty) {
        availableGrades = allGrades;
      }
    } else {
      availableGrades = allGrades;
    }

    // 3. Determine effective Grade Level
    int? effectiveGradeLevel;
    if (_sharedGradeLevel != null &&
        availableGrades.any((g) => g.level == _sharedGradeLevel)) {
      effectiveGradeLevel = _sharedGradeLevel;
    } else {
      effectiveGradeLevel = availableGrades.any((g) => g.level == 7)
          ? 7
          : (availableGrades.isNotEmpty ? availableGrades.first.level : null);
      _sharedGradeLevel = effectiveGradeLevel;
      for (final item in _items) {
        item.gradeLevel = effectiveGradeLevel;
      }
    }

    // 4. Determine available Sections for (effectiveYearId, effectiveGradeLevel)
    final filteredSections =
        (effectiveYearId != null && effectiveGradeLevel != null)
            ? allSections
                .where((sec) =>
                    sec.academicYearId == effectiveYearId &&
                    sec.gradeLevel == effectiveGradeLevel)
                .toList()
            : <SectionModel>[];
    filteredSections.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    // 5. Determine effective Section
    int? effectiveSectionId;
    if (_sharedSectionId != null &&
        filteredSections.any((s) => s.id == _sharedSectionId)) {
      effectiveSectionId = _sharedSectionId;
    } else {
      effectiveSectionId = null;
      _sharedSectionId = null;
      for (final item in _items) {
        item.sectionId = null;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? AppColors.primaryGreen.withValues(alpha: 0.12) : const Color(0xFFF0FAF4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          const Text('Apply enrollment to all rows:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primaryGreen)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16, color: AppColors.primaryGreen),
            tooltip: 'Refresh Sections & Academic Years',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              ref.invalidate(academicYearsListProvider);
              ref.invalidate(gradeLevelsListProvider);
              ref.invalidate(sectionsListProvider);
            },
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          // Academic Year
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int>(
              key: ValueKey('bulk_academic_year_$effectiveYearId'),
              initialValue: effectiveYearId,
              isExpanded: true,
              decoration: _compactDeco(context, 'Academic Year'),
              items: years
                  .map((y) => DropdownMenuItem<int>(
                      value: y.id, child: Text(y.yearRange)))
                  .toList(),
              onChanged: (val) {
                ref.invalidate(academicYearsListProvider);
                ref.invalidate(sectionsListProvider);
                ref.invalidate(gradeLevelsListProvider);
                setState(() {
                  _sharedAcademicYearId = val;
                  final yearSecs = val != null
                      ? allSections.where((s) => s.academicYearId == val).toList()
                      : <SectionModel>[];
                  final validGrades = yearSecs.isNotEmpty
                      ? allGrades
                          .where((g) => yearSecs.any((s) => s.gradeLevel == g.level))
                          .toList()
                      : allGrades;
                  if (!validGrades.any((g) => g.level == _sharedGradeLevel)) {
                    _sharedGradeLevel = validGrades.any((g) => g.level == 7)
                        ? 7
                        : (validGrades.isNotEmpty ? validGrades.first.level : null);
                  }
                  _sharedSectionId = null;
                  if (_sharedGradeLevel != null && _sharedGradeLevel! < 11) {
                    _sharedTrackStrand = null;
                  }
                  for (final item in _items) {
                    item.academicYearId = val;
                    item.gradeLevel = _sharedGradeLevel;
                    item.sectionId = null;
                    item.trackStrand = _sharedTrackStrand;
                  }
                });
              },
            ),
          ),

          // Grade Level
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              key: ValueKey('bulk_grade_level_${effectiveYearId}_$effectiveGradeLevel'),
              initialValue: effectiveGradeLevel,
              isExpanded: true,
              decoration: _compactDeco(context, 'Grade Level'),
              items: availableGrades
                  .map((g) => DropdownMenuItem<int>(
                      value: g.level, child: Text(g.name)))
                  .toList(),
              onChanged: (val) => setState(() {
                _sharedGradeLevel = val;
                _sharedSectionId = null;
                if (val != null && val < 11) {
                  _sharedTrackStrand = null;
                }
                for (final item in _items) {
                  item.gradeLevel = val;
                  item.sectionId = null;
                  item.trackStrand = _sharedTrackStrand;
                }
              }),
            ),
          ),

          // Section
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int>(
              key: ValueKey('bulk_section_${effectiveYearId}_${effectiveGradeLevel}_$effectiveSectionId'),
              initialValue: effectiveSectionId,
              isExpanded: true,
              decoration: _compactDeco(
                context,
                filteredSections.isEmpty ? 'No sections available' : 'Section',
              ),
              items: filteredSections
                  .map((s) =>
                      DropdownMenuItem<int>(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: filteredSections.isEmpty
                  ? null
                  : (val) => setState(() {
                      _sharedSectionId = val;
                      for (final item in _items) {
                        item.sectionId = val;
                      }
                    }),
            ),
          ),

          // Track & Strand for Senior High School (Grade 11 & 12)
          if (effectiveGradeLevel != null && effectiveGradeLevel >= 11)
            SizedBox(
              width: 220,
              child: TextFormField(
                key: ValueKey('bulk_track_strand_$effectiveGradeLevel'),
                initialValue: _sharedTrackStrand,
                decoration: _compactDeco(context, 'Track & Strand (SHS)'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                onChanged: (val) => setState(() {
                  _sharedTrackStrand = val.trim().isEmpty ? null : val.trim();
                  for (final item in _items) {
                    item.trackStrand = _sharedTrackStrand;
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
      separatorBuilder: (_, unused) => const SizedBox(height: 10),
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
          _editLrnField(item),
          _editField('Last Name', item.lastName, (v) => item.lastName = v,
              width: 160, toUpperCase: true),
          _editField('First Name', item.firstName,
              (v) => item.firstName = v, width: 160, toUpperCase: true),
          _editField('Middle Name', item.middleName,
              (v) => item.middleName = v, width: 140, toUpperCase: true),
          _editField('Extension', item.extension,
              (v) => item.extension = v, width: 90, toUpperCase: true),
          _sexDropdown(item),
          _editDobField(item),
          _is4psCheckbox(item),
        ],
      );

  Widget _editLrnField(_OcrItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 160,
      child: TextFormField(
        initialValue: item.lrn.isNotEmpty ? item.lrn : '308035',
        keyboardType: TextInputType.number,
        maxLength: 12,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'LRN',
          hintText: '12-digit number',
          counterText: '',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F9FA),
        ),
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        onChanged: (v) {
          setState(() {
            item.lrn = v.trim();
          });
        },
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

  Widget _editDobField(_OcrItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Convert any existing 'YYYY-MM-DD' or parsed date to 'MM-DD-YYYY' for display
    String initialDisplay = '';
    if (item.dob.isNotEmpty) {
      final parsed = _parseFlexibleDob(item.dob);
      if (parsed != null) {
        initialDisplay =
            '${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}-${parsed.year.toString().padLeft(4, '0')}';
      } else {
        initialDisplay = item.dob;
      }
    }

    return SizedBox(
      width: 140,
      child: TextFormField(
        initialValue: initialDisplay,
        keyboardType: TextInputType.number,
        inputFormatters: [DobInputFormatter()],
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          hintText: 'MM-DD-YYYY',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: isDark ? AppColors.darkSurface2 : const Color(0xFFF8F9FA),
        ),
        style: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        onChanged: (v) {
          final parsed = _parseFlexibleDob(v);
          if (parsed != null) {
            item.dob =
                '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
          } else {
            item.dob = v.trim();
          }
        },
      ),
    );
  }

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
          separatorBuilder: (_, unused) => const SizedBox(height: 6),
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

        // Step 0 — Process All (Files) or Proceed to Review (CSV)
        if (_step == 0) ...[
          if (_activeInputTab == 0 &&
              _items.where((i) => !i.filePath.startsWith('csv_row_')).isNotEmpty)
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
                  : 'Process All (${_items.where((i) => !i.filePath.startsWith('csv_row_')).length})'),
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
          if (_activeInputTab == 1 &&
              _parsedStudentRows.any((r) => r.isValid))
            ElevatedButton.icon(
              onPressed: _applyValidCsvRowsToQueue,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(
                  'Proceed to Review (${_parsedStudentRows.where((r) => r.isValid).length})'),
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
