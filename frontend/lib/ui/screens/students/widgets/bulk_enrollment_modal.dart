import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/widgets/app_button_loader.dart';

class BulkEnrollmentModal extends ConsumerStatefulWidget {
  const BulkEnrollmentModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BulkEnrollmentModal(),
    );
  }

  @override
  ConsumerState<BulkEnrollmentModal> createState() => _BulkEnrollmentModalState();
}

class _BulkEnrollmentModalState extends ConsumerState<BulkEnrollmentModal> {
  final TextEditingController _csvTextController = TextEditingController();

  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;

  int _inputTab = 0; // 0: Type / Paste CSV, 1: Upload File
  String? _pickedFileName;
  bool _isVerifying = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _verifiedStudents = [];
  bool _hasAttemptedVerification = false;

  static const String _sampleCsvTemplate =
      'LRN\n'
      '308035123456\n'
      '308035654321\n'
      '308035987654\n'
      '308035112233';

  @override
  void dispose() {
    _csvTextController.dispose();
    super.dispose();
  }

  void _loadSampleData() {
    setState(() {
      _csvTextController.text = _sampleCsvTemplate;
      _pickedFileName = null;
      _verifiedStudents.clear();
      _hasAttemptedVerification = false;
    });
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
      _verifiedStudents.clear();
      _hasAttemptedVerification = false;
    });
  }

  List<String> _extractLrnsFromText(String csvString) {
    final lines = csvString
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    final List<String> rawTokens = [];
    final firstLine = lines.first.toLowerCase();

    int lrnIndex = -1;
    final headers = firstLine.split(',');
    for (int i = 0; i < headers.length; i++) {
      if (headers[i].contains('lrn')) {
        lrnIndex = i;
        break;
      }
    }

    final dataLines = lrnIndex != -1 ? lines.sublist(1) : lines;
    for (final line in dataLines) {
      final cols = line.split(',');
      if (lrnIndex != -1 && cols.length > lrnIndex) {
        rawTokens.add(cols[lrnIndex].trim());
      } else {
        if (cols.isNotEmpty) rawTokens.add(cols[0].trim());
      }
    }

    final Set<String> matched = {};
    for (final token in rawTokens) {
      final clean = token.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.length == 12) {
        matched.add(clean);
      }
    }

    return matched.toList();
  }

  Future<void> _verifyFromText(String text) async {
    final lrns = _extractLrnsFromText(text);
    if (lrns.isEmpty) {
      showErrorDialog(
        context,
        'No Valid LRNs Found',
        'No 12-digit LRNs were detected. Please ensure your format matches the sample template (e.g. one 12-digit LRN per line).',
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final repo = ref.read(studentRepositoryProvider);
      final verified = await repo.verifyLrns(lrns);

      if (!mounted) return;
      setState(() {
        _verifiedStudents = verified;
        _hasAttemptedVerification = true;
        _isVerifying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      showErrorDialog(context, 'Verification Failed', msg);
    }
  }

  Future<void> _pickAndVerifyCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final csvString = utf8.decode(bytes);
      setState(() {
        _pickedFileName = result.files.first.name;
        _csvTextController.text = csvString;
      });

      await _verifyFromText(csvString);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'File Read Error', e.toString());
    }
  }

  Future<void> _submitEnrollment() async {
    if (_selectedAcademicYearId == null ||
        _selectedGradeLevel == null ||
        _selectedSectionId == null) {
      showErrorDialog(
        context,
        'Missing Target Section',
        'Please select Academic Year, Grade Level, and Section before enrolling students.',
      );
      return;
    }

    final validIds = _verifiedStudents
        .where((s) => s['found'] == true && s['studentId'] != null)
        .map((s) => s['studentId'] as int)
        .toList();

    if (validIds.isEmpty) {
      showErrorDialog(
        context,
        'No Valid Students',
        'There are no verified students to enroll. Please verify your LRN list first.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.bulkEnrollStudents(
        studentIds: validIds,
        academicYearId: _selectedAcademicYearId!,
        gradeLevel: _selectedGradeLevel!,
        sectionId: _selectedSectionId!,
        trackStrand: _trackStrand?.trim().isEmpty == true ? null : _trackStrand?.trim(),
      );

      if (!mounted) return;
      ref.invalidate(studentPageProvider);
      await showSuccessDialog(
        context,
        message: 'Successfully enrolled ${validIds.length} student(s)!',
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      showErrorDialog(context, 'Bulk Enrollment Failed', msg);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 600;

    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradesAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    final validCount = _verifiedStudents.where((s) => s['found'] == true).length;
    final invalidCount = _verifiedStudents.length - validCount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.94 : 0.90),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: isMobile ? 12 : 14,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bulk CSV Enrollment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 15 : 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 14),
                          if (!isMobile) ...[
                            const SizedBox(width: 4),
                            const Text(
                              'Admin Only',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtitle
                      Text(
                        'Enroll multiple existing students at once by entering their LRNs or uploading a CSV file. The system verifies student records live with the backend before completing enrollment.',
                        style: TextStyle(
                          fontSize: isMobile ? 11.5 : 12.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section Header
                      Text(
                        '1. TARGET SECTION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Academic Year & Grade Level (Responsive layout)
                      if (isMobile) ...[
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Academic Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          initialValue: _selectedAcademicYearId,
                          isExpanded: true,
                          items: yearsAsync.maybeWhen(
                            data: (years) => years
                                .map((y) => DropdownMenuItem(
                                      value: y.id,
                                      child: Text(y.yearRange, style: const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            orElse: () => [],
                          ),
                          onChanged: (val) => setState(() => _selectedAcademicYearId = val),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Grade Level',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          initialValue: _selectedGradeLevel,
                          isExpanded: true,
                          items: gradesAsync.maybeWhen(
                            data: (grades) => grades
                                .map((g) => DropdownMenuItem(
                                      value: g.level,
                                      child: Text(g.name, style: const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            orElse: () => [],
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedGradeLevel = val;
                              _selectedSectionId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          initialValue: _selectedSectionId,
                          isExpanded: true,
                          items: sectionsAsync.maybeWhen(
                            data: (sections) {
                              if (_selectedGradeLevel != null) {
                                sections = sections
                                    .where((s) => s.gradeLevel == _selectedGradeLevel)
                                    .toList();
                              }
                              return sections
                                  .map((s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.name, style: const TextStyle(fontSize: 13)),
                                      ))
                                  .toList();
                            },
                            orElse: () => [],
                          ),
                          onChanged: (val) => setState(() => _selectedSectionId = val),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Track / Strand (Optional)',
                            hintText: 'e.g. STEM, TVL',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (val) => _trackStrand = val,
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Academic Year',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                initialValue: _selectedAcademicYearId,
                                isExpanded: true,
                                items: yearsAsync.maybeWhen(
                                  data: (years) => years
                                      .map((y) => DropdownMenuItem(
                                            value: y.id,
                                            child: Text(y.yearRange, style: const TextStyle(fontSize: 13)),
                                          ))
                                      .toList(),
                                  orElse: () => [],
                                ),
                                onChanged: (val) => setState(() => _selectedAcademicYearId = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Grade Level',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                initialValue: _selectedGradeLevel,
                                isExpanded: true,
                                items: gradesAsync.maybeWhen(
                                  data: (grades) => grades
                                      .map((g) => DropdownMenuItem(
                                            value: g.level,
                                            child: Text(g.name, style: const TextStyle(fontSize: 13)),
                                          ))
                                      .toList(),
                                  orElse: () => [],
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedGradeLevel = val;
                                    _selectedSectionId = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Section',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                initialValue: _selectedSectionId,
                                isExpanded: true,
                                items: sectionsAsync.maybeWhen(
                                  data: (sections) {
                                    if (_selectedGradeLevel != null) {
                                      sections = sections
                                          .where((s) => s.gradeLevel == _selectedGradeLevel)
                                          .toList();
                                    }
                                    return sections
                                        .map((s) => DropdownMenuItem(
                                              value: s.id,
                                              child: Text(s.name, style: const TextStyle(fontSize: 13)),
                                            ))
                                        .toList();
                                  },
                                  orElse: () => [],
                                ),
                                onChanged: (val) => setState(() => _selectedSectionId = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Track / Strand (Optional)',
                                  hintText: 'e.g. STEM, TVL',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                onChanged: (val) => _trackStrand = val,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Input Method Tabs
                      if (isMobile) ...[
                        Text(
                          '2. STUDENT LRNS (CSV INPUT)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _inputTab = 0),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _inputTab == 0
                                          ? AppColors.primaryGreen
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Type / Paste CSV',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _inputTab == 0
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _inputTab = 1),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _inputTab == 1
                                          ? AppColors.primaryGreen
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Upload CSV File',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _inputTab == 1
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '2. STUDENT LRNS (CSV INPUT)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            // Toggle pill
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => setState(() => _inputTab = 0),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _inputTab == 0
                                            ? AppColors.primaryGreen
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        'Type / Paste CSV',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _inputTab == 0
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _inputTab = 1),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _inputTab == 1
                                          ? AppColors.primaryGreen
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      'Upload CSV File',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _inputTab == 1
                                            ? Colors.white
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),

                      // Sample CSV Reference & Actions
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface2 : const Color(0xFFF4FBF7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.primaryGreen.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.info_outline_rounded,
                                        size: 16, color: AppColors.primaryGreen),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Sample Format Reference:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _loadSampleData,
                                      icon: const Icon(Icons.flash_on_rounded, size: 13),
                                      label: const Text('Fill Example', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryGreen,
                                        side: BorderSide(
                                          color: AppColors.primaryGreen.withValues(alpha: 0.4),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: _copyTemplate,
                                      icon: const Icon(Icons.copy_rounded, size: 13),
                                      label: const Text('Copy Template', style: TextStyle(fontSize: 11)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              child: SelectableText(
                                _sampleCsvTemplate,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.4,
                                  color: isDark ? Colors.green.shade300 : const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Text input or Upload file view
                      if (_inputTab == 0) ...[
                        TextFormField(
                          controller: _csvTextController,
                          maxLines: 6,
                          minLines: 4,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type or paste student LRNs here...\ne.g.\nLRN\n308035123456\n308035654321\n308035987654',
                            hintStyle: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                            ),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.all(12),
                            helperText: 'One 12-digit LRN per line, or comma-separated CSV with an LRN header.',
                            helperStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.upload_file_rounded,
                                size: 36,
                                color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _pickedFileName ?? 'Select a CSV file from your device',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _isVerifying ? null : _pickAndVerifyCsv,
                                icon: const Icon(Icons.folder_open, size: 16),
                                label: const Text('Choose CSV File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Verification Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isVerifying
                              ? null
                              : () => _verifyFromText(_csvTextController.text),
                          icon: _isVerifying
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                )
                              : const Icon(Icons.verified_outlined, size: 18),
                          label: Text(
                            _isVerifying
                                ? 'Verifying with Backend...'
                                : 'Verify LRNs with Backend',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      // Live Verification Results Panel
                      if (_hasAttemptedVerification) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    'Live Backend Verification:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$validCount Valid',
                                          style: const TextStyle(
                                            color: AppColors.primaryGreen,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (invalidCount > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$invalidCount Invalid',
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black26 : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                                  ),
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: _verifiedStudents.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                                  ),
                                  itemBuilder: (context, index) {
                                    final student = _verifiedStudents[index];
                                    final found = student['found'] == true;
                                    final name = found
                                        ? '${student['lastName'] ?? ''}, ${student['firstName'] ?? ''}'
                                        : 'Not found in database';
                                    final status = student['status'] != null
                                        ? ' · Status: ${student['status']}'
                                        : '';

                                    return ListTile(
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      leading: Icon(
                                        found ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                        color: found ? AppColors.primaryGreen : AppColors.error,
                                        size: 18,
                                      ),
                                      title: Text(
                                        student['lrn'] ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '$name$status',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: found
                                              ? (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                                              : AppColors.error,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Modal Footer
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: isMobile
                    ? Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (_isSubmitting ||
                                      validCount == 0 ||
                                      _selectedAcademicYearId == null ||
                                      _selectedGradeLevel == null ||
                                      _selectedSectionId == null)
                                  ? null
                                  : _submitEnrollment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isSubmitting
                                  ? const AppButtonLoader(
                                      color: Colors.white,
                                      size: 16,
                                      strokeWidth: 2,
                                    )
                                  : Text(
                                      validCount > 0
                                          ? 'Enroll $validCount Student(s)'
                                          : 'Enroll Students',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (_isSubmitting ||
                                    validCount == 0 ||
                                    _selectedAcademicYearId == null ||
                                    _selectedGradeLevel == null ||
                                    _selectedSectionId == null)
                                ? null
                                : _submitEnrollment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: _isSubmitting
                                ? const AppButtonLoader(
                                    color: Colors.white,
                                    size: 16,
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    validCount > 0
                                        ? 'Enroll $validCount Student(s)'
                                        : 'Enroll Students',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
