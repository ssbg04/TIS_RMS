import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../providers/setup_provider.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/modals/custom_modal.dart';

const List<int> _kValidGradeLevels = [7, 8, 9, 10, 11, 12];

class _ParsedAcademicRow {
  final int rowIndex;
  final String academicYear;
  final int gradeLevel;
  final String sectionName;
  final bool isNewYear;
  final bool isDuplicate;
  final List<String> errors;

  bool get isValid => errors.isEmpty && !isDuplicate;

  _ParsedAcademicRow({
    required this.rowIndex,
    required this.academicYear,
    required this.gradeLevel,
    required this.sectionName,
    required this.isNewYear,
    required this.isDuplicate,
    required this.errors,
  });
}

class BulkAcademicImportModal extends ConsumerStatefulWidget {
  const BulkAcademicImportModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const BulkAcademicImportModal(),
    );
  }

  @override
  ConsumerState<BulkAcademicImportModal> createState() =>
      _BulkAcademicImportModalState();
}

class _BulkAcademicImportModalState
    extends ConsumerState<BulkAcademicImportModal> {
  final TextEditingController _textController = TextEditingController();
  List<_ParsedAcademicRow> _parsedRows = [];
  bool _hasParsed = false;
  bool _isSubmitting = false;

  static const String _templateCsv =
      'Academic Year,Grade Level,Section Name\n'
      '2024-2025,7,Rizal\n'
      '2024-2025,7,Bonifacio\n'
      '2024-2025,8,Mabini\n'
      '2024-2025,9,Emerald\n'
      '2024-2025,10,Diamond\n'
      '2024-2025,11,STEM 1\n'
      '2024-2025,12,HUMSS 1';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _copyTemplate() {
    Clipboard.setData(const ClipboardData(text: _templateCsv));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV example template copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        setState(() {
          _textController.text = content;
        });
        _parseInput();
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'File Error', 'Failed to read CSV file: $e');
      }
    }
  }

  void _parseInput() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedRows = [];
        _hasParsed = false;
      });
      return;
    }

    final existingYears = ref.read(academicYearsListProvider).value ?? [];
    final existingSections = ref.read(sectionsListProvider).value ?? [];

    final lines = const LineSplitter().convert(text);
    final List<_ParsedAcademicRow> rows = [];
    final currentYear = DateTime.now().year;
    final regex = RegExp(r'^(\d{4})\s*-\s*(\d{4})$');

    // Track rows inside this batch to detect intra-batch duplicates
    final Set<String> batchKeys = {};

    int rowCounter = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Handle comma, tab, or semicolon
      List<String> parts;
      if (line.contains('\t')) {
        parts = line.split('\t').map((p) => p.trim()).toList();
      } else if (line.contains(';')) {
        parts = line.split(';').map((p) => p.trim()).toList();
      } else {
        parts = line.split(',').map((p) => p.trim()).toList();
      }

      // Check header line
      final lower0 = parts.isNotEmpty ? parts[0].toLowerCase() : '';
      if (i == 0 &&
          (lower0.contains('academic') ||
              lower0.contains('year') ||
              lower0.contains('grade') ||
              lower0.contains('section'))) {
        continue;
      }

      rowCounter++;
      final List<String> errors = [];

      final rawYear = parts.isNotEmpty ? parts[0] : '';
      final rawGradeStr = parts.length > 1 ? parts[1] : '';
      final rawSection = parts.length > 2 ? parts[2] : '';

      String academicYear = rawYear;
      int gradeLevel = 0;
      String sectionName = rawSection;

      // Validate Academic Year
      final yearMatch = regex.firstMatch(rawYear);
      if (yearMatch == null) {
        errors.add('Year must be YYYY-YYYY (e.g. 2024-2025)');
      } else {
        final startY = int.tryParse(yearMatch.group(1)!) ?? 0;
        final endY = int.tryParse(yearMatch.group(2)!) ?? 0;
        if (endY != startY + 1) {
          errors.add('End year must be start + 1');
        } else if (startY > currentYear) {
          errors.add('Cannot exceed current year ($currentYear-${currentYear + 1})');
        } else {
          academicYear = '$startY-$endY';
        }
      }

      // Validate Grade Level
      final parsedGrade = int.tryParse(
        rawGradeStr.toLowerCase().replaceAll('grade', '').replaceAll('gr', '').trim(),
      );
      if (parsedGrade == null) {
        errors.add('Grade level must be numeric (7–12)');
      } else if (!_kValidGradeLevels.contains(parsedGrade)) {
        errors.add('Grade $parsedGrade is outside valid range (7–12)');
      } else {
        gradeLevel = parsedGrade;
      }

      // Validate Section Name
      if (sectionName.isEmpty) {
        errors.add('Section name cannot be empty');
      }

      // Check if Year is new
      final isNewYear = errors.isEmpty &&
          !existingYears.any((y) => y.yearRange == academicYear);

      // Check if Section already exists
      bool isDuplicate = false;
      if (errors.isEmpty) {
        final existingYear = existingYears.cast<AcademicYearModel?>().firstWhere(
              (y) => y?.yearRange == academicYear,
              orElse: () => null,
            );

        if (existingYear != null) {
          final alreadyExistsInDb = existingSections.any(
            (s) =>
                s.academicYearId == existingYear.id &&
                s.gradeLevel == gradeLevel &&
                s.name.toLowerCase() == sectionName.toLowerCase(),
          );
          if (alreadyExistsInDb) {
            isDuplicate = true;
          }
        }

        // Check intra-batch duplicate
        final batchKey = '$academicYear|$gradeLevel|${sectionName.toLowerCase()}';
        if (batchKeys.contains(batchKey)) {
          isDuplicate = true;
          errors.add('Duplicate section in CSV batch');
        } else {
          batchKeys.add(batchKey);
        }
      }

      rows.add(
        _ParsedAcademicRow(
          rowIndex: rowCounter,
          academicYear: academicYear,
          gradeLevel: gradeLevel,
          sectionName: sectionName,
          isNewYear: isNewYear,
          isDuplicate: isDuplicate,
          errors: errors,
        ),
      );
    }

    setState(() {
      _parsedRows = rows;
      _hasParsed = true;
    });
  }

  Future<void> _handleImport() async {
    final validRows = _parsedRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      showErrorDialog(
        context,
        'No Valid Sections',
        'There are no valid, non-duplicate sections to import. Please review the errors in the table.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = validRows
        .map((r) => {
              'academicYear': r.academicYear,
              'gradeLevel': r.gradeLevel,
              'sectionName': r.sectionName,
            })
        .toList();

    try {
      final result = await ref
          .read(setupMutationProvider.notifier)
          .bulkCreateAcademicStructure(payload);

      if (!mounted) return;

      final message = result['message']?.toString() ??
          'Successfully imported ${validRows.length} section(s)!';

      Navigator.of(context).pop();
      showSuccessDialog(
        context,
        title: 'Bulk Import Completed',
        message: message,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Import Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validCount = _parsedRows.where((r) => r.isValid).length;
    final errorCount = _parsedRows.where((r) => r.errors.isNotEmpty).length;
    final dupCount = _parsedRows.where((r) => r.isDuplicate && r.errors.isEmpty).length;
    final newYearCount = _parsedRows.where((r) => r.isNewYear && r.isValid).map((r) => r.academicYear).toSet().length;

    return CustomModal(
      title: 'Bulk Setup: Academic Years & Sections',
      icon: Icons.table_chart_rounded,
      maxWidth: 860,
      content: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;
          final isUltraNarrow = constraints.maxWidth < 430;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template guide
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isCompact ? 10 : 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryGreen.withValues(alpha: 0.1)
                          : const Color(0xFFF0FAF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 18,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isCompact
                                    ? 'CSV: Year, Grade, Section'
                                    : 'CSV Format: Academic Year, Grade Level, Section Name',
                                style: TextStyle(
                                  fontSize: isCompact ? 12 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.primaryGreen,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _copyTemplate,
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: Text(
                                isCompact ? 'Copy' : 'Copy Template',
                                style: TextStyle(fontSize: isCompact ? 11 : 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Provide 3 columns per row (comma, tab, or semicolon separated):\n'
                          '• Academic Year: YYYY-YYYY format (e.g. 2024-2025)\n'
                          '• Grade Level: 7, 8, 9, 10, 11, or 12\n'
                          '• Section Name: e.g. Rizal, Diamond, STEM 1\n'
                          '*Note: New academic years will be safely created as inactive.',
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            height: 1.4,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Controls row
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Input or Paste CSV Text:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickCsvFile,
                            icon: const Icon(Icons.file_upload_outlined, size: 14),
                            label: const Text('Browse File', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null && data!.text!.isNotEmpty) {
                                setState(() {
                                  _textController.text = data.text!;
                                });
                                _parseInput();
                              }
                            },
                            icon: const Icon(Icons.paste_rounded, size: 14),
                            label: const Text('Paste', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _textController.clear();
                              setState(() {
                                _parsedRows = [];
                                _hasParsed = false;
                              });
                            },
                            icon: const Icon(Icons.clear, size: 14),
                            label: const Text('Clear', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Text Area
                  TextField(
                    controller: _textController,
                    minLines: 4,
                    maxLines: 7,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paste or type CSV rows here...\n2024-2025, 7, Rizal\n2024-2025, 10, Diamond',
                      hintStyle: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) => _parseInput(),
                  ),
                  const SizedBox(height: 12),

                  // Parse & Status Bar
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _parseInput,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Parse & Preview', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      if (_hasParsed)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildStatusBadge(
                              label: '$validCount Valid',
                              color: AppColors.primaryGreen,
                            ),
                            if (newYearCount > 0)
                              _buildStatusBadge(
                                label: '$newYearCount New Year${newYearCount > 1 ? 's' : ''}',
                                color: Colors.blue,
                              ),
                            if (dupCount > 0)
                              _buildStatusBadge(
                                label: '$dupCount Duplicate${dupCount > 1 ? 's' : ''}',
                                color: Colors.orange,
                              ),
                            if (errorCount > 0)
                              _buildStatusBadge(
                                label: '$errorCount Error${errorCount > 1 ? 's' : ''}',
                                color: AppColors.error,
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Live Preview / Validation Table
                  if (_hasParsed) ...[
                    Row(
                      children: [
                        Text(
                          'Live Validation Preview (${_parsedRows.length} rows):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (!isCompact && _parsedRows.isNotEmpty)
                          Text(
                            'Scroll to view all',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                        ),
                      ),
                      child: _parsedRows.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No rows detected. Paste CSV rows above to view live preview.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            )
                          : isCompact
                              ? _buildMobilePreviewList(isDark)
                              : _buildDesktopPreviewTable(isDark),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Footer Actions
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (isUltraNarrow) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting || validCount == 0
                                ? null
                                : _handleImport,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, size: 16),
                            label: Text(
                              _isSubmitting
                                  ? 'Importing...'
                                  : 'Import $validCount Section${validCount == 1 ? '' : 's'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ] else ...[
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting || validCount == 0
                              ? null
                              : _handleImport,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: Text(
                            _isSubmitting
                                ? 'Importing...'
                                : 'Import $validCount Section${validCount == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopPreviewTable(bool isDark) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              ),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 44,
                child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 110,
                child: Text('Academic Year', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 85,
                child: Text('Grade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text('Section Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 3,
                child: Text('Status & Validation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        // Rows
        Expanded(
          child: ListView.separated(
            itemCount: _parsedRows.length,
            separatorBuilder: (_, unused) => Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),
            itemBuilder: (context, idx) {
              final row = _parsedRows[idx];
              Color statusColor;
              IconData statusIcon;
              String statusText;

              if (row.errors.isNotEmpty) {
                statusColor = AppColors.error;
                statusIcon = Icons.cancel_outlined;
                statusText = row.errors.join('; ');
              } else if (row.isDuplicate) {
                statusColor = Colors.orange;
                statusIcon = Icons.warning_amber_rounded;
                statusText = 'Already exists in database (skipped)';
              } else if (row.isNewYear) {
                statusColor = Colors.blue;
                statusIcon = Icons.add_circle_outline_rounded;
                statusText = 'Valid (will create new Academic Year)';
              } else {
                statusColor = AppColors.primaryGreen;
                statusIcon = Icons.check_circle_outline_rounded;
                statusText = 'Valid';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${row.rowIndex}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        row.academicYear,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 85,
                      child: Text(
                        row.gradeLevel > 0 ? 'Grade ${row.gradeLevel}' : '—',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.sectionName.isNotEmpty ? row.sectionName : '—',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePreviewList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _parsedRows.length,
      separatorBuilder: (_, unused) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final row = _parsedRows[idx];
        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (row.errors.isNotEmpty) {
          statusColor = AppColors.error;
          statusIcon = Icons.cancel_outlined;
          statusText = row.errors.join('; ');
        } else if (row.isDuplicate) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning_amber_rounded;
          statusText = 'Already exists in database (skipped)';
        } else if (row.isNewYear) {
          statusColor = Colors.blue;
          statusIcon = Icons.add_circle_outline_rounded;
          statusText = 'Valid (will create new Academic Year)';
        } else {
          statusColor = AppColors.primaryGreen;
          statusIcon = Icons.check_circle_outline_rounded;
          statusText = 'Valid';
        }

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: row.errors.isNotEmpty
                  ? AppColors.error.withValues(alpha: 0.3)
                  : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${row.rowIndex}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      row.academicYear,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (row.gradeLevel > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Grade ${row.gradeLevel}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Icon(statusIcon, color: statusColor, size: 16),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Section: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    row.sectionName.isNotEmpty ? row.sectionName : '—',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
}
