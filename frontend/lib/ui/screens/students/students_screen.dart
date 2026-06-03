import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/student_model.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/student_provider.dart';
import '../documents/documents_screen.dart';
import '../students/student_detail_screen.dart';
import 'widgets/add_edit_student_modal.dart';
import '../../providers/setup_provider.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/auth_provider.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  final String userRole;
  const StudentsScreen({super.key, this.userRole = 'teacher'});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _debounce;

  final List<int> _selectedStudentIds = [];
  bool _showMultiSelect = false;
  ProviderSubscription<String>? _tabListener;

  static const _gradeLevels = ['All Grades', '7', '8', '9', '10', '11', '12'];
  static const _statusItems = ['All Status', 'Enrolled', 'Graduated', 'Transferred', 'Dropped'];
  static const _pageSizes   = [10, 20, 50];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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
    _searchController.dispose();
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

  // ----------------------------------------------------------------
  // SHOW ADD / EDIT MODAL
  // ----------------------------------------------------------------
  void _openModal({StudentModel? student}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditStudentModal(student: student),
    );
    // result == true means success — list already refreshed by provider
    if (result == true && mounted) {
      // Provider already invalidated inside mutation notifier
    }
  }

  void _showBulkEnrollModal() {
    showDialog(
      context: context,
      builder: (context) => BulkEnrollDialog(
        studentIds: _selectedStudentIds,
        onSuccess: () {
          setState(() {
            _selectedStudentIds.clear();
          });
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Students successfully graduated.'), backgroundColor: AppColors.success));
          setState(() => _selectedStudentIds.clear());
        }
      } catch (e) {
        if (mounted) {
          final errMsg = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: AppColors.error));
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
                    '"${student.fullName}"? This cannot be undone.',
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:         Text('Student deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final raw = e.toString();
          final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // ----------------------------------------------------------------
  // NAVIGATION HELPERS
  // ----------------------------------------------------------------
  void _viewProfile(int studentId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudentDetailScreen(
        studentId: studentId,
        userRole: widget.userRole,
      ),
    ));
  }

  void _openDocumentsFolder(int studentId) {
    ref.read(openedFolderStudentIdProvider.notifier).setStudentId(studentId);
    ref.read(activeTabProvider.notifier).setTab('Documents');
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final query    = ref.watch(studentQueryProvider);
    final pageAsync = ref.watch(studentPageProvider);
    final isMobile = MediaQuery.of(context).size.width <= 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Floating Add Student button (mobile)
      floatingActionButton: (widget.userRole != 'teacher' && isMobile)
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              onPressed: () => _openModal(),
              child: const Icon(Icons.person_add),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header + Controls ──
              _buildHeaderControls(context, query, ref),
              const SizedBox(height: AppSizes.p24),

              // ── Data Table / Cards ──
              Expanded(
                child: pageAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGreen),
                  ),
                  error: (err, _) => _buildError(err.toString()),
                  data: (page) => LayoutBuilder(
                    builder: (ctx, c) => c.maxWidth > 800
                        ? _buildDesktopTable(page.students)
                        : _buildMobileCardList(page.students),
                  ),
                ),
              ),

              // ── Pagination ──
              const SizedBox(height: AppSizes.p16),
              pageAsync.maybeWhen(
                data:   (page) => _buildPagination(query, page),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // HEADER + CONTROLS
  // ================================================================
  Widget _buildHeaderControls(BuildContext context, StudentQueryParams query, WidgetRef ref) {
    final gradeValue = query.gradeLevel.isEmpty ? 'All Grades' : query.gradeLevel;
    final statusValue = query.status.isEmpty ? 'All Status' : query.status;
    final sectionValue = query.section.isEmpty ? 'All Sections' : query.section;
    final schoolYearValue = query.schoolYear.isEmpty ? 'All School Years' : query.schoolYear;

    final academicYearsAsync = ref.watch(academicYearsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

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
              // Desktop: show full button in header
              if (widget.userRole != 'teacher' && isDesktop)
                SizedBox(
                  width: 180,
                  child: PrimaryButton(
                    label: '+ ADD STUDENT',
                    onPressed: () => _openModal(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.p16),

          // Search bar (full width)
          AppSearchBar(
            controller: _searchController,
            hint: 'Search by LRN or name...',
            maxWidth: double.infinity,
          ),
          const SizedBox(height: AppSizes.p12),

          // Filter dropdown menu using MenuAnchor
          MenuAnchor(
            builder: (context, controller, child) {
              String filterLabel = 'Filter';
              List<String> activeFilters = [];
              if (gradeValue != 'All Grades') activeFilters.add(gradeValue);
              if (statusValue != 'All Status') activeFilters.add(statusValue);
              if (sectionValue != 'All Sections') activeFilters.add(sectionValue);
              if (schoolYearValue != 'All School Years') activeFilters.add(schoolYearValue);
              
              if (activeFilters.isNotEmpty) {
                filterLabel = activeFilters.join(', ');
              }

              return InkWell(
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(filterLabel, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            },
            menuChildren: [
              academicYearsAsync.when(
                data: (years) {
                  final items = ['All School Years', ...years.map((y) => y.yearRange)];
                  return SubmenuButton(
                    menuChildren: items.map((y) => MenuItemButton(
                      child: Text(y),
                      onPressed: () => ref.read(studentQueryProvider.notifier).setSchoolYear(y == 'All School Years' ? '' : y),
                    )).toList(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text('School Year'),
                    ),
                  );
                },
                loading: () => const MenuItemButton(child: Text('Loading School Years...')),
                error: (_, __) => const MenuItemButton(child: Text('Error loading SY')),
              ),
              SubmenuButton(
                menuChildren: schoolYearValue == 'All School Years'
                    ? [const MenuItemButton(onPressed: null, child: Text('Select School Year first', style: TextStyle(color: Colors.grey)))]
                    : _gradeLevels.map((g) => MenuItemButton(
                  child: Text(g),
                  onPressed: () => ref.read(studentQueryProvider.notifier).setGradeLevel(g == 'All Grades' ? '' : g),
                )).toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Grade Level', style: TextStyle(color: schoolYearValue == 'All School Years' ? Colors.grey : AppColors.textPrimary)),
                ),
              ),
              sectionsAsync.when(
                data: (sections) {
                  final items = ['All Sections', ...sections.map((s) => s.name)];
                  // To avoid duplicates if sections with same name exist across grades:
                  final uniqueItems = items.toSet().toList();
                  return SubmenuButton(
                    menuChildren: gradeValue == 'All Grades'
                        ? [const MenuItemButton(onPressed: null, child: Text('Select Grade Level first', style: TextStyle(color: Colors.grey)))]
                        : uniqueItems.map((s) => MenuItemButton(
                      child: Text(s),
                      onPressed: () => ref.read(studentQueryProvider.notifier).setSection(s == 'All Sections' ? '' : s),
                    )).toList(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text('Section', style: TextStyle(color: gradeValue == 'All Grades' ? Colors.grey : AppColors.textPrimary)),
                    ),
                  );
                },
                loading: () => const MenuItemButton(child: Text('Loading Sections...')),
                error: (_, __) => const MenuItemButton(child: Text('Error loading sections')),
              ),
              SubmenuButton(
                menuChildren: _statusItems.map((s) => MenuItemButton(
                  child: Text(s),
                  onPressed: () => ref.read(studentQueryProvider.notifier).setStatus(s == 'All Status' ? '' : s),
                )).toList(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Status'),
                ),
              ),
              // ── Multi-select toggle ──
              if (widget.userRole != 'teacher')
                MenuItemButton(
                  leadingIcon: Icon(
                    _showMultiSelect ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: _showMultiSelect ? AppColors.primaryGreen : AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showMultiSelect = !_showMultiSelect;
                      if (!_showMultiSelect) _selectedStudentIds.clear();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      _showMultiSelect ? 'Multi-Select: ON' : 'Multi-Select: OFF',
                      style: TextStyle(
                        color: _showMultiSelect ? AppColors.primaryGreen : AppColors.textPrimary,
                        fontWeight: _showMultiSelect ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          if (_selectedStudentIds.isNotEmpty && widget.userRole != 'teacher') ...[
            const SizedBox(height: AppSizes.p16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: isDesktop
                  ? Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSizes.p8,
                      runSpacing: AppSizes.p8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_box, color: AppColors.primaryGreen),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedStudentIds.length} students selected',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            PopupMenuButton<String>(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('BULK ACTIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                              onSelected: (value) {
                                if (value == 'enroll') {
                                  _showBulkEnrollModal();
                                } else if (value == 'graduate') {
                                  _showBulkGraduateConfirm();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'enroll',
                                  child: Row(children: [Icon(Icons.group_add, color: AppColors.primaryGreen, size: 18), SizedBox(width: 10), Text('Bulk Enroll', style: TextStyle(fontSize: 14))]),
                                ),
                                const PopupMenuItem(
                                  value: 'graduate',
                                  child: Row(children: [Icon(Icons.school, color: Colors.blue, size: 18), SizedBox(width: 10), Text('Bulk Graduate', style: TextStyle(fontSize: 14))]),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey,
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                              onPressed: () => setState(() => _selectedStudentIds.clear()),
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('CLEAR'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_box, color: AppColors.primaryGreen),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedStudentIds.length} students selected',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: PopupMenuButton<String>(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.bolt, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('BULK ACTIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ),
                                onSelected: (value) {
                                  if (value == 'enroll') {
                                    _showBulkEnrollModal();
                                  } else if (value == 'graduate') {
                                    _showBulkGraduateConfirm();
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'enroll',
                                    child: Row(children: [Icon(Icons.group_add, color: AppColors.primaryGreen, size: 18), SizedBox(width: 10), Text('Bulk Enroll', style: TextStyle(fontSize: 14))]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'graduate',
                                    child: Row(children: [Icon(Icons.school, color: Colors.blue, size: 18), SizedBox(width: 10), Text('Bulk Graduate', style: TextStyle(fontSize: 14))]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                foregroundColor: Colors.grey,
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                              onPressed: () => setState(() => _selectedStudentIds.clear()),
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('CLEAR'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ],
      );
    });
  }

  // ================================================================
  // DESKTOP DATA TABLE
  // ================================================================
  Widget _buildDesktopTable(List<StudentModel> students) {
    if (students.isEmpty) return _buildEmptyState();

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
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.primaryGreen.withValues(alpha: 0.06),
              ),
              dataRowMaxHeight: 56,
              columns: [
                if (widget.userRole != 'teacher' && _showMultiSelect)
                  DataColumn(
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
                const DataColumn(label: Text('LRN',           style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Name',          style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Grade & Sec.',  style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Status',        style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Missing Docs',  style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Actions',       style: TextStyle(fontWeight: FontWeight.bold))),
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
                    DataCell(Text(student.lrn, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(student.fullName)),
                    DataCell(Text(student.gradeSection)),
                    DataCell(_StatusChip(status: student.status)),
                    DataCell(_DocumentProgressBar(
                      missingCount: student.missingDocumentsCount,
                      totalCount: student.totalDocumentsCount,
                    )),
                    DataCell(_ActionButtons(
                      student:          student,
                      userRole:         widget.userRole,
                      onEdit:           () => _openModal(student: student),
                      onDelete:         () => _confirmDelete(student),
                      onViewProfile:    () => _viewProfile(student.id),
                      onOpenDocuments:  () => _openDocumentsFolder(student.id),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ),
  );
}

  // ================================================================
  // MOBILE CARD LIST
  // ================================================================
  Widget _buildMobileCardList(List<StudentModel> students) {
    if (students.isEmpty) return _buildEmptyState();

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

          return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // TOP ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    Expanded(
                      child: Text(
                        s.lrn,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSizes.p8),

                    Flexible(
                      child: _StatusChip(status: s.status),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.p8),

                // NAME
                Text(
                  s.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 2),

                // GRADE SECTION
                Text(
                  s.gradeSection,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.p12),
                  child: Divider(height: 1),
                ),

                // BOTTOM SECTION
                Wrap(
                  spacing: AppSizes.p12,
                  runSpacing: AppSizes.p12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Docs: ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        _DocumentProgressBar(
                          missingCount: s.missingDocumentsCount,
                          totalCount: s.totalDocumentsCount,
                        ),
                      ],
                    ),
                    _ActionButtons(
                      student: s,
                      userRole: widget.userRole,
                      onEdit: () => _openModal(student: s),
                      onDelete: () => _confirmDelete(s),
                      onViewProfile: () => _viewProfile(s.id),
                      onOpenDocuments: () => _openDocumentsFolder(s.id),
                    ),
                  ],
                ),
              ],
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
    final total      = page.total as int;
    final totalPages = page.totalPages as int;
    final current    = query.page;

    final from = total == 0 ? 0 : ((current - 1) * query.limit) + 1;
    final to   = (current * query.limit).clamp(0, total);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // keeps the right-aligned controls visible first
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Showing $from–$to of $total',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: AppSizes.p12),

          // First page
          _PaginationButton(
            icon:    Icons.first_page,
            enabled: current > 1,
            onTap:   () => ref.read(studentQueryProvider.notifier).setPage(1),
          ),
          // Prev
          _PaginationButton(
            icon:    Icons.chevron_left,
            enabled: current > 1,
            onTap:   () => ref.read(studentQueryProvider.notifier).setPage(current - 1),
          ),

          // Page number chips
          ...List.generate(totalPages, (i) => i + 1)
              .where((p) => (p - current).abs() <= 2)
              .map((p) => _PageChip(
                    page:    p,
                    current: current,
                    onTap:   () => ref.read(studentQueryProvider.notifier).setPage(p),
                  )),

          // Next
          _PaginationButton(
            icon:    Icons.chevron_right,
            enabled: current < totalPages,
            onTap:   () => ref.read(studentQueryProvider.notifier).setPage(current + 1),
          ),
          // Last page
          _PaginationButton(
            icon:    Icons.last_page,
            enabled: current < totalPages,
            onTap:   () => ref.read(studentQueryProvider.notifier).setPage(totalPages),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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

  const _DocumentProgressBar({
    required this.missingCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate how many documents are completed
    final int completedCount = (totalCount - missingCount).clamp(0, totalCount);
    
    // Prevent division by zero if totalCount is 0 (e.g. no requirements)
    final double progress = totalCount == 0 ? 1.0 : completedCount / totalCount;
    final bool isComplete = missingCount == 0 && totalCount > 0;

    return Column(
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
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final StudentModel student;
  final String       userRole;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewProfile;
  final VoidCallback onOpenDocuments;

  const _ActionButtons({
    required this.student,
    required this.userRole,
    required this.onEdit,
    required this.onDelete,
    required this.onViewProfile,
    required this.onOpenDocuments,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message:  'View Profile',
          child:    IconButton(
            icon:      const Icon(Icons.person, color: AppColors.primaryGreen),
            onPressed: onViewProfile,
          ),
        ),
        Tooltip(
          message:  'Open Documents Folder',
          child:    IconButton(
            icon:      const Icon(Icons.folder_open, color: Colors.orange),
            onPressed: onOpenDocuments,
          ),
        ),
        if (userRole != 'teacher') ...[
          Tooltip(
            message:  'Edit Student',
            child:    IconButton(
              icon:      const Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: onEdit,
            ),
          ),
          Tooltip(
            message:  'Delete Student',
            child:    IconButton(
              icon:      const Icon(Icons.delete, color: AppColors.error),
              onPressed: onDelete,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData     icon;
  final bool         enabled;
  final VoidCallback onTap;
  const _PaginationButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon:      Icon(icon, size: 20, color: enabled ? AppColors.primaryGreen : Colors.grey.shade300),
      onPressed: enabled ? onTap : null,
    );
  }
}

class _PageChip extends StatelessWidget {
  final int          page;
  final int          current;
  final VoidCallback onTap;
  const _PageChip({required this.page, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = page == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color:        isActive ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:       isActive ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            '$page',
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
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
                    return DropdownButtonFormField<int>(
                      value: _selectedAcademicYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      items: years.map((y) => DropdownMenuItem<int>(value: y.id, child: Text(y.yearRange))).toList(),
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