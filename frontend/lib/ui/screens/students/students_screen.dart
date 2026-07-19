import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/student_model.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/student_provider.dart';
import '../documents/documents_screen.dart';
import '../documents/widgets/student_profile_modal.dart';
import 'widgets/add_edit_student_modal.dart';
import '../../providers/setup_provider.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/archives_provider.dart';
import '../../providers/auth_provider.dart';

import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/widgets/app_pagination.dart';
import 'package:data_table_2/data_table_2.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  final String userRole;
  const StudentsScreen({super.key, this.userRole = 'teacher'});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  final List<int> _selectedStudentIds = [];
  bool _showMultiSelect = false;
  ProviderSubscription<String>? _tabListener;

  // Pending filter state (applied only when user taps "Apply now")
  String _pendingSchoolYear = 'All School Years';
  String _pendingGradeLevel = 'All Grades';
  String _pendingSection    = 'All Sections';
  String _pendingStatus     = 'All Status';
  String _pending4Ps        = 'All'; // 'All', 'Yes', 'No'

  static const _gradeLevels = ['All Grades', '7', '8', '9', '10', '11', '12'];
  static const _statusItems = ['All Status', 'Enrolled', 'Graduated', 'Transferred', 'Dropped'];
  static const _4psItems    = ['All', 'Yes', 'No'];
  static const _pageSizes   = [10, 20, 50];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabListener = ref.listenManual<String>(activeTabProvider, (previous, next) {
        if (!mounted) return;
        if (next != 'Students') {
          if (_searchController.text.isNotEmpty) _searchController.clear();
          ref.read(studentQueryProvider.notifier).reset();
          if (_showMultiSelect || _selectedStudentIds.isNotEmpty) {
            setState(() {
              _showMultiSelect = false;
              _selectedStudentIds.clear();
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _horizontalScrollController.dispose();
    ref.read(studentQueryProvider.notifier).reset();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(studentQueryProvider.notifier).setSearch(_searchController.text);
    });
  }

  void _onSearchSubmitted(String query) {
    _debounce?.cancel();
    ref.read(studentQueryProvider.notifier).setSearch(query);
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  // ----------------------------------------------------------------
  // SHOW ADD / EDIT MODAL
  // ----------------------------------------------------------------
  Future<bool?> _openModal({StudentModel? student}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditStudentModal(student: student),
    );
    // result == true means success — list already refreshed by provider
    if (result == true && mounted) {
      // Provider already invalidated inside mutation notifier
      await showSuccessDialog(
        context,
        message: student == null
            ? 'Student added successfully!'
            : 'Student updated successfully!',
      );
    }
    return result;
  }

  void _toggleSelectAll(List<StudentModel> students) {
    setState(() {
      if (_selectedStudentIds.length == students.length) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds.clear();
        _selectedStudentIds.addAll(students.map((e) => e.id));
      }
    });
  }

  Widget _buildBatchActionsBar(List<StudentModel> allStudents) {
    if (!_showMultiSelect) return const SizedBox.shrink();
    
    final count = _selectedStudentIds.length;
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final allSelected = count > 0 && count == allStudents.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count == 0 ? (isMobile ? '0' : 'Select') : '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: count == 0 ? AppColors.textSecondary : AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isMobile) ...[
            TextButton.icon(
              onPressed: () => _toggleSelectAll(allStudents),
              icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 18),
              label: Text(allSelected ? 'Deselect' : 'Select All'),
            ),
            const SizedBox(width: 8),
          ] else ...[
             IconButton(
               onPressed: () => _toggleSelectAll(allStudents),
               icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 20),
               tooltip: allSelected ? 'Deselect All' : 'Select All',
             ),
          ],
          Container(height: 24, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
          if (!isMobile) ...[
            ElevatedButton.icon(
              onPressed: count == 0 ? null : _showBulkEnrollModal,
              icon: const Icon(Icons.group_add, size: 18),
              label: const Text('Enroll'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: count == 0 ? null : _showBulkGraduateConfirm,
              icon: const Icon(Icons.school, size: 18),
              label: const Text('Graduate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ] else ...[
            IconButton(
              onPressed: count == 0 ? null : _showBulkEnrollModal,
              icon: Icon(Icons.group_add, color: count == 0 ? Colors.grey : AppColors.primaryGreen),
              tooltip: 'Enroll',
            ),
            IconButton(
              onPressed: count == 0 ? null : _showBulkGraduateConfirm,
              icon: Icon(Icons.school, color: count == 0 ? Colors.grey : Colors.blue),
              tooltip: 'Graduate',
            ),
          ],
          const SizedBox(width: 4),
          Container(height: 24, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
          IconButton(
            onPressed: () => setState(() {
              _selectedStudentIds.clear();
              _showMultiSelect = false;
            }),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Cancel',
          ),
        ],
      ),
    );
  }

  Widget _batchActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showBulkEnrollModal() {
    showDialog(
      context: context,
      builder: (context) => BulkEnrollDialog(
        studentIds: _selectedStudentIds,
        onSuccess: () {
          setState(() {
            _selectedStudentIds.clear();
            _showMultiSelect = false;
          });
          showSuccessDialog(context, message: 'Students successfully enrolled.');
        },
      ),
    );
  }

  void _showBulkGraduateConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Graduate'),
        content: Text('Are you sure you want to change the status of ${_selectedStudentIds.length} selected student(s) to "Graduated"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('GRADUATE'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(studentMutationProvider.notifier).bulkGraduate(_selectedStudentIds);
        if (mounted) {
          setState(() {
            _selectedStudentIds.clear();
            _showMultiSelect = false;
          });
          showSuccessDialog(context, message: 'Students successfully graduated.');
        }
      } catch (e) {
        if (mounted) {
          final errMsg = e.toString().replaceAll('Exception: ', '');
          showErrorDialog(context, 'Error', errMsg);
        }
      }
    }
  }

  // ----------------------------------------------------------------
  // DELETE CONFIRM
  // ----------------------------------------------------------------
  Future<void> _confirmDelete(StudentModel student) async {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Delete Student?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to permanently delete '
                    '"${student.listDisplayName}"? This cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  const Text('Please enter your password to confirm:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: errorMessage,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final pwd = passwordController.text;
                          if (pwd.isEmpty) {
                            setState(() => errorMessage = 'Password is required');
                            return;
                          }
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          final isVerified = await ref.read(authProvider.notifier).verifyPassword(pwd);
                          if (!isVerified) {
                            setState(() {
                              isLoading = false;
                              errorMessage = 'Incorrect password';
                            });
                          } else {
                            Navigator.of(ctx).pop(true);
                          }
                        },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('DELETE'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(studentMutationProvider.notifier).deleteStudent(student.id);
        if (mounted) {
          showSuccessDialog(context, message: 'Student deleted successfully.');
        }
      } catch (e) {
        if (mounted) {
          final raw = e.toString();
          final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
          showErrorDialog(context, 'Error', msg);
        }
      }
    }
  }

  // ----------------------------------------------------------------
  // NAVIGATION HELPERS
  // ----------------------------------------------------------------
  void _viewProfile(StudentModel student) {
    showStudentProfileModal(
      context,
      studentId: student.id,
      userRole: widget.userRole,
      onEdit: () async {
        Navigator.pop(context);
        await _openModal(student: student);
        if (mounted) {
          _viewProfile(student);
        }
      },
      onDelete: () {
        Navigator.pop(context);
        _confirmDelete(student);
      },
    );
  }

  void _openDocumentsFolder(StudentModel student) {
    if (student.status == 'Graduated' || student.status == 'Transferred' || student.status == 'Dropped') {
      ref.read(activeTabProvider.notifier).setTab('Archives');
      Future.microtask(() {
        if (mounted) {
          ref.read(openedArchiveFolderProvider.notifier).setFolder(
            OpenedArchiveFolderData(id: student.id, name: student.listDisplayName)
          );
        }
      });
    } else {
      ref.read(activeTabProvider.notifier).setTab('Documents');
      Future.microtask(() {
        if (mounted) {
          ref.read(openedFolderProvider.notifier).setFolder(
            OpenedFolderData(id: student.id, name: student.listDisplayName)
          );
        }
      });
    }
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final query    = ref.watch(studentQueryProvider);
    final pageAsync = ref.watch(studentPageProvider);
    final isMobile = MediaQuery.of(context).size.width <= 800;
    
    final academicYearsAsync = ref.watch(academicYearsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);
    final activeCount = [
      query.schoolYear.isNotEmpty,
      query.gradeLevel.isNotEmpty,
      query.section.isNotEmpty,
      query.status.isNotEmpty,
    ].where((v) => v).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (!isMobile || _showMultiSelect) ? null : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: 'filter_fab',
              backgroundColor: AppColors.surfaceWhite,
              foregroundColor: AppColors.primaryGreen,
              shape: const CircleBorder(),
              onPressed: () => _openFilterDialog(query, academicYearsAsync, sectionsAsync),
              child: Badge(
                isLabelVisible: activeCount > 0,
                label: Text(activeCount.toString()),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
            if (widget.userRole != 'teacher')
              FloatingActionButton(
                heroTag: 'add_student_fab',
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: () => _openModal(),
                child: const Icon(Icons.person_add),
              )
            else
              const SizedBox(width: 56), // spacer when add button is hidden
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSizes.p24,
                  right: AppSizes.p24,
                  top: AppSizes.p24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header + Controls ──
                    _buildHeaderControls(context, query, ref, activeCount),
                    const SizedBox(height: AppSizes.p24),

                    // ── Data Table / Cards ──
                    Expanded(
                      child: pageAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: AppColors.primaryGreen),
                        ),
                        error: (err, _) => _buildError(err.toString()),
                        data: (page) {
                          // Teacher with no active filters and 0 total means no sections assigned
                          final hasNoSections = widget.userRole == 'teacher' &&
                              query.search.isEmpty &&
                              query.gradeLevel.isEmpty &&
                              query.section.isEmpty &&
                              query.status.isEmpty &&
                              query.schoolYear.isEmpty &&
                              page.total == 0;
                          return LayoutBuilder(
                            builder: (ctx, c) => c.maxWidth > 800
                                ? _buildDesktopTable(page.students, noSections: hasNoSections)
                                : _buildMobileCardList(page.students, noSections: hasNoSections),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Pagination ──
            pageAsync.maybeWhen(
              data:   (page) => _buildPagination(query, page),
              orElse: () => const SizedBox.shrink(),
              ),
              ],
            ),
          ),
          if (_showMultiSelect)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: SafeArea(
                child: pageAsync.maybeWhen(
                  data: (page) => _buildBatchActionsBar(page.students),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================================================================
  // HEADER + CONTROLS
  // ================================================================
  Widget _buildHeaderControls(BuildContext context, StudentQueryParams query, WidgetRef ref, int activeCount) {

    return LayoutBuilder(builder: (_, c) {
      final isDesktop = c.maxWidth > 800;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Students Directory',
                style: TextStyle(
                  fontSize:   isDesktop ? 28 : 22,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p16),

          // ── Search bar + multi-select ──
          Row(
            children: [
              Flexible(
                child: AppSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  collapsible: true,
                  hideIconWhenExpanded: true,
                  onSubmitted: _onSearchSubmitted,
                  hint: 'Search by LRN or name...',
                  maxWidth: isDesktop ? 420 : c.maxWidth,
                ),
              ),
              if (widget.userRole != 'teacher' && !_searchFocusNode.hasFocus) ...[
                const SizedBox(width: 8),
                _buildMultiSelectToggle(false),
              ],
              if (isDesktop && !_searchFocusNode.hasFocus) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () => _openFilterDialog(query, ref.read(academicYearsListProvider), ref.read(sectionsListProvider)),
                    icon: Badge(
                      isLabelVisible: activeCount > 0,
                      label: Text(activeCount.toString()),
                      child: const Icon(Icons.tune_rounded, size: 20),
                    ),
                    label: const Text('Filter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                    ),
                  ),
                ),
                if (widget.userRole != 'teacher') ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    height: 42,
                    child: PrimaryButton(
                      label: 'ADD',
                      onPressed: () => _openModal(),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      );
    });
  }

  // ================================================================
  // FILTER BUTTON + DIALOG OPENER
  // ================================================================
  void _openFilterDialog(
    StudentQueryParams query,
    AsyncValue<dynamic> academicYearsAsync,
    AsyncValue<dynamic> sectionsAsync,
  ) {
    // Sync pending state from current applied query before opening
    setState(() {
      _pendingSchoolYear = query.schoolYear.isEmpty ? 'All School Years' : query.schoolYear;
      _pendingGradeLevel = query.gradeLevel.isEmpty ? 'All Grades' : query.gradeLevel;
      _pendingSection    = query.section.isEmpty    ? 'All Sections'   : query.section;
      _pendingStatus     = query.status.isEmpty     ? 'All Status'     : query.status;
      _pending4Ps        = query.is4Ps.isEmpty      ? 'All' : (query.is4Ps == 'true' ? 'Yes' : 'No');
    });

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildFilterPanelContent(
                query,
                academicYearsAsync,
                sectionsAsync,
                setDialogState,
                () => Navigator.of(ctx).pop(),
              ),
            ),
          );
        },
      ),
    );
  }


  // ================================================================
  // MULTI-SELECT TOGGLE
  // ================================================================
  Widget _buildMultiSelectToggle(bool isIconOnly) {
    return Tooltip(
      message: 'Multi-Select',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showMultiSelect = !_showMultiSelect;
            if (!_showMultiSelect) _selectedStudentIds.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(horizontal: isIconOnly ? 12 : 14, vertical: 8),
          height: 42,
          decoration: BoxDecoration(
            color: _showMultiSelect
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : AppColors.surfaceWhite,
            border: Border.all(
              color: _showMultiSelect ? AppColors.primaryGreen : Colors.grey.shade300,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showMultiSelect ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 16,
                color: _showMultiSelect ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
              if (!isIconOnly) ...[
                const SizedBox(width: 6),
                Text(
                  'Select',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _showMultiSelect ? AppColors.primaryGreen : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // FILTER PANEL
  // ================================================================
  Widget _buildFilterPanelContent(
    StudentQueryParams query,
    AsyncValue<dynamic> academicYearsAsync,
    AsyncValue<dynamic> sectionsAsync,
    StateSetter setDialogState,
    VoidCallback onApply,
  ) {
    final syItems = academicYearsAsync.whenOrNull(
          data: (years) => ['All School Years', ...(years as List).map((y) => y.yearRange as String)],
        ) ??
        ['All School Years'];

    final sectionItems = sectionsAsync.whenOrNull(
          data: (sections) {
            final filteredSections = (sections as List).where((s) {
              if (_pendingGradeLevel != 'All Grades' && s.gradeLevel.toString() != _pendingGradeLevel) return false;
              if (_pendingSchoolYear != 'All School Years' && s.academicYearRange != _pendingSchoolYear) return false;
              return true;
            });
            final raw = ['All Sections', ...filteredSections.map((s) => s.name as String)];
            return raw.toSet().toList();
          },
        ) ??
        ['All Sections'];

    // Precompute counts for badges
    final Map<String, int> syGradeCount = {};
    if (academicYearsAsync.value != null && sectionsAsync.value != null) {
      final sList = sectionsAsync.value as List;
      for (final sy in syItems.skip(1)) {
        syGradeCount[sy] = sList.where((s) => s.academicYearRange == sy).map((s) => s.gradeLevel).toSet().length;
      }
    }

    final Map<String, int> gradeSectionCount = {};
    if (sectionsAsync.value != null) {
      final sList = sectionsAsync.value as List;
      for (final grade in _gradeLevels.skip(1)) {
        gradeSectionCount[grade] = sList.where((s) {
          final matchGrade = s.gradeLevel.toString() == grade;
          final matchSy = _pendingSchoolYear == 'All School Years' || s.academicYearRange == _pendingSchoolYear;
          return matchGrade && matchSy;
        }).length;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 20),

          // School Year
          _buildFilterSection(
            label: 'School Year',
            onReset: () => setDialogState(() {
              _pendingSchoolYear = 'All School Years';
              _pendingSection = 'All Sections';
            }),
            child: _buildFilterDropdown(
              value: syItems.contains(_pendingSchoolYear) ? _pendingSchoolYear : 'All School Years',
              items: syItems,
              counts: syGradeCount,
              onChanged: (v) => setDialogState(() {
                _pendingSchoolYear = v!;
                _pendingSection = 'All Sections';
              }),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // Grade Level
          _buildFilterSection(
            label: 'Grade Level',
            onReset: () => setDialogState(() {
              _pendingGradeLevel = 'All Grades';
              _pendingSection = 'All Sections';
            }),
            child: _buildFilterDropdown(
              value: _gradeLevels.contains(_pendingGradeLevel) ? _pendingGradeLevel : 'All Grades',
              items: _gradeLevels.toList(),
              counts: gradeSectionCount,
              onChanged: (v) => setDialogState(() {
                _pendingGradeLevel = v!;
                _pendingSection = 'All Sections';
              }),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // Section
          _buildFilterSection(
            label: 'Section',
            onReset: () => setDialogState(() => _pendingSection = 'All Sections'),
            child: _buildFilterDropdown(
              value: sectionItems.contains(_pendingSection) ? _pendingSection : 'All Sections',
              items: sectionItems,
              hint: _pendingGradeLevel == 'All Grades' ? 'Select Grade Level first' : null,
              enabled: _pendingGradeLevel != 'All Grades',
              onChanged: _pendingGradeLevel == 'All Grades'
                  ? null
                  : (v) => setDialogState(() => _pendingSection = v!),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // Status
          _buildFilterSection(
            label: 'Status',
            onReset: () => setDialogState(() => _pendingStatus = 'All Status'),
            child: _buildFilterDropdown(
              value: _statusItems.contains(_pendingStatus) ? _pendingStatus : 'All Status',
              items: _statusItems.toList(),
              onChanged: (v) => setDialogState(() => _pendingStatus = v!),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // 4Ps Beneficiary
          _buildFilterSection(
            label: '4Ps Beneficiary',
            onReset: () => setDialogState(() => _pending4Ps = 'All'),
            child: _buildFilterDropdown(
              value: _4psItems.contains(_pending4Ps) ? _pending4Ps : 'All',
              items: _4psItems.toList(),
              onChanged: (v) => setDialogState(() => _pending4Ps = v!),
            ),
          ),

          // Footer buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                // Reset all
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _pendingSchoolYear = 'All School Years';
                        _pendingGradeLevel = 'All Grades';
                        _pendingSection    = 'All Sections';
                        _pendingStatus     = 'All Status';
                        _pending4Ps        = 'All';
                      });
                      final n = ref.read(studentQueryProvider.notifier);
                      n.setSchoolYear('');
                      n.setGradeLevel('');
                      n.setSection('');
                      n.setStatus('');
                      n.setIs4Ps('');
                    },
                    child: const Text('Reset all', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                // Apply
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final n = ref.read(studentQueryProvider.notifier);
                      n.setSchoolYear(_pendingSchoolYear == 'All School Years' ? '' : _pendingSchoolYear);
                      n.setGradeLevel(_pendingGradeLevel == 'All Grades' ? '' : _pendingGradeLevel);
                      n.setSection(_pendingSection == 'All Sections' ? '' : _pendingSection);
                      n.setStatus(_pendingStatus == 'All Status' ? '' : _pendingStatus);
                      
                      String is4psVal = '';
                      if (_pending4Ps == 'Yes') is4psVal = 'true';
                      if (_pending4Ps == 'No') is4psVal = 'false';
                      n.setIs4Ps(is4psVal);

                      onApply();
                    },
                    child: const Text('Apply now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String label,
    required VoidCallback onReset,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: onReset,
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
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

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    Map<String, int>? counts,
    ValueChanged<String?>? onChanged,
    String? hint,
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceWhite : Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            fontSize: 14,
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
          hint: hint != null
              ? Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))
              : null,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? AppColors.textSecondary : AppColors.textMuted,
            size: 20,
          ),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(i, style: const TextStyle(fontSize: 14)),
                        if (counts != null && counts[i] != null && counts[i]! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              counts[i].toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  // ================================================================
  // DESKTOP DATA TABLE
  // ================================================================
  Widget _buildDesktopTable(List<StudentModel> students, {bool noSections = false}) {
    if (students.isEmpty) return _buildEmptyState(noSections: noSections);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width:      double.infinity,
          decoration: BoxDecoration(
            color:        AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            child: DataTable2(
              minWidth: 900,
              columnSpacing: 12,
              horizontalMargin: 16,
              headingRowColor: WidgetStateProperty.all(
                AppColors.primaryGreen.withValues(alpha: 0.06),
              ),
              dataRowHeight: 56,
              columns: [
                if (widget.userRole != 'teacher' && _showMultiSelect)
                  DataColumn2(
                    fixedWidth: 40,
                    label: Checkbox(
                      activeColor: AppColors.primaryGreen,
                      value: students.isNotEmpty &&
                          students.every((s) => _selectedStudentIds.contains(s.id)),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            for (var s in students) {
                              if (!_selectedStudentIds.contains(s.id)) {
                                _selectedStudentIds.add(s.id);
                              }
                            }
                          } else {
                            for (var s in students) {
                              _selectedStudentIds.remove(s.id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                const DataColumn2(size: ColumnSize.M, label: Text('LRN',           style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn2(size: ColumnSize.L, label: Text('Name',          style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn2(size: ColumnSize.M, label: Text('Grade & Sec.',  style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn2(size: ColumnSize.S, label: Text('4Ps',           style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn2(size: ColumnSize.S, label: Text('Status',        style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn2(size: ColumnSize.M, label: Text('Missing Docs',  style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn2(size: ColumnSize.S, label: Text('Actions',       style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: students.map((student) {
                final isSelected = _selectedStudentIds.contains(student.id);
                return DataRow(
                  selected: isSelected,
                  cells: [
                    if (widget.userRole != 'teacher' && _showMultiSelect)
                      DataCell(
                        Checkbox(
                          activeColor: AppColors.primaryGreen,
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedStudentIds.add(student.id);
                              } else {
                                _selectedStudentIds.remove(student.id);
                              }
                            });
                          },
                        ),
                      ),
                    DataCell(
                      Text(student.lrn, style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => _viewProfile(student),
                    ),
                    DataCell(
                      Text(student.listDisplayName),
                      onTap: () => _viewProfile(student),
                    ),
                    DataCell(
                      Text(student.gradeSection),
                      onTap: () => _viewProfile(student),
                    ),
                    DataCell(
                      student.is4ps 
                          ? const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 20)
                          : const Icon(Icons.cancel, color: Colors.grey, size: 20),
                      onTap: () => _viewProfile(student),
                    ),
                    DataCell(
                      _StatusChip(status: student.status),
                      onTap: () => _viewProfile(student),
                    ),
                    DataCell(
                      _DocumentProgressBar(
                        missingCount: student.missingDocumentsCount,
                        totalCount: student.totalDocumentsCount,
                        missingDocuments: student.missingDocuments,
                      ),
                      onTap: () => _viewProfile(student),
                    ),
                    DataCell(_ActionButtons(
                      onOpenDocuments:  () => _openDocumentsFolder(student),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          );
        },
    );
  }

  // ================================================================
  // MOBILE CARD LIST
  // ================================================================
  Widget _buildMobileCardList(List<StudentModel> students, {bool noSections = false}) {
    if (students.isEmpty) return _buildEmptyState(noSections: noSections);

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async {
        ref.invalidate(studentPageProvider);
        // Wait for the provider to rebuild
        await ref.read(studentPageProvider.future);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: students.length,
        separatorBuilder: (ctx, index) =>
            const SizedBox(height: AppSizes.p12),
        itemBuilder: (_, i) {
          final s = students[i];

          return InkWell(
            onTap: () {
              if (_showMultiSelect) {
                setState(() {
                  if (_selectedStudentIds.contains(s.id)) {
                    _selectedStudentIds.remove(s.id);
                  } else {
                    _selectedStudentIds.add(s.id);
                  }
                });
              } else {
                _viewProfile(s);
              }
            },
            onLongPress: widget.userRole != 'teacher'
                ? () {
                    setState(() {
                      _showMultiSelect = true;
                      if (!_selectedStudentIds.contains(s.id)) {
                        _selectedStudentIds.add(s.id);
                      }
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.p16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.userRole != 'teacher' && _showMultiSelect) ...[
                    Checkbox(
                      activeColor: AppColors.primaryGreen,
                      value: _selectedStudentIds.contains(s.id),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedStudentIds.add(s.id);
                          } else {
                            _selectedStudentIds.remove(s.id);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Avatar
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                      child: Text(
                        '${s.firstName.isNotEmpty ? s.firstName[0] : ''}${s.lastName.isNotEmpty ? s.lastName[0] : ''}',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.p16),
                  
                  // Info Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                s.listDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (s.is4ps) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '4Ps',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _StatusChip(status: s.status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'LRN: ${s.lrn}  ·  ${s.gradeSection}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                _DocumentProgressBar(
                                  missingCount: s.missingDocumentsCount,
                                  totalCount: s.totalDocumentsCount,
                                  missingDocuments: s.missingDocuments,
                                ),
                              ],
                            ),
                            _ActionButtons(
                              onOpenDocuments: () => _openDocumentsFolder(s),
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
        },
      ),
    );
  }

  // ================================================================
  // PAGINATION CONTROLS
  // ================================================================
  Widget _buildPagination(StudentQueryParams query, dynamic page) {
    return AppPagination(
      currentPage: query.page,
      totalPages: page.totalPages as int,
      onPageChanged: (p) => ref.read(studentQueryProvider.notifier).setPage(p),
    );
  }

  Widget _buildEmptyState({bool noSections = false}) {
    if (noSections) {
      // Teacher has no sections assigned at all
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.class_outlined, size: 56, color: Colors.orange.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'No sections assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no sections assigned to your account yet.\nContact your administrator to assign sections.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No students found.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    final clean = message.startsWith('Exception: ') ? message.substring(11) : message;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            clean,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon:      const Icon(Icons.refresh),
            label:     const Text('Retry'),
            onPressed: () => ref.invalidate(studentPageProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// EXTRACTED COMPONENTS
// ================================================================


class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _bg {
    return switch (status) {
      'Enrolled'        => AppColors.primaryGreen.withValues(alpha: 0.10),
      'Graduated'       => Colors.blue.withValues(alpha: 0.10),
      'Transferred'     => Colors.orange.withValues(alpha: 0.10),
      'Dropped'         => Colors.red.withValues(alpha: 0.10),
      _                 => Colors.grey.shade200,
    };
  }

  Color get _text {
    return switch (status) {
      'Enrolled'        => AppColors.primaryGreen,
      'Graduated'       => Colors.blue.shade700,
      'Transferred'     => Colors.orange.shade800,
      'Dropped'         => Colors.red.shade700,
      _                 => Colors.grey.shade700,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: _text, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

// ----------------------------------------------------------------
// NEW PROGRESS BAR COMPONENT (Replaces _MissingDocsBadge)
// ----------------------------------------------------------------
class _DocumentProgressBar extends StatelessWidget {
  final int missingCount;
  final int totalCount;
  final List<String> missingDocuments;

  const _DocumentProgressBar({
    required this.missingCount,
    required this.totalCount,
    required this.missingDocuments,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate how many documents are completed
    final int completedCount = (totalCount - missingCount).clamp(0, totalCount);
    
    // Prevent division by zero if totalCount is 0 (e.g. no requirements)
    final double progress = totalCount == 0 ? 1.0 : completedCount / totalCount;
    final bool isComplete = missingCount == 0 && totalCount > 0;

    String tooltipMessage = '';
    if (!isComplete && missingDocuments.isNotEmpty) {
      final jhsDocs = missingDocuments.where((d) => d.startsWith('[JHS]')).map((d) => d.replaceFirst('[JHS] ', '')).toList();
      final shsDocs = missingDocuments.where((d) => d.startsWith('[SHS]')).map((d) => d.replaceFirst('[SHS] ', '')).toList();
      final otherDocs = missingDocuments.where((d) => !d.startsWith('[JHS]') && !d.startsWith('[SHS]')).toList();
      
      final lines = <String>['Missing Documents:'];
      if (jhsDocs.isNotEmpty) {
        lines.add('JHS:');
        lines.addAll(jhsDocs.map((d) => '  • $d'));
      }
      if (shsDocs.isNotEmpty) {
        lines.add('SHS:');
        lines.addAll(shsDocs.map((d) => '  • $d'));
      }
      if (otherDocs.isNotEmpty) {
        if (jhsDocs.isNotEmpty || shsDocs.isNotEmpty) lines.add('Other:');
        lines.addAll(otherDocs.map((d) => '  • $d'));
      }

      tooltipMessage = lines.join('\n');
    } else if (isComplete) {
      tooltipMessage = 'All documents completed';
    } else {
      tooltipMessage = 'No documents required';
    }

    return Tooltip(
      message: tooltipMessage,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$completedCount / $totalCount Docs',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isComplete ? AppColors.primaryGreen : AppColors.textPrimary,
                ),
              ),
              if (isComplete) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 14),
              ]
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 100, // Fixed width to keep column formatting tidy
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: isComplete ? AppColors.primaryGreen : Colors.orange, // Orange indicates pending docs
              minHeight: 6,
              borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onOpenDocuments;

  const _ActionButtons({
    required this.onOpenDocuments,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.folder_open, color: Colors.orange, size: 22),
      tooltip: 'Open Folder',
      onPressed: onOpenDocuments,
    );
  }
}

  // ============================================================
// BULK ENROLLMENT MODAL DIALOG
// ============================================================
class BulkEnrollDialog extends ConsumerStatefulWidget {
  final List<int> studentIds;
  final VoidCallback onSuccess;

  const BulkEnrollDialog({
    super.key,
    required this.studentIds,
    required this.onSuccess,
  });

  @override
  ConsumerState<BulkEnrollDialog> createState() => _BulkEnrollDialogState();
}

class _BulkEnrollDialogState extends ConsumerState<BulkEnrollDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedAcademicYearId;
  int? _selectedGradeLevel;
  int? _selectedSectionId;
  String? _trackStrand;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    return AlertDialog(
      title: Text('Bulk Enroll ${widget.studentIds.length} Students'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                yearsAsync.when(
                  data: (years) {
                    if (_selectedAcademicYearId == null && years.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedAcademicYearId = years.first.id);
                      });
                    }
                    return DropdownButtonFormField<int>(
                      value: _selectedAcademicYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      items: years.map((y) => DropdownMenuItem<int>(
                        value: y.id, 
                        child: Text(y.yearRange)
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAcademicYearId = val;
                          _selectedSectionId = null;
                        });
                      },
                      validator: (v) => v == null ? 'Academic year is required.' : null,
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: AppSizes.p16),
                gradeLevelsAsync.when(
                  data: (grades) {
                    return DropdownButtonFormField<int>(
                      value: _selectedGradeLevel,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        prefixIcon: Icon(Icons.grade),
                        border: OutlineInputBorder(),
                      ),
                      items: grades.map((g) => DropdownMenuItem<int>(value: g.level, child: Text(g.name))).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedGradeLevel = val;
                          _selectedSectionId = null;
                        });
                      },
                      validator: (v) => v == null ? 'Grade level is required.' : null,
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: AppSizes.p16),
                sectionsAsync.when(
                  data: (sections) {
                    final filtered = sections.where((sec) =>
                        sec.academicYearId == _selectedAcademicYearId &&
                        sec.gradeLevel == _selectedGradeLevel).toList();

                    return DropdownButtonFormField<int>(
                      value: _selectedSectionId,
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        prefixIcon: Icon(Icons.segment),
                        border: OutlineInputBorder(),
                      ),
                      items: filtered.map((s) => DropdownMenuItem<int>(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (val) => setState(() => _selectedSectionId = val),
                      validator: (v) => v == null ? 'Section is required.' : null,
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                  error: (e, _) => Text('Error: $e'),
                ),
                if (_selectedGradeLevel != null && _selectedGradeLevel! >= 11) ...[
                  const SizedBox(height: AppSizes.p16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Track & Strand (for SHS)',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _trackStrand = val.trim().isEmpty ? null : val.trim(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          width: 150,
          child: PrimaryButton(
            label: 'ENROLL',
            isLoading: _isLoading,
            onPressed: _handleSubmit,
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(studentMutationProvider.notifier).bulkEnroll(
            studentIds: widget.studentIds,
            academicYearId: _selectedAcademicYearId!,
            gradeLevel: _selectedGradeLevel!,
            sectionId: _selectedSectionId!,
            trackStrand: _trackStrand,
          );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to bulk enroll: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}