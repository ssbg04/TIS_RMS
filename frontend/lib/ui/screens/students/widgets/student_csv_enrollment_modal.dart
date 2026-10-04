import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/widgets/app_button_loader.dart';

class StudentCsvEnrollmentModal extends ConsumerStatefulWidget {
  final int studentId;
  final String studentName;
  final String studentLrn;

  const StudentCsvEnrollmentModal({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentLrn,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int studentId,
    required String studentName,
    required String studentLrn,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StudentCsvEnrollmentModal(
        studentId: studentId,
        studentName: studentName,
        studentLrn: studentLrn,
      ),
    );
  }

  @override
  ConsumerState<StudentCsvEnrollmentModal> createState() =>
      _StudentCsvEnrollmentModalState();
}

class _StudentCsvEnrollmentModalState
    extends ConsumerState<StudentCsvEnrollmentModal> {
  final TextEditingController _csvTextController = TextEditingController();

  int _inputTab = 0; // 0: Type / Paste CSV directly, 1: Upload File
  String? _pickedFileName;
  bool _isVerifying = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _verifiedRecords = [];
  bool _hasVerified = false;

  static const String _sampleCsvTemplate =
      'School Year, Grade Level, Section, Track/Strand\n'
      '2021-2022, 7, Diamond, \n'
      '2022-2023, 8, Emerald, \n'
      '2023-2024, 9, Ruby, \n'
      '2024-2025, 10, Sapphire, \n'
      '2025-2026, 11, TVL-A, TVL';

  @override
  void dispose() {
    _csvTextController.dispose();
    super.dispose();
  }

  void _loadSampleData() {
    setState(() {
      _csvTextController.text = _sampleCsvTemplate;
      _pickedFileName = null;
      _verifiedRecords.clear();
      _hasVerified = false;
    });
    _verifyProgression();
  }

  void _copyTemplate() {
    Clipboard.setData(const ClipboardData(text: _sampleCsvTemplate));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sample CSV format copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearInput() {
    setState(() {
      _csvTextController.clear();
      _pickedFileName = null;
      _verifiedRecords.clear();
      _hasVerified = false;
    });
  }

  List<Map<String, String>> _parseCsvInput(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    final firstLine = lines.first.toLowerCase();
    int startIndex = 0;
    if (firstLine.contains('year') ||
        firstLine.contains('grade') ||
        firstLine.contains('section') ||
        firstLine.contains('sy')) {
      startIndex = 1;
    }

    final List<Map<String, String>> result = [];
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final delimiter = line.contains('\t') ? '\t' : (line.contains(';') ? ';' : ',');
      final parts = line.split(delimiter).map((p) => p.trim()).toList();
      if (parts.isEmpty || (parts.length == 1 && parts[0].isEmpty)) continue;

      final schoolYear = parts.isNotEmpty ? parts[0] : '';
      final gradeLevel = parts.length > 1 ? parts[1] : '';
      final section = parts.length > 2 ? parts[2] : '';
      final trackStrand = parts.length > 3 ? parts[3] : '';

      result.add({
        'schoolYear': schoolYear,
        'gradeLevel': gradeLevel,
        'sectionName': section,
        'trackStrand': trackStrand,
      });
    }

    return result;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content = '';
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        }
        setState(() {
          _pickedFileName = file.name;
          _csvTextController.text = content;
          _inputTab = 0; // Return to editor so user can inspect and type
        });
        await _verifyProgression();
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'File Reading Error',
          'Failed to read file: $e',
        );
      }
    }
  }

  Future<void> _verifyProgression() async {
    final parsed = _parseCsvInput(_csvTextController.text);
    if (parsed.isEmpty) {
      setState(() {
        _verifiedRecords = [];
        _hasVerified = true;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _hasVerified = false;
    });

    try {
      final res = await ref.read(studentRepositoryProvider).verifyStudentEnrollments(
            studentId: widget.studentId,
            enrollments: parsed,
          );

      if (mounted) {
        final results = res['results'] as List? ?? [];
        setState(() {
          _verifiedRecords = results.map((r) => Map<String, dynamic>.from(r as Map)).toList();
          _hasVerified = true;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _hasVerified = true;
        });
        showErrorDialog(
          context,
          'Verification Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _submitEnrollments() async {
    final validRecords = _verifiedRecords.where((r) => r['isValid'] == true).toList();
    if (validRecords.isEmpty) {
      showErrorDialog(
        context,
        'No Valid Records',
        'There are no verified valid enrollment records to import. Please resolve the errors indicated below.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = validRecords.map((r) {
        return {
          'academicYearId': r['academicYearId'],
          'sectionId': r['sectionId'],
          'gradeLevel': r['parsedGradeLevel'],
          'trackStrand': r['trackStrand'],
        };
      }).toList();

      final res = await ref.read(studentRepositoryProvider).bulkAddStudentEnrollments(
            studentId: widget.studentId,
            enrollments: payload,
          );

      if (mounted) {
        setState(() => _isSubmitting = false);
        final count = res['count'] ?? validRecords.length;
        await showSuccessDialog(
          context,
          title: 'Enrollments Imported',
          message: 'Successfully imported $count enrollment record(s) for ${widget.studentName}.',
        );
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorDialog(
          context,
          'Import Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMobile = screenW < 650;

    final validCount = _verifiedRecords.where((r) => r['isValid'] == true).length;
    final errorCount = _verifiedRecords.where((r) => r['isValid'] == false).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: 820,
        constraints: BoxConstraints(
          maxHeight: screenH * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.playlist_add_check_rounded,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk CSV Enrollment for Student',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '1 Student Mode',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${widget.studentName} (LRN: ${widget.studentLrn})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tab Selector: Type/Paste vs Upload
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _inputTab = 0),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _inputTab == 0
                                      ? AppColors.primaryGreen
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: 16,
                                      color: _inputTab == 0
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Type / Paste CSV',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _inputTab == 0
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _inputTab = 1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _inputTab == 1
                                      ? AppColors.primaryGreen
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.upload_file_rounded,
                                      size: 16,
                                      color: _inputTab == 1
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Upload CSV File',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _inputTab == 1
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Sample CSV Reference Box with Direct Fill ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF4FBF7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.primaryGreen.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sample Format Reference (Directly Editable):',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _loadSampleData,
                                    icon: const Icon(Icons.flash_on_rounded, size: 13),
                                    label: const Text(
                                      'Fill Example',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primaryGreen,
                                      side: BorderSide(
                                        color: AppColors.primaryGreen.withValues(alpha: 0.4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _copyTemplate,
                                    icon: const Icon(Icons.copy_rounded, size: 13),
                                    label: const Text(
                                      'Copy Template',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  if (_csvTextController.text.isNotEmpty)
                                    IconButton(
                                      onPressed: _clearInput,
                                      icon: const Icon(Icons.close, size: 14),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Clear',
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.grey.shade300,
                              ),
                            ),
                            child: const SelectableText(
                              'School Year, Grade Level, Section, Track/Strand (Optional)\n'
                              'e.g. 2021-2022, 7, Diamond,',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.4,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input Field or Upload Area
                    if (_inputTab == 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CSV Input (Type or paste rows here):',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${_parseCsvInput(_csvTextController.text).length} record(s) detected',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _csvTextController,
                        maxLines: 7,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'School Year, Grade Level, Section, Track/Strand\n'
                              '2021-2022, 7, Diamond,\n'
                              '2022-2023, 8, Emerald,\n'
                              '2023-2024, 9, Ruby,\n'
                              '2024-2025, 10, Sapphire,',
                          hintStyle: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGreen,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (_hasVerified) {
                            setState(() => _hasVerified = false);
                          }
                        },
                      ),
                    ] else ...[
                      // Upload file area
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 42,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _pickedFileName != null
                                    ? 'Selected: $_pickedFileName'
                                    : 'Click to select CSV or TXT file from your computer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Supports comma, semicolon, or tab-delimited records',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Verification Trigger Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Backend Progression Verification:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isVerifying || _csvTextController.text.trim().isEmpty
                              ? null
                              : _verifyProgression,
                          icon: _isVerifying
                              ? const AppButtonLoader(
                                  color: Colors.white,
                                  size: 14,
                                  strokeWidth: 2,
                                )
                              : const Icon(Icons.verified_outlined, size: 16),
                          label: Text(_isVerifying ? 'Verifying...' : 'Verify Progression'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Verification Results Panel
                    if (_isVerifying)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Column(
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5),
                            SizedBox(height: 10),
                            Text(
                              'Checking progression & section validity with backend...',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else if (_hasVerified) ...[
                      // Summary status pill bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: errorCount > 0
                              ? (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50)
                              : (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: errorCount > 0
                                ? (isDark ? Colors.red.withValues(alpha: 0.4) : Colors.red.shade300)
                                : (isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              errorCount > 0
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: errorCount > 0 ? AppColors.error : AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorCount > 0
                                    ? '$validCount record(s) ready to enroll, $errorCount issue(s) detected.'
                                    : 'All $validCount record(s) passed backend verification and are ready to enroll!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: errorCount > 0
                                      ? AppColors.error
                                      : AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Verified Records List
                      if (_verifiedRecords.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'No records detected. Please enter CSV rows and verify.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _verifiedRecords.length,
                              separatorBuilder: (ctx, i) => Divider(
                                height: 1,
                                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                              ),
                              itemBuilder: (ctx, index) {
                                final item = _verifiedRecords[index];
                                final isValid = item['isValid'] == true;
                                final error = item['error'] as String?;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  color: isValid
                                      ? Colors.transparent
                                      : (isDark
                                          ? Colors.red.withValues(alpha: 0.08)
                                          : Colors.red.shade50.withValues(alpha: 0.6)),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.black26 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'S.Y. ${item['schoolYear'] ?? 'N/A'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Grade ${item['parsedGradeLevel'] ?? item['gradeLevel'] ?? 'N/A'}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Section: ${item['sectionName'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? AppColors.darkTextPrimary
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (item['trackStrand'] != null &&
                                                    item['trackStrand'].toString().isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '(${item['trackStrand']})',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (error != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                error,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.error,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isValid
                                              ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                              : AppColors.error.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isValid ? Icons.check_circle : Icons.cancel,
                                              size: 13,
                                              color: isValid
                                                  ? AppColors.primaryGreen
                                                  : AppColors.error,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isValid ? 'Valid' : 'Error',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isValid
                                                    ? AppColors.primaryGreen
                                                    : AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    validCount > 0
                        ? '$validCount valid enrollment(s) to import'
                        : '0 valid enrollments',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: (_isSubmitting || validCount == 0)
                            ? null
                            : _submitEnrollments,
                        icon: _isSubmitting
                            ? const AppButtonLoader(
                                color: Colors.white,
                                size: 14,
                                strokeWidth: 2,
                              )
                            : const Icon(Icons.playlist_add_check, size: 18),
                        label: Text(
                          _isSubmitting
                              ? 'Importing...'
                              : 'Import Enrollments ($validCount)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
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
