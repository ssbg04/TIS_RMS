import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../../domain/repositories/student_repository.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../shared/dialogs/error_dialog.dart';

/// Accepted enrollment chosen in add-student (prefill) mode.
class OcrEnrollmentPrefill {
  final int academicYearId;
  final int gradeLevel;
  final int? sectionId;
  final String sectionName;
  final String schoolYear;

  const OcrEnrollmentPrefill({
    required this.academicYearId,
    required this.gradeLevel,
    required this.sectionName,
    required this.schoolYear,
    this.sectionId,
  });
}

enum _ValidationMode { editStudent, addStudent }

class _Entry {
  final OcrEnrollmentRecord record;
  int? academicYearId;
  int gradeLevel;
  int? sectionId;

  _Entry({
    required this.record,
    required this.gradeLevel,
  });
}

class OcrEnrollmentValidationModal extends ConsumerStatefulWidget {
  final int? studentId;
  final List<OcrEnrollmentRecord> records;
  final _ValidationMode _mode;

  const OcrEnrollmentValidationModal._({
    super.key,
    this.studentId,
    required this.records,
    required _ValidationMode mode,
  }) : _mode = mode;

  /// Edit-student mode: accept writes the enrollment via the API.
  /// Returns the number of accepted enrollments.
  static Future<int> show(
    BuildContext context, {
    required int studentId,
    required List<OcrEnrollmentRecord> records,
  }) async {
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OcrEnrollmentValidationModal._(
        studentId: studentId,
        records: records,
        mode: _ValidationMode.editStudent,
      ),
    );
    return result ?? 0;
  }

  /// Add-student mode: no API writes. Returns the accepted, edited
  /// enrollments, or an empty list when the user rejects/closes without
  /// accepting anything.
  static Future<List<OcrEnrollmentPrefill>> showForAddStudent(
    BuildContext context, {
    required List<OcrEnrollmentRecord> records,
  }) async {
    final result = await showDialog<List<OcrEnrollmentPrefill>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => OcrEnrollmentValidationModal._(
        records: records,
        mode: _ValidationMode.addStudent,
      ),
    );
    return result ?? const [];
  }

  @override
  ConsumerState<OcrEnrollmentValidationModal> createState() =>
      _OcrEnrollmentValidationModalState();
}

class _OcrEnrollmentValidationModalState
    extends ConsumerState<OcrEnrollmentValidationModal> {
  late List<_Entry> _entries;
  int _acceptedCount = 0;
  final List<OcrEnrollmentPrefill> _acceptedPrefills = [];
  int? _acceptingIndex;

  bool get _isEditMode => widget._mode == _ValidationMode.editStudent;

  @override
  void initState() {
    super.initState();
    _entries = widget.records.map((r) {
      final gradeNum = int.tryParse(r.gradeLevel.replaceAll(RegExp(r'\D'), ''));
      return _Entry(
        record: r,
        gradeLevel: (gradeNum != null && gradeNum >= 7 && gradeNum <= 12)
            ? gradeNum
            : 7,
      );
    }).toList();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    try {
      final years = await ref.read(academicYearsListProvider.future);
      final sections = await ref.read(sectionsListProvider.future);
      if (!mounted) return;
      setState(() {
        for (final e in _entries) {
          e.academicYearId = _matchYear(years, e.record.schoolYear);
          e.sectionId = _matchSection(sections, e);
        }
      });
    } catch (_) {
      // Lists unavailable (e.g. teacher without sections) - leave manual.
    }
  }

  int? _matchYear(List<AcademicYearModel> years, String schoolYear) {
    final sy = schoolYear.trim();
    for (final y in years) {
      if (y.yearRange.toLowerCase() == sy.toLowerCase()) return y.id;
    }
    for (final y in years) {
      if (y.status.toLowerCase() == 'active') return y.id;
    }
    return years.isEmpty ? null : years.first.id;
  }

  int? _matchSection(List<SectionModel> sections, _Entry entry) {
    final name = entry.record.section.trim().toLowerCase();
    for (final s in sections) {
      final yearOk = s.academicYearId == null ||
          entry.academicYearId == null ||
          s.academicYearId == entry.academicYearId;
      if (s.gradeLevel == entry.gradeLevel &&
          yearOk &&
          s.name.trim().toLowerCase() == name) {
        return s.id;
      }
    }
    return null;
  }

  List<SectionModel> _sectionsForEntry(
    List<SectionModel> allSections,
    _Entry entry,
  ) {
    return allSections
        .where((s) =>
            s.gradeLevel == entry.gradeLevel &&
            (s.academicYearId == null ||
                entry.academicYearId == null ||
                s.academicYearId == entry.academicYearId))
        .toList();
  }

  Future<void> _accept(int index) async {
    final entry = _entries[index];
    if (entry.academicYearId == null || entry.sectionId == null) {
      showErrorDialog(
        context,
        'Incomplete',
        'Select Academic Year and Section before accepting.',
      );
      return;
    }

    if (!_isEditMode) {
      final years = ref.read(academicYearsListProvider).asData?.value ?? [];
      final year = years
          .where((y) => y.id == entry.academicYearId)
          .firstOrNull;
      final prefill = OcrEnrollmentPrefill(
        academicYearId: entry.academicYearId!,
        gradeLevel: entry.gradeLevel,
        sectionId: entry.sectionId,
        sectionName:
            entry.record.section.isEmpty ? 'Section' : entry.record.section,
        schoolYear: year?.yearRange ?? entry.record.schoolYear,
      );
      setState(() {
        _acceptedPrefills.add(prefill);
        _entries.removeAt(index);
      });
      return;
    }

    setState(() => _acceptingIndex = index);
    try {
      await ref.read(studentMutationProvider.notifier).addEnrollment(
            studentId: widget.studentId!,
            academicYearId: entry.academicYearId!,
            gradeLevel: entry.gradeLevel,
            sectionId: entry.sectionId!,
          );
      if (!mounted) return;
      setState(() {
        _acceptedCount++;
        _entries.removeAt(index);
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      showErrorDialog(context, 'Accept Failed', msg);
    } finally {
      if (mounted) setState(() => _acceptingIndex = null);
    }
  }

  void _remove(int index) {
    setState(() => _entries.removeAt(index));
  }

  void _close() {
    Navigator.of(context).pop(
      _isEditMode
          ? _acceptedCount
          : List<OcrEnrollmentPrefill>.from(_acceptedPrefills),
    );
  }

  InputDecoration _deco(String label) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yearsAsync = ref.watch(academicYearsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final years = yearsAsync.asData?.value ?? <AcademicYearModel>[];
    final allSections = sectionsAsync.asData?.value ?? <SectionModel>[];
    final initialCount =
        _entries.length + (_isEditMode ? _acceptedCount : _acceptedPrefills.length);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.document_scanner,
                    size: 22,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEditMode
                          ? 'Validate Enrollment from OCR'
                          : 'Review Enrollment from Scan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Edit Year Level, Grade Level, and Section. '
                'Accept to save, decline/delete to skip without saving.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_entries.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No records left.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildEntryRow(index, years, allSections, isDark),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _isEditMode
                        ? '$_acceptedCount of $initialCount accepted'
                        : '${_acceptedPrefills.length} of $initialCount accepted',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _close,
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryRow(
    int index,
    List<AcademicYearModel> years,
    List<SectionModel> allSections,
    bool isDark,
  ) {
    final entry = _entries[index];
    final sections = _sectionsForEntry(allSections, entry);
    final sectionValueOk = entry.sectionId != null &&
        sections.any((s) => s.id == entry.sectionId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.record.schoolYear.isEmpty
                      ? 'Detected Enrollment'
                      : 'Detected: ${entry.record.schoolYear} · Grade ${entry.record.gradeLevel} · ${entry.record.section}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              // Icon-only actions: no container, no background, no border.
              IconButton(
                onPressed: _acceptingIndex == index
                    ? null
                    : () => _accept(index),
                tooltip: 'Accept Enrollment',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: _acceptingIndex == index
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                        size: 22,
                        color: AppColors.primaryGreen,
                      ),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: _acceptingIndex == index
                    ? null
                    : () => _remove(index),
                tooltip: 'Decline Enrollment',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.block,
                  size: 20,
                  color: AppColors.warning,
                ),
              ),
              if (_isEditMode) ...[
                const SizedBox(width: 2),
                IconButton(
                  onPressed:
                      _acceptingIndex == index ? null : () => _remove(index),
                  tooltip: 'Delete Record',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<int>(
                  initialValue: entry.academicYearId,
                  isExpanded: true,
                  decoration: _deco('Year Level'),
                  items: years
                      .map((y) => DropdownMenuItem<int>(
                          value: y.id, child: Text(y.yearRange)))
                      .toList(),
                  onChanged: _acceptingIndex == index
                      ? null
                      : (v) => setState(() {
                            entry.academicYearId = v;
                            entry.sectionId =
                                _matchSection(allSections, entry);
                          }),
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  initialValue: entry.gradeLevel,
                  isExpanded: true,
                  decoration: _deco('Grade Level'),
                  items: [7, 8, 9, 10, 11, 12]
                      .map((g) => DropdownMenuItem<int>(
                          value: g, child: Text('Grade $g')))
                      .toList(),
                  onChanged: _acceptingIndex == index
                      ? null
                      : (v) => setState(() {
                            entry.gradeLevel = v!;
                            entry.sectionId =
                                _matchSection(allSections, entry);
                          }),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int>(
                  initialValue: sectionValueOk ? entry.sectionId : null,
                  isExpanded: true,
                  decoration: _deco('Section'),
                  items: sections
                      .map((s) =>
                          DropdownMenuItem<int>(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: _acceptingIndex == index
                      ? null
                      : (v) => setState(() => entry.sectionId = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
