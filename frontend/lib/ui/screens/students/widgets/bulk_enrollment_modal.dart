import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';

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
  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;

  bool _isVerifying = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _verifiedStudents = [];
  bool _hasAttemptedVerification = false;

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
      final lines = csvString.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      if (lines.isEmpty) {
        if (mounted) showErrorDialog(context, 'Error', 'CSV file is empty.');
        return;
      }

      // Assume LRN is in the first column or there's a header.
      // Let's just aggressively find 12-digit numbers if no header, or extract column.
      List<String> lrns = [];
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
          lrns.add(cols[lrnIndex].trim());
        } else {
          // just grab the first column
          if (cols.isNotEmpty) lrns.add(cols[0].trim());
        }
      }

      lrns = lrns.where((l) => RegExp(r'^\d{12}$').hasMatch(l)).toList();
      if (lrns.isEmpty) {
        if (mounted) showErrorDialog(context, 'Error', 'No valid 12-digit LRNs found in the CSV.');
        return;
      }

      setState(() => _isVerifying = true);
      
      final repo = ref.read(studentRepositoryProvider);
      final verified = await repo.verifyLrns(lrns);
      
      setState(() {
        _verifiedStudents = verified;
        _hasAttemptedVerification = true;
        _isVerifying = false;
      });

    } catch (e) {
      setState(() => _isVerifying = false);
      if (mounted) showErrorDialog(context, 'Error', e.toString());
    }
  }

  Future<void> _submitEnrollment() async {
    if (_selectedAcademicYearId == null || _selectedGradeLevel == null || _selectedSectionId == null) {
      showErrorDialog(context, 'Error', 'Please select Academic Year, Grade Level, and Section.');
      return;
    }

    final validIds = _verifiedStudents
        .where((s) => s['found'] == true && s['studentId'] != null)
        .map((s) => s['studentId'] as int)
        .toList();

    if (validIds.isEmpty) {
      showErrorDialog(context, 'Error', 'No valid students to enroll.');
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
        trackStrand: _trackStrand,
      );
      
      if (mounted) {
        showSuccessDialog(context, message: 'Successfully enrolled ${validIds.length} students.');
        Navigator.pop(context);
        ref.invalidate(studentPageProvider);
      }
    } catch (e) {
      if (mounted) showErrorDialog(context, 'Error', e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradesAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    final validCount = _verifiedStudents.where((s) => s['found'] == true).length;
    final invalidCount = _verifiedStudents.length - validCount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bulk CSV Enrollment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload a CSV file containing student LRNs. The system will verify them and enroll valid students into the selected section.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Academic Year', border: OutlineInputBorder()),
                    initialValue: _selectedAcademicYearId,
                    items: yearsAsync.maybeWhen(
                      data: (years) => years.map((y) => DropdownMenuItem(value: y.id, child: Text(y.yearRange))).toList(),
                      orElse: () => [],
                    ),
                    onChanged: (val) => setState(() => _selectedAcademicYearId = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Grade Level', border: OutlineInputBorder()),
                    initialValue: _selectedGradeLevel,
                    items: gradesAsync.maybeWhen(
                      data: (grades) => grades.map((g) => DropdownMenuItem(value: g.level, child: Text(g.name))).toList(),
                      orElse: () => [],
                    ),
                    onChanged: (val) => setState(() => _selectedGradeLevel = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                    initialValue: _selectedSectionId,
                    items: sectionsAsync.maybeWhen(
                      data: (sections) {
                        if (_selectedGradeLevel != null) {
                          sections = sections.where((s) => s.gradeLevel == _selectedGradeLevel).toList();
                        }
                        return sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList();
                      },
                      orElse: () => [],
                    ),
                    onChanged: (val) => setState(() => _selectedSectionId = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Track/Strand (Optional)', border: OutlineInputBorder()),
                    onChanged: (val) => _trackStrand = val,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isVerifying ? null : _pickAndVerifyCsv,
              icon: _isVerifying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file),
              label: const Text('Select CSV & Verify'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                foregroundColor: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (_hasAttemptedVerification) ...[
              const SizedBox(height: 24),
              Text(
                'Verification Results: $validCount valid, $invalidCount invalid',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _verifiedStudents.length,
                  itemBuilder: (context, index) {
                    final student = _verifiedStudents[index];
                    final found = student['found'] == true;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        found ? Icons.check_circle : Icons.error,
                        color: found ? AppColors.primaryGreen : AppColors.error,
                      ),
                      title: Text(student['lrn'] ?? ''),
                      subtitle: Text(found ? '${student['lastName']}, ${student['firstName']} (${student['status']})' : 'Not found in database'),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: (_isSubmitting || validCount == 0 || _selectedAcademicYearId == null || _selectedGradeLevel == null || _selectedSectionId == null) 
                      ? null 
                      : _submitEnrollment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Enroll $validCount Students'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
