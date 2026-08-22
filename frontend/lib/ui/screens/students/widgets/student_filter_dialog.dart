import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../domain/entities/setup_models.dart';
import '../../../providers/setup_provider.dart';
import '../../../providers/student_provider.dart';

class StudentFilterDialog extends ConsumerStatefulWidget {
  final StudentQueryParams initialQuery;

  const StudentFilterDialog({
    super.key,
    required this.initialQuery,
  });

  static Future<void> show(
    BuildContext context, {
    required StudentQueryParams query,
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
          child: StudentFilterDialog(initialQuery: query),
        ),
      ),
    );
  }

  @override
  ConsumerState<StudentFilterDialog> createState() =>
      _StudentFilterDialogState();
}

class _StudentFilterDialogState extends ConsumerState<StudentFilterDialog> {
  late String _pendingSchoolYear;
  late String _pendingGradeLevel;
  late String _pendingSection;
  late String _pendingStatus;
  late String _pending4Ps;
  late String _pendingSortBy;
  late String _pendingSortOrder;
  late int _pendingLimit;

  static const _docStatusSortItems = [
    'Default',
    'Completed',
    'Pending',
  ];
  static const _statusItems = [
    'All Status',
    'Enrolled',
    'Graduated',
    'Transferred',
    'Dropped',
    'Inactive',
  ];
  static const _4psItems = ['All', 'Yes', 'No'];
  static const _pageSizes = [10, 15, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    _pendingSchoolYear =
        q.schoolYear.isEmpty ? 'All School Years' : q.schoolYear;
    _pendingGradeLevel = q.gradeLevel.isEmpty ? 'All Grades' : q.gradeLevel;
    _pendingSection = q.section.isEmpty ? 'All Sections' : q.section;
    _pendingStatus = q.status.isEmpty ? 'All Status' : q.status;
    _pending4Ps =
        q.is4Ps.isEmpty ? 'All' : (q.is4Ps == 'true' ? 'Yes' : 'No');
    _pendingSortBy = q.sortBy;
    _pendingSortOrder = q.sortOrder;
    _pendingLimit = q.limit;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(sectionsListProvider);
      }
    });
  }

  String _formatGradeDisplay(String grade) {
    if (grade == 'All Grades') return 'All Grades';
    if (grade.toLowerCase().startsWith('grade')) return grade;
    return 'Grade $grade';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reactively watch database setup providers
    final academicYearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    // 1. Dynamic School Years from DB
    final syItems = [
      'All School Years',
      ...academicYearsAsync.maybeWhen(
        data: (years) => years.map((y) => y.yearRange).toList(),
        orElse: () => <String>[],
      ),
    ];
    if (!syItems.contains(_pendingSchoolYear)) {
      _pendingSchoolYear = 'All School Years';
    }

    // 2. Dynamic Grade Levels from DB
    final dbGradeLevels = gradeLevelsAsync.maybeWhen(
      data: (grades) {
        final list = List<GradeLevelModel>.from(grades);
        list.sort((a, b) => a.level.compareTo(b.level));
        return list.map((g) => g.level.toString()).toList();
      },
      orElse: () => ['7', '8', '9', '10', '11', '12'],
    );

    List<String> availableGrades = dbGradeLevels;
    if (_pendingSchoolYear != 'All School Years' && sectionsAsync.hasValue) {
      final sList = sectionsAsync.value ?? [];
      final gradesInYear = sList
          .where((s) => s.academicYearRange == _pendingSchoolYear)
          .map((s) => s.gradeLevel.toString())
          .toSet();
      if (gradesInYear.isNotEmpty) {
        availableGrades =
            dbGradeLevels.where((g) => gradesInYear.contains(g)).toList();
      }
    }
    final gradeLevelItems = ['All Grades', ...availableGrades];
    if (!gradeLevelItems.contains(_pendingGradeLevel)) {
      _pendingGradeLevel = 'All Grades';
    }

    // 3. Dynamic Sections from DB (Cascaded by Grade Level & School Year)
    final sectionItems = sectionsAsync.maybeWhen(
      data: (sections) {
        final filteredSections = sections.where((s) {
          if (_pendingGradeLevel != 'All Grades' &&
              s.gradeLevel.toString() != _pendingGradeLevel) {
            return false;
          }
          if (_pendingSchoolYear != 'All School Years' &&
              s.academicYearRange != null &&
              s.academicYearRange != _pendingSchoolYear) {
            return false;
          }
          return true;
        });
        final names = filteredSections
            .map((s) => s.name.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return ['All Sections', ...names];
      },
      orElse: () => ['All Sections'],
    );
    if (!sectionItems.contains(_pendingSection)) {
      _pendingSection = 'All Sections';
    }

    final isSectionEnabled =
        _pendingGradeLevel != 'All Grades' && sectionItems.length > 1;
    final sectionHint = _pendingGradeLevel == 'All Grades'
        ? 'Select Grade Level first'
        : (sectionItems.length <= 1 ? 'No sections available' : null);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Filter Students',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(
            height: 20,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          ),

          // ── Scrollable Filter Body ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. School Year (Cascades to Grade & Section)
                  _buildFilterSection(
                    label: 'School Year',
                    hasActiveFilter:
                        _pendingSchoolYear != 'All School Years',
                    onReset: () => setState(() {
                      _pendingSchoolYear = 'All School Years';
                      _pendingGradeLevel = 'All Grades';
                      _pendingSection = 'All Sections';
                    }),
                    child: _buildCleanDropdown(
                      value: _pendingSchoolYear,
                      items: syItems,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _pendingSchoolYear = v;
                            _pendingGradeLevel = 'All Grades';
                            _pendingSection = 'All Sections';
                          });
                        }
                      },
                    ),
                  ),

                  _buildDivider(isDark),

                  // 2. Grade Level (Cascades to Section)
                  _buildFilterSection(
                    label: 'Grade Level',
                    hasActiveFilter: _pendingGradeLevel != 'All Grades',
                    onReset: () => setState(() {
                      _pendingGradeLevel = 'All Grades';
                      _pendingSection = 'All Sections';
                    }),
                    child: _buildCleanDropdown(
                      value: _pendingGradeLevel,
                      items: gradeLevelItems,
                      labelBuilder: _formatGradeDisplay,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _pendingGradeLevel = v;
                            _pendingSection = 'All Sections';
                          });
                        }
                      },
                    ),
                  ),

                  _buildDivider(isDark),

                  // 3. Section (Dependent on Grade Level)
                  _buildFilterSection(
                    label: 'Section',
                    hasActiveFilter: _pendingSection != 'All Sections',
                    onReset: () => setState(() {
                      _pendingSection = 'All Sections';
                    }),
                    child: _buildCleanDropdown(
                      value: _pendingSection,
                      items: sectionItems,
                      enabled: isSectionEnabled,
                      hint: sectionHint,
                      onChanged: isSectionEnabled
                          ? (v) {
                              if (v != null) {
                                setState(() => _pendingSection = v);
                              }
                            }
                          : null,
                    ),
                  ),

                  _buildDivider(isDark),

                  // 4. Status Filter
                  _buildFilterSection(
                    label: 'Status',
                    hasActiveFilter: _pendingStatus != 'All Status',
                    onReset: () => setState(() {
                      _pendingStatus = 'All Status';
                    }),
                    child: _buildFilterChipGroup(
                      items: _statusItems,
                      selectedValue: _pendingStatus,
                      onSelected: (v) => setState(() => _pendingStatus = v),
                    ),
                  ),

                  _buildDivider(isDark),

                  // 5. 4Ps Beneficiary
                  _buildFilterSection(
                    label: '4Ps Beneficiary',
                    hasActiveFilter: _pending4Ps != 'All',
                    onReset: () => setState(() => _pending4Ps = 'All'),
                    child: _buildFilterChipGroup(
                      items: _4psItems,
                      selectedValue: _pending4Ps,
                      onSelected: (v) => setState(() => _pending4Ps = v),
                    ),
                  ),

                  _buildDivider(isDark),

                  // 6. Document Status Attention Sort
                  _buildFilterSection(
                    label: 'Doc Status Attention',
                    hasActiveFilter: _pendingSortBy == 'doc_status',
                    onReset: () => setState(() {
                      if (_pendingSortBy == 'doc_status') {
                        _pendingSortBy = '';
                        _pendingSortOrder = '';
                      }
                    }),
                    child: _buildFilterChipGroup(
                      items: _docStatusSortItems,
                      selectedValue: (_pendingSortBy == 'doc_status' &&
                              _pendingSortOrder == 'asc')
                          ? 'Completed'
                          : ((_pendingSortBy == 'doc_status' &&
                                  _pendingSortOrder == 'desc')
                              ? 'Pending'
                              : 'Default'),
                      onSelected: (v) => setState(() {
                        if (v == 'Completed') {
                          _pendingSortBy = 'doc_status';
                          _pendingSortOrder = 'asc';
                        } else if (v == 'Pending') {
                          _pendingSortBy = 'doc_status';
                          _pendingSortOrder = 'desc';
                        } else {
                          if (_pendingSortBy == 'doc_status') {
                            _pendingSortBy = '';
                            _pendingSortOrder = '';
                          }
                        }
                      }),
                    ),
                  ),

                  _buildDivider(isDark),

                  // 7. Students per Page
                  _buildFilterSection(
                    label: 'Students per Page',
                    hasActiveFilter: _pendingLimit != 20,
                    onReset: () => setState(() => _pendingLimit = 20),
                    child: _buildFilterChipGroup(
                      items: _pageSizes.map((s) => '$s per page').toList(),
                      selectedValue: '$_pendingLimit per page',
                      onSelected: (v) {
                        final numVal = int.tryParse(v.split(' ')[0]) ?? 20;
                        setState(() => _pendingLimit = numVal);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          ),

          // ── Footer Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              children: [
                // Reset all
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _pendingSchoolYear = 'All School Years';
                        _pendingGradeLevel = 'All Grades';
                        _pendingSection = 'All Sections';
                        _pendingStatus = 'All Status';
                        _pending4Ps = 'All';
                        _pendingSortBy = '';
                        _pendingSortOrder = '';
                        _pendingLimit = 20;
                      });
                    },
                    child: const Text(
                      'Reset all',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Apply now
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      String is4psVal = '';
                      if (_pending4Ps == 'Yes') is4psVal = 'true';
                      if (_pending4Ps == 'No') is4psVal = 'false';

                      ref.read(studentQueryProvider.notifier).setFilters(
                            schoolYear:
                                _pendingSchoolYear == 'All School Years'
                                    ? ''
                                    : _pendingSchoolYear,
                            gradeLevel: _pendingGradeLevel == 'All Grades'
                                ? ''
                                : _pendingGradeLevel,
                            section: _pendingSection == 'All Sections'
                                ? ''
                                : _pendingSection,
                            status: _pendingStatus == 'All Status'
                                ? ''
                                : _pendingStatus,
                            is4Ps: is4psVal,
                            sortBy: _pendingSortBy,
                            sortOrder: _pendingSortOrder,
                            limit: _pendingLimit,
                          );

                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: isDark
          ? AppColors.darkBorder.withValues(alpha: 0.5)
          : Colors.grey.shade100,
    );
  }

  Widget _buildFilterSection({
    required String label,
    required VoidCallback onReset,
    required Widget child,
    bool hasActiveFilter = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              if (hasActiveFilter)
                GestureDetector(
                  onTap: onReset,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildCleanDropdown({
    required String value,
    required List<String> items,
    String Function(String)? labelBuilder,
    ValueChanged<String?>? onChanged,
    String? hint,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedValue = items.contains(value) ? value : items.firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: enabled
            ? (isDark ? AppColors.darkSurface2 : AppColors.surfaceWhite)
            : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100),
        border: Border.all(
          color: enabled
              ? (isDark ? AppColors.darkBorder : Colors.grey.shade300)
              : (isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.5)
                  : Colors.grey.shade200),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          menuMaxHeight: 260,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          elevation: 4,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled
                ? (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary)
                : AppColors.textMuted,
            size: 22,
          ),
          hint: hint != null
              ? Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                  ),
                )
              : null,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: enabled
                ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                : AppColors.textMuted,
          ),
          items: items.map((item) {
            final displayLabel =
                labelBuilder != null ? labelBuilder(item) : item;
            final isItemActive = item == selectedValue;
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                displayLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      isItemActive ? FontWeight.w600 : FontWeight.w400,
                  color: isItemActive
                      ? AppColors.primaryGreen
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
                ),
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildFilterChipGroup({
    required List<String> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = item == selectedValue;
        return ChoiceChip(
          label: Text(
            item,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? AppColors.primaryGreen
                  : (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary),
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onSelected(item);
            }
          },
          selectedColor: AppColors.primaryGreen.withValues(alpha: 0.12),
          backgroundColor:
              isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
              width: 1,
            ),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
