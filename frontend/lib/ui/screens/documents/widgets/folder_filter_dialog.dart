import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/document_provider.dart';

class FolderFilterDialog extends ConsumerStatefulWidget {
  final DocumentQueryParams initialQuery;

  const FolderFilterDialog({
    super.key,
    required this.initialQuery,
  });

  static Future<void> show(
    BuildContext context, {
    required DocumentQueryParams query,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: MediaQuery.of(context).size.height < 600 ? 16 : 40,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: FolderFilterDialog(
            initialQuery: query,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<FolderFilterDialog> createState() =>
      _FolderFilterDialogState();
}

class _FolderFilterDialogState extends ConsumerState<FolderFilterDialog> {
  late String _selectedGradeLevel;
  late String _selectedSection;

  @override
  void initState() {
    super.initState();
    _selectedGradeLevel = widget.initialQuery.gradeLevel.isEmpty
        ? 'All Grades'
        : widget.initialQuery.gradeLevel;
    _selectedSection = widget.initialQuery.section.isEmpty
        ? 'All Sections'
        : widget.initialQuery.section;
  }

  void _applyFilters([String? activeYearRange]) {
    final notifier = ref.read(documentQueryProvider.notifier);
    notifier.setGradeLevel(_selectedGradeLevel == 'All Grades' ? '' : _selectedGradeLevel);
    // School Year is selected in background as the active year
    if (activeYearRange != null && activeYearRange.isNotEmpty) {
      notifier.setSchoolYear(activeYearRange);
    }
    notifier.setSection(_selectedSection == 'All Sections' ? '' : _selectedSection);
    Navigator.pop(context);
  }

  void _resetFilters([String? activeYearRange]) {
    setState(() {
      _selectedGradeLevel = 'All Grades';
      _selectedSection = 'All Sections';
    });
    final notifier = ref.read(documentQueryProvider.notifier);
    notifier.setGradeLevel('');
    if (activeYearRange != null && activeYearRange.isNotEmpty) {
      notifier.setSchoolYear(activeYearRange);
    }
    notifier.setSection('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final academicYearsAsync = ref.watch(academicYearsListProvider);

    final activeYear = academicYearsAsync.valueOrNull?.firstWhere(
      (y) => y.status.toLowerCase() == 'active',
      orElse: () => academicYearsAsync.valueOrNull?.isNotEmpty == true
          ? academicYearsAsync.valueOrNull!.first
          : AcademicYearModel(id: 0, yearRange: '', status: ''),
    );
    final activeYearRange = activeYear?.yearRange ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Filter Folders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [

                  _buildDropdown<String>(
                    label: 'Grade Level',
                    value: _selectedGradeLevel,
                    items: gradeLevelsAsync.maybeWhen(
                      data: (grades) => [
                        'All Grades',
                        ...grades.map((g) => g.name)
                      ],
                      orElse: () => ['All Grades'],
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGradeLevel = val;
                          _selectedSection = 'All Sections';
                        });
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  _buildDropdown<String>(
                    label: 'Section',
                    value: _selectedSection,
                    items: sectionsAsync.maybeWhen(
                      data: (sections) {
                        final sectionNames = {'All Sections'};
                        var filteredSections = sections;
                        
                        // 1. Only show sections belonging to the active academic year
                        if (activeYear != null && activeYear.id > 0) {
                          filteredSections = filteredSections.where((s) {
                            if (s.academicYearId != null) {
                              return s.academicYearId == activeYear.id;
                            }
                            if (s.academicYearRange != null && s.academicYearRange!.isNotEmpty) {
                              return s.academicYearRange == activeYear.yearRange;
                            }
                            return true;
                          }).toList();
                        }

                        // 2. Only show sections belonging to the selected grade level
                        if (_selectedGradeLevel != 'All Grades') {
                          final grades = gradeLevelsAsync.valueOrNull ?? [];
                          final match = grades.where((g) => g.name == _selectedGradeLevel);
                          if (match.isNotEmpty) {
                            final levelInt = match.first.level;
                            filteredSections = filteredSections.where((s) => s.gradeLevel == levelInt).toList();
                          }
                        }
                        
                        sectionNames.addAll(filteredSections.map((s) => s.name));
                        
                        // Ensure selected section is in the new list, otherwise reset
                        if (!sectionNames.contains(_selectedSection)) {
                           // Delay reset to avoid building error
                           WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _selectedSection = 'All Sections');
                           });
                        }
                        
                        return sectionNames.toList();
                      },
                      orElse: () => ['All Sections'],
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSection = val);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _resetFilters(activeYearRange),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _applyFilters(activeYearRange),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    // Ensure value is in items, otherwise fallback to first item
    T currentValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: currentValue,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                width: 2,
              ),
            ),
          ),
          dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
