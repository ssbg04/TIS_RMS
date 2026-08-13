import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/student_model.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/student_provider.dart';
import '../documents/widgets/student_profile_modal.dart';
import 'widgets/add_student_modal.dart';
import 'widgets/edit_student_modal.dart';
import 'widgets/bulk_ocr_import_dialog.dart';
import '../../providers/setup_provider.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/archives_provider.dart';

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
  bool _isDragOver = false;
  Timer? _dragResetTimer;
  ProviderSubscription<String>? _tabListener;
  // Pending filter state (applied only when user taps "Apply now")
  String _pendingSchoolYear = 'All School Years';
  String _pendingGradeLevel = 'All Grades';
  String _pendingSection = 'All Sections';
  String _pendingStatus = 'All Status';
  String _pending4Ps = 'All'; // 'All', 'Yes', 'No'
  int _pendingLimit = 15;
  String _pendingSortBy = '';
  String _pendingSortOrder = '';

  static const _lrnSortItems = ['Default LRN Order', 'ASC', 'DESC'];
  static const _docStatusSortItems = [
    'Default Doc Status Order',
    'Low-High Attention',
    'High-Low Attention',
  ];

  static const _gradeLevels = ['All Grades', '7', '8', '9', '10', '11', '12'];
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

    // Sync initial search text if it was set externally (e.g. from Dashboard)
    final initialQuery = ref.read(studentQueryProvider).search;
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
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
        } else {
          // Sync search text if returning to Students tab with a pre-filled query
          final currentQuery = ref.read(studentQueryProvider).search;
          if (_searchController.text != currentQuery) {
            _searchController.text = currentQuery;
            if (mounted) setState(() {});
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _dragResetTimer?.cancel();
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
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => student == null
            ? const AddStudentModal()
            : EditStudentModal(student: student),
      ),
    );
    // For add: show success dialog here on students screen.
    // For edit: success dialog is shown inside EditStudentModal before popping,
    //           so we just return the result and let _viewProfile re-open the profile.
    if (result == true && mounted && student == null) {
      await showSuccessDialog(
        context,
        message: 'Student added successfully!',
      );
    }
    return result;
  }

  // ----------------------------------------------------------------
  // SHOW BULK OCR IMPORT DIALOG
  // ----------------------------------------------------------------
  Future<void> _openBulkOcrImport({List<File>? preloadedFiles}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BulkOcrImportDialog(preloadedFiles: preloadedFiles),
      ),
    );
  }

  // ── DRAG AND DROP WRAPPER (Windows only) ──────────────────────────────────
  Widget _buildDragDropWrapper(BuildContext context, {required Widget child}) {
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    if (!isWindows) return child;

    // Reset drag overlay if screen is no longer current active route or active tab
    final isActiveTab = ref.read(activeTabProvider) == 'Students';
    if (_isDragOver && (!isActiveTab || ModalRoute.of(context)?.isCurrent != true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isDragOver) {
          setState(() => _isDragOver = false);
        }
      });
    }

    return DropTarget(
      onDragEntered: (details) {
        _dragResetTimer?.cancel();
        if (ref.read(activeTabProvider) != 'Students') return;
        if (ModalRoute.of(context)?.isCurrent == true) {
          setState(() => _isDragOver = true);
        }
        // Safety auto-reset timer in case Windows OS swallows dragExit event
        _dragResetTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _isDragOver) {
            setState(() => _isDragOver = false);
          }
        });
      },
      onDragExited: (details) {
        _dragResetTimer?.cancel();
        if (mounted) {
          setState(() => _isDragOver = false);
        }
      },
      onDragDone: (details) {
        _dragResetTimer?.cancel();
        if (mounted) {
          setState(() => _isDragOver = false);
        }
        if (ref.read(activeTabProvider) != 'Students') return;
        if (ModalRoute.of(context)?.isCurrent != true) return;
        final validFiles = details.files.where((xfile) {
          final ext = xfile.path.toLowerCase();
          return ext.endsWith('.pdf') ||
              ext.endsWith('.jpg') ||
              ext.endsWith('.jpeg') ||
              ext.endsWith('.png') ||
              ext.endsWith('.xlsx') ||
              ext.endsWith('.xls') ||
              ext.endsWith('.csv');
        }).map((x) => File(x.path)).toList();

        if (validFiles.isNotEmpty) {
          _openBulkOcrImport(preloadedFiles: validFiles);
        }
      },
      child: Stack(
        children: [
          child,
          if (_isDragOver)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.primaryGreen,
                      width: 2.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 64,
                          color: AppColors.primaryGreen.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Drop files to import students',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PDF, JPG, PNG, XLSX supported',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryGreen.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // RIGHT-CLICK CONTEXT MENU (Windows)
  // ----------------------------------------------------------------
  Future<void> _showStudentContextMenu(
    BuildContext ctx,
    Offset globalPosition,
    StudentModel student,
  ) async {
    if (widget.userRole == 'teacher') return;
    final RenderBox overlay =
        Overlay.of(ctx).context.findRenderObject()! as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    final choice = await showMenu<String>(
      context: ctx,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: const [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryGreen),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'select',
          child: Row(
            children: const [
              Icon(Icons.check_box_outlined, size: 18, color: AppColors.primaryGreen),
              SizedBox(width: 10),
              Text('Select'),
            ],
          ),
        ),
      ],
    );
    if (!mounted) return;
    if (choice == 'edit') {
      await _openModal(student: student);
    } else if (choice == 'select') {
      setState(() {
        _showMultiSelect = true;
        if (!_selectedStudentIds.contains(student.id)) {
          _selectedStudentIds.add(student.id);
        }
      });
    }
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

  Widget _buildInlineMultiSelectHeader(List<StudentModel> allStudents) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = _selectedStudentIds.length;
    final allSelected = allStudents.isNotEmpty && count == allStudents.length;
    final buttonColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceCard
            : AppColors.primaryGreen.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Tooltip(
              message: 'Cancel selection',
              child: IconButton(
                icon: Icon(Icons.close, color: buttonColor),
                onPressed: () => setState(() {
                  _selectedStudentIds.clear();
                  _showMultiSelect = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count == 0 ? 'Select items' : '$count selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: allSelected ? 'Unselect All' : 'Select All',
              child: IconButton(
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  color: buttonColor,
                ),
                onPressed: allStudents.isEmpty
                    ? null
                    : () => _toggleSelectAll(allStudents),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 1,
              height: 24,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Enroll',
              child: IconButton(
                icon: Icon(Icons.group_add_rounded, color: buttonColor),
                onPressed: count == 0 ? null : _showBulkEnrollModal,
              ),
            ),
            Tooltip(
              message: 'Graduate',
              child: IconButton(
                icon: Icon(Icons.school_rounded, color: buttonColor),
                onPressed: count == 0 ? null : _showBulkGraduateConfirm,
              ),
            ),
            Tooltip(
              message: 'Transfer',
              child: IconButton(
                icon: Icon(
                  Icons.transfer_within_a_station_rounded,
                  color: buttonColor,
                ),
                onPressed: count == 0
                    ? null
                    : () => _showBulkChangeStatusConfirm(
                        'Transferred',
                        allStudents,
                      ),
              ),
            ),
            Tooltip(
              message: 'Drop',
              child: IconButton(
                icon: Icon(Icons.person_off_rounded, color: buttonColor),
                onPressed: count == 0
                    ? null
                    : () =>
                        _showBulkChangeStatusConfirm('Dropped', allStudents),
              ),
            ),
            Tooltip(
              message: 'Inactive',
              child: IconButton(
                icon: Icon(
                  Icons.do_not_disturb_on_total_silence_rounded,
                  color: buttonColor,
                ),
                onPressed: count == 0
                    ? null
                    : () =>
                        _showBulkChangeStatusConfirm('Inactive', allStudents),
              ),
            ),
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
          showSuccessDialog(
            context,
            message: 'Students successfully enrolled.',
          );
        },
      ),
    );
  }

  void _showBulkGraduateConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Graduate'),
        content: Text(
          'Are you sure you want to change the status of ${_selectedStudentIds.length} selected student(s) to "Graduated"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('GRADUATE'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref
            .read(studentMutationProvider.notifier)
            .bulkGraduate(_selectedStudentIds);
        if (mounted) {
          setState(() {
            _selectedStudentIds.clear();
            _showMultiSelect = false;
          });
          showSuccessDialog(
            context,
            message: 'Students successfully graduated.',
          );
        }
      } catch (e) {
        if (mounted) {
          final errMsg = e.toString().replaceAll('Exception: ', '');
          showErrorDialog(context, 'Error', errMsg);
        }
      }
    }
  }

  void _showBulkChangeStatusConfirm(
    String newStatus,
    List<StudentModel> allStudents,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bulk $newStatus'),
        content: Text(
          'Are you sure you want to change the status of ${_selectedStudentIds.length} selected student(s) to "$newStatus"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'Dropped'
                  ? Colors.red
                  : Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(newStatus.toUpperCase()),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final selectedStudents = allStudents
            .where((s) => _selectedStudentIds.contains(s.id))
            .toList();
        await ref
            .read(studentMutationProvider.notifier)
            .bulkChangeStatus(selectedStudents, newStatus);
        if (mounted) {
          setState(() {
            _selectedStudentIds.clear();
            _showMultiSelect = false;
          });
          showSuccessDialog(
            context,
            message: 'Students successfully updated to $newStatus.',
          );
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
    final confirmController = TextEditingController();
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
                    'Are you sure you want to delete '
                    '"${student.listDisplayName}"? The student will be marked as inactive and securely stored.',
                  ),
                  const SizedBox(height: 16),
                  const Text('Please type "confirm" to delete:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    decoration: InputDecoration(
                      labelText: 'Type confirm',
                      errorText: errorMessage,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(ctx).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final text = confirmController.text.trim();
                          if (text.isEmpty) {
                            setState(() => errorMessage = 'Input is required');
                            return;
                          }
                          if (text.toLowerCase() != 'confirm') {
                            setState(
                              () => errorMessage = 'Please type "confirm"',
                            );
                            return;
                          }
                          Navigator.of(ctx).pop(true);
                        },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
        await ref
            .read(studentMutationProvider.notifier)
            .setStudentInactive(student.id, student);
        if (mounted) {
          showSuccessDialog(
            context,
            message: 'Student deleted but still stored and marked as inactive.',
          );
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
      onEditById: (currentId) async {
        Navigator.pop(context);
        final pageState = ref.read(studentPageProvider);
        final students = pageState.value?.students ?? [];
        final targetStudent = students.firstWhere(
          (s) => s.id == currentId,
          orElse: () => student,
        );
        await _openModal(student: targetStudent);
        if (mounted) {
          _viewProfile(targetStudent);
        }
      },
      onDeleteById: (currentId) {
        Navigator.pop(context);
        final pageState = ref.read(studentPageProvider);
        final students = pageState.value?.students ?? [];
        final targetStudent = students.firstWhere(
          (s) => s.id == currentId,
          orElse: () => student,
        );
        _confirmDelete(targetStudent);
      },
    );
  }

  void _openDocumentsFolder(StudentModel student) {
    if (student.status != 'Enrolled') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Student Not Enrolled'),
          content: Text(
            '${student.listDisplayName} is currently marked as ${student.status}. Would you like to navigate to the Archives screen to view their documents?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(activeTabProvider.notifier).setTab('Archives');
                Future.microtask(() {
                  if (mounted) {
                    ref
                        .read(openedArchiveFolderProvider.notifier)
                        .setFolder(
                          OpenedArchiveFolderData(
                            id: student.id,
                            name: student.listDisplayName,
                          ),
                        );
                  }
                });
              },
              child: const Text('PROCEED'),
            ),
          ],
        ),
      );
    } else {
      ref.read(activeTabProvider.notifier).setTab('Documents');
      Future.microtask(() {
        if (mounted) {
          ref
              .read(openedFolderProvider.notifier)
              .setFolder(
                OpenedFolderData(id: student.id, name: student.listDisplayName),
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
    final query = ref.watch(studentQueryProvider);
    final pageAsync = ref.watch(studentPageProvider);
    final activeCount = [
      query.schoolYear.isNotEmpty,
      query.gradeLevel.isNotEmpty,
      query.section.isNotEmpty,
      query.status.isNotEmpty,
      query.is4Ps.isNotEmpty,
      query.sortBy.isNotEmpty,
      query.limit != 20,
    ].where((v) => v).length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (ref.read(activeTabProvider) != 'Students') return;
        if (_showMultiSelect || _selectedStudentIds.isNotEmpty) {
          setState(() {
            _showMultiSelect = false;
            _selectedStudentIds.clear();
          });
          return;
        }
        ref.read(activeTabProvider.notifier).setTab('Dashboard');
      },
      child: _buildDragDropWrapper(
        context,
        child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:
          (widget.userRole == 'teacher' ||
              _showMultiSelect ||
              _searchFocusNode.hasFocus ||
              defaultTargetPlatform == TargetPlatform.windows)
          ? null
          : FloatingActionButton(
              heroTag: 'add_student_fab',
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: () => _openModal(),
              child: const Icon(Icons.person_add),
            ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header + Controls or Inline Multi-Select Header ──
                      if (_showMultiSelect)
                        _buildInlineMultiSelectHeader(
                          pageAsync.value?.students ?? [],
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSizes.p24,
                            right: AppSizes.p24,
                            top: AppSizes.p24,
                          ),
                          child: _buildHeaderControls(
                            context,
                            query,
                            ref,
                            activeCount,
                          ),
                        ),
                      const SizedBox(height: AppSizes.p24),

                      // ── Data Table / Cards ──
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.p24,
                                ),
                                child: pageAsync.when(
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  error: (err, _) =>
                                      _buildError(err.toString()),
                                  data: (page) {
                                    // Teacher with no active filters and 0 total means no sections assigned
                                    final hasNoSections =
                                        widget.userRole == 'teacher' &&
                                        query.search.isEmpty &&
                                        query.gradeLevel.isEmpty &&
                                        query.section.isEmpty &&
                                        query.status.isEmpty &&
                                        query.schoolYear.isEmpty &&
                                        page.total == 0;
                                    final sortedStudents = _sortStudents(
                                      page.students,
                                      query,
                                    );
                                    return LayoutBuilder(
                                      builder: (ctx, c) => c.maxWidth > 800
                                          ? _buildDesktopTable(
                                              sortedStudents,
                                              query,
                                              noSections: hasNoSections,
                                            )
                                          : _buildMobileCardList(
                                              sortedStudents,
                                              noSections: hasNoSections,
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Pagination ──
                pageAsync.maybeWhen(
                  data: (page) => _buildPagination(query, page),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
      ),),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 24),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                collapsible: false,
                hint: 'Search by LRN or name...',
                maxWidth: 600,
                onSubmitted: (value) {
                  Navigator.of(context).pop(); // Close dialog
                  _onSearchSubmitted(value);
                },
              ),
            ),
          ),
        );
      },
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  // ================================================================
  // HEADER + CONTROLS
  // ================================================================
  Widget _buildHeaderControls(
    BuildContext context,
    StudentQueryParams query,
    WidgetRef ref,
    int activeCount,
  ) {
    return LayoutBuilder(
      builder: (_, c) {
        final isDesktop = c.maxWidth > 800;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Students Directory',
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                query.search.isNotEmpty ? Icons.close : Icons.search,
                size: 28,
                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
              ),
              tooltip: query.search.isNotEmpty ? 'Clear Search' : 'Search Students',
              onPressed: () {
                if (query.search.isNotEmpty) {
                  _searchController.clear();
                  ref.read(studentQueryProvider.notifier).setSearch('');
                } else {
                  _showSearchDialog(context);
                }
              },
            ),
            ...[
              if (widget.userRole != 'teacher' &&
                  defaultTargetPlatform != TargetPlatform.android) ...[
                const SizedBox(width: 8),
                _buildMultiSelectToggle(true),
              ],
              const SizedBox(width: 8),
              // "Add" + "Bulk Add" buttons for Windows (replaces FAB)
              if (defaultTargetPlatform == TargetPlatform.windows &&
                  widget.userRole != 'teacher') ...[
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _openBulkOcrImport,
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Bulk Add', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => _openModal(),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Filter icon (icon only, no background)
              IconButton(
                onPressed: () => _openFilterDialog(
                  query,
                  ref.read(academicYearsListProvider),
                  ref.read(sectionsListProvider),
                ),
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text(activeCount.toString()),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
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
      _pendingSchoolYear = query.schoolYear.isEmpty
          ? 'All School Years'
          : query.schoolYear;
      _pendingGradeLevel = query.gradeLevel.isEmpty
          ? 'All Grades'
          : query.gradeLevel;
      _pendingSection = query.section.isEmpty ? 'All Sections' : query.section;
      _pendingStatus = query.status.isEmpty ? 'All Status' : query.status;
      _pending4Ps = query.is4Ps.isEmpty
          ? 'All'
          : (query.is4Ps == 'true' ? 'Yes' : 'No');
      _pendingSortBy = query.sortBy;
      _pendingSortOrder = query.sortOrder;
      _pendingLimit = query.limit;
    });

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: MediaQuery.of(context).size.height < 600 ? 16 : 40,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
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
      child: IconButton(
        onPressed: () {
          setState(() {
            _showMultiSelect = !_showMultiSelect;
            if (!_showMultiSelect) _selectedStudentIds.clear();
          });
        },
        icon: Icon(
          _showMultiSelect
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          color: _showMultiSelect
              ? AppColors.primaryGreen
              : AppColors.textSecondary,
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
    final syItems =
        academicYearsAsync.whenOrNull(
          data: (years) => [
            'All School Years',
            ...(years as List).map((y) => y.yearRange as String),
          ],
        ) ??
        ['All School Years'];

    final sectionItems =
        sectionsAsync.whenOrNull(
          data: (sections) {
            final filteredSections = (sections as List).where((s) {
              if (_pendingGradeLevel != 'All Grades' &&
                  s.gradeLevel.toString() != _pendingGradeLevel)
                return false;
              if (_pendingSchoolYear != 'All School Years' &&
                  s.academicYearRange != _pendingSchoolYear)
                return false;
              return true;
            });
            final raw = [
              'All Sections',
              ...filteredSections.map((s) => s.name as String),
            ];
            return raw.toSet().toList();
          },
        ) ??
        ['All Sections'];

    // Precompute counts for badges
    final Map<String, int> syGradeCount = {};
    if (academicYearsAsync.value != null && sectionsAsync.value != null) {
      final sList = sectionsAsync.value as List;
      for (final sy in syItems.skip(1)) {
        syGradeCount[sy] = sList
            .where((s) => s.academicYearRange == sy)
            .map((s) => s.gradeLevel)
            .toSet()
            .length;
      }
    }

    final Map<String, int> gradeSectionCount = {};
    if (sectionsAsync.value != null) {
      final sList = sectionsAsync.value as List;
      for (final grade in _gradeLevels.skip(1)) {
        gradeSectionCount[grade] = sList.where((s) {
          final matchGrade = s.gradeLevel.toString() == grade;
          final matchSy =
              _pendingSchoolYear == 'All School Years' ||
              s.academicYearRange == _pendingSchoolYear;
          return matchGrade && matchSy;
        }).length;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
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
                const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 20, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),

          // Scrollable middle section for filter items
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LRN Sort
                  _buildFilterSection(
                    label: 'LRN',
                    onReset: () => setDialogState(() {
                      if (_pendingSortBy == 'lrn') {
                        _pendingSortBy = '';
                        _pendingSortOrder = '';
                      }
                    }),
                    child: _buildFilterChipGroup(
                      items: _lrnSortItems,
                      selectedValue:
                          (_pendingSortBy == 'lrn' &&
                                  _pendingSortOrder == 'asc')
                              ? 'ASC'
                              : ((_pendingSortBy == 'lrn' &&
                                      _pendingSortOrder == 'desc')
                                  ? 'DESC'
                                  : 'Default LRN Order'),
                      onSelected: (v) => setDialogState(() {
                        if (v == 'ASC') {
                          _pendingSortBy = 'lrn';
                          _pendingSortOrder = 'asc';
                        } else if (v == 'DESC') {
                          _pendingSortBy = 'lrn';
                          _pendingSortOrder = 'desc';
                        } else {
                          if (_pendingSortBy == 'lrn') {
                            _pendingSortBy = '';
                            _pendingSortOrder = '';
                          }
                        }
                      }),
                    ),
                  ),

                  const Divider(height: 1, indent: 20, endIndent: 20),

                  // School Year
                  _buildFilterSection(
                    label: 'School Year',
                    onReset: () => setDialogState(() {
                      _pendingSchoolYear = 'All School Years';
                      _pendingSection = 'All Sections';
                    }),
                    child: _buildFilterDropdown(
                      value: syItems.contains(_pendingSchoolYear)
                          ? _pendingSchoolYear
                          : 'All School Years',
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
                      value: _gradeLevels.contains(_pendingGradeLevel)
                          ? _pendingGradeLevel
                          : 'All Grades',
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
                    onReset: () =>
                        setDialogState(() => _pendingSection = 'All Sections'),
                    child: _buildFilterDropdown(
                      value: sectionItems.contains(_pendingSection)
                          ? _pendingSection
                          : 'All Sections',
                      items: sectionItems,
                      hint: _pendingGradeLevel == 'All Grades'
                          ? 'Select Grade Level first'
                          : null,
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
                    onReset: () =>
                        setDialogState(() => _pendingStatus = 'All Status'),
                    child: _buildFilterChipGroup(
                      items: _statusItems.toList(),
                      selectedValue: _statusItems.contains(_pendingStatus)
                          ? _pendingStatus
                          : 'All Status',
                      onSelected: (v) => setDialogState(() => _pendingStatus = v),
                    ),
                  ),

                  const Divider(height: 1, indent: 20, endIndent: 20),

                  // 4Ps Beneficiary
                  _buildFilterSection(
                    label: '4Ps Beneficiary',
                    onReset: () => setDialogState(() => _pending4Ps = 'All'),
                    child: _buildFilterChipGroup(
                      items: _4psItems.toList(),
                      selectedValue: _4psItems.contains(_pending4Ps)
                          ? _pending4Ps
                          : 'All',
                      onSelected: (v) => setDialogState(() => _pending4Ps = v),
                    ),
                  ),

                  const Divider(height: 1, indent: 20, endIndent: 20),

                  // Doc Status
                  _buildFilterSection(
                    label: 'Doc Status Attention',
                    onReset: () => setDialogState(() {
                      if (_pendingSortBy == 'doc_status') {
                        _pendingSortBy = '';
                        _pendingSortOrder = '';
                      }
                    }),
                    child: _buildFilterChipGroup(
                      items: _docStatusSortItems,
                      selectedValue:
                          (_pendingSortBy == 'doc_status' &&
                                  _pendingSortOrder == 'asc')
                              ? 'Low-High Attention'
                              : ((_pendingSortBy == 'doc_status' &&
                                      _pendingSortOrder == 'desc')
                                  ? 'High-Low Attention'
                                  : 'Default Doc Status Order'),
                      onSelected: (v) => setDialogState(() {
                        if (v == 'Low-High Attention') {
                          _pendingSortBy = 'doc_status';
                          _pendingSortOrder = 'asc';
                        } else if (v == 'High-Low Attention') {
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

                  const Divider(height: 1, indent: 20, endIndent: 20),

                  // Items per Page
                  _buildFilterSection(
                    label: 'Items per Page',
                    onReset: () => setDialogState(() => _pendingLimit = 15),
                    child: _buildFilterChipGroup(
                      items: _pageSizes.map((s) => '$s per page').toList(),
                      selectedValue: _pageSizes.contains(_pendingLimit)
                          ? '$_pendingLimit per page'
                          : '15 per page',
                      onSelected: (v) {
                        final numVal = int.tryParse(v.split(' ')[0]) ?? 15;
                        setDialogState(() => _pendingLimit = numVal);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade200),

          // Footer buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                // Reset all
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _pendingSchoolYear = 'All School Years';
                        _pendingGradeLevel = 'All Grades';
                        _pendingSection = 'All Sections';
                        _pendingStatus = 'All Status';
                        _pending4Ps = 'All';
                        _pendingSortBy = '';
                        _pendingSortOrder = '';
                        _pendingLimit = 15;
                      });
                      final n = ref.read(studentQueryProvider.notifier);
                      n.setSchoolYear('');
                      n.setGradeLevel('');
                      n.setSection('');
                      n.setStatus('');
                      n.setIs4Ps('');
                      n.setLrn('');
                      n.setSort('', '');
                      n.setLimit(15);
                    },
                    child: const Text(
                      'Reset all',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final n = ref.read(studentQueryProvider.notifier);
                      n.setSchoolYear(
                        _pendingSchoolYear == 'All School Years'
                            ? ''
                            : _pendingSchoolYear,
                      );
                      n.setGradeLevel(
                        _pendingGradeLevel == 'All Grades'
                            ? ''
                            : _pendingGradeLevel,
                      );
                      n.setSection(
                        _pendingSection == 'All Sections'
                            ? ''
                            : _pendingSection,
                      );
                      n.setStatus(
                        _pendingStatus == 'All Status' ? '' : _pendingStatus,
                      );

                      String is4psVal = '';
                      if (_pending4Ps == 'Yes') is4psVal = 'true';
                      if (_pending4Ps == 'No') is4psVal = 'false';
                      n.setIs4Ps(is4psVal);
                      n.setSort(_pendingSortBy, _pendingSortOrder);
                      n.setLimit(_pendingLimit);

                      onApply();
                    },
                    child: const Text(
                      'Apply now',
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

  Widget _buildFilterSection({
    required String label,
    required VoidCallback onReset,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: enabled 
            ? (isDark ? AppColors.darkSurface2 : AppColors.surfaceWhite) 
            : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          isDense: true,
          dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
          style: TextStyle(
            fontSize: 14,
            color: enabled 
                ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary) 
                : AppColors.textMuted,
          ),
          hint: hint != null
              ? Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                )
              : null,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled 
                ? (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary) 
                : AppColors.textMuted,
            size: 20,
          ),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        i, 
                        style: TextStyle(
                          fontSize: 14, 
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      if (counts != null && counts[i] != null && counts[i]! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.1,
                            ),
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
                ),
              )
              .toList(),
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
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected 
                  ? AppColors.primaryGreen 
                  : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onSelected(item);
            }
          },
          selectedColor: AppColors.primaryGreen.withValues(alpha: 0.12),
          backgroundColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
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

  List<StudentModel> _sortStudents(
    List<StudentModel> rawStudents,
    StudentQueryParams query,
  ) {
    if (rawStudents.isEmpty || query.sortBy.isEmpty) {
      return List<StudentModel>.from(rawStudents);
    }
    final students = List<StudentModel>.from(rawStudents);
    if (query.sortBy == 'lrn') {
      students.sort((a, b) {
        final comp = a.lrn.compareTo(b.lrn);
        return query.sortOrder == 'desc' ? -comp : comp;
      });
    } else if (query.sortBy == 'name') {
      students.sort((a, b) {
        final compA = '${a.lastName} ${a.firstName}'.toLowerCase();
        final compB = '${b.lastName} ${b.firstName}'.toLowerCase();
        final comp = compA.compareTo(compB);
        return query.sortOrder == 'desc' ? -comp : comp;
      });
    } else if (query.sortBy == 'grade_section') {
      students.sort((a, b) {
        final gComp = (a.latestGradeLevel ?? 0).compareTo(
          b.latestGradeLevel ?? 0,
        );
        if (gComp != 0) {
          return query.sortOrder == 'desc' ? -gComp : gComp;
        }
        final sComp = (a.latestSection ?? '').toLowerCase().compareTo(
              (b.latestSection ?? '').toLowerCase(),
            );
        return query.sortOrder == 'desc' ? -sComp : sComp;
      });
    } else if (query.sortBy == 'doc_status') {
      students.sort((a, b) {
        final comp = a.missingDocumentsCount.compareTo(
          b.missingDocumentsCount,
        );
        return query.sortOrder == 'desc' ? -comp : comp;
      });
    }
    return students;
  }

  // ================================================================
  // DESKTOP DATA TABLE
  // ================================================================
  Widget _buildDesktopTable(
    List<StudentModel> rawStudents,
    StudentQueryParams query, {
    bool noSections = false,
  }) {
    if (rawStudents.isEmpty) return _buildEmptyState(noSections: noSections);

    List<StudentModel> students = _sortStudents(rawStudents, query);

    return LayoutBuilder(
      builder: (context, constraints) {
        DataCell buildHoverCell(Widget child, StudentModel student) {
          return DataCell(
            GestureDetector(
              onSecondaryTapDown: defaultTargetPlatform == TargetPlatform.windows
                  ? (details) => _showStudentContextMenu(
                        context,
                        details.globalPosition,
                        student,
                      )
                  : null,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Align(alignment: Alignment.centerLeft, child: child),
                ),
              ),
            ),
            onTap: () => _viewProfile(student),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              child: DataTable2(
                minWidth: 950,
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
                      label: defaultTargetPlatform == TargetPlatform.windows
                          ? const SizedBox.shrink()
                          : Checkbox(
                              activeColor: AppColors.primaryGreen,
                              value:
                                  students.isNotEmpty &&
                                  students.every(
                                    (s) => _selectedStudentIds.contains(s.id),
                                  ),
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
                  DataColumn2(
                    size: ColumnSize.M,
                    label: Row(
                      children: [
                        const Text(
                          'LRN',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onSelected: (val) {
                            ref
                                .read(studentQueryProvider.notifier)
                                .setSort(val.isEmpty ? '' : 'lrn', val);
                          },
                          itemBuilder: (ctx) => [
                            CheckedPopupMenuItem(
                              value: '',
                              checked: query.sortBy == 'lrn' && query.sortOrder == '',
                              child: const Text('None'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'asc',
                              checked: query.sortBy == 'lrn' && query.sortOrder == 'asc',
                              child: const Text('ASC'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'desc',
                              checked: query.sortBy == 'lrn' && query.sortOrder == 'desc',
                              child: const Text('DESC'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataColumn2(
                    size: ColumnSize.L,
                    label: Row(
                      children: [
                        const Text(
                          'Name',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onSelected: (val) {
                            ref
                                .read(studentQueryProvider.notifier)
                                .setSort(val.isEmpty ? '' : 'name', val);
                          },
                          itemBuilder: (ctx) => [
                            CheckedPopupMenuItem(
                              value: '',
                              checked: query.sortBy == 'name' && query.sortOrder == '',
                              child: const Text('None'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'asc',
                              checked: query.sortBy == 'name' && query.sortOrder == 'asc',
                              child: const Text('A-Z'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'desc',
                              checked: query.sortBy == 'name' && query.sortOrder == 'desc',
                              child: const Text('Z-A'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataColumn2(
                    size: ColumnSize.M,
                    label: Row(
                      children: [
                        const Text(
                          'Grade & Sec.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onSelected: (val) {
                            ref
                                .read(studentQueryProvider.notifier)
                                .setSort(val.isEmpty ? '' : 'grade_section', val);
                          },
                          itemBuilder: (ctx) => [
                            CheckedPopupMenuItem(
                              value: '',
                              checked: query.sortBy == 'grade_section' && query.sortOrder == '',
                              child: const Text('None'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'asc',
                              checked: query.sortBy == 'grade_section' && query.sortOrder == 'asc',
                              child: const Text('7-12 & A-Z'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'desc',
                              checked: query.sortBy == 'grade_section' && query.sortOrder == 'desc',
                              child: const Text('12-7 & Z-A'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataColumn2(
                    size: ColumnSize.S,
                    label: Row(
                      children: [
                        const Text(
                          '4Ps',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onSelected: (val) {
                            ref
                                .read(studentQueryProvider.notifier)
                                .setIs4Ps(val);
                          },
                          itemBuilder: (ctx) => [
                            CheckedPopupMenuItem(
                              value: '',
                              checked: query.is4Ps == '',
                              child: const Text('All'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'true',
                              checked: query.is4Ps == 'true',
                              child: const Text('Yes'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'false',
                              checked: query.is4Ps == 'false',
                              child: const Text('No'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataColumn2(
                    size: ColumnSize.M,
                    label: Row(
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onSelected: (val) {
                            ref
                                .read(studentQueryProvider.notifier)
                                .setStatus(val);
                          },
                          itemBuilder: (ctx) => [
                            CheckedPopupMenuItem(
                              value: '',
                              checked: query.status == '',
                              child: const Text('All Status'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'Enrolled',
                              checked: query.status == 'Enrolled',
                              child: const Text('Enrolled'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'Graduated',
                              checked: query.status == 'Graduated',
                              child: const Text('Graduated'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'Transferred',
                              checked: query.status == 'Transferred',
                              child: const Text('Transferred'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'Dropped',
                              checked: query.status == 'Dropped',
                              child: const Text('Dropped'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'Inactive',
                              checked: query.status == 'Inactive',
                              child: const Text('Inactive'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataColumn2(
                    size: ColumnSize.M,
                    label: Row(
                      children: [
                        const Text(
                          'Doc Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onSelected: (val) {
                            ref
                                .read(studentQueryProvider.notifier)
                                .setSort(val.isEmpty ? '' : 'doc_status', val);
                          },
                          itemBuilder: (ctx) => [
                            CheckedPopupMenuItem(
                              value: '',
                              checked: query.sortBy == 'doc_status' && query.sortOrder == '',
                              child: const Text('None'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'asc',
                              checked: query.sortBy == 'doc_status' && query.sortOrder == 'asc',
                              child: const Text('Low-High Attention'),
                            ),
                            CheckedPopupMenuItem(
                              value: 'desc',
                              checked: query.sortBy == 'doc_status' && query.sortOrder == 'desc',
                              child: const Text('High-Low Attention'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const DataColumn2(
                    size: ColumnSize.S,
                    label: Text(
                      'Action',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
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
                      buildHoverCell(
                        Text(
                          student.lrn,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        student,
                      ),
                      buildHoverCell(Text(student.listDisplayName), student),
                      buildHoverCell(Text(student.gradeSection), student),
                      buildHoverCell(
                        student.is4ps
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primaryGreen,
                                size: 20,
                              )
                            : const Icon(
                                Icons.cancel,
                                color: Colors.grey,
                                size: 20,
                              ),
                        student,
                      ),
                      buildHoverCell(
                        _StatusChip(status: student.status),
                        student,
                      ),
                      buildHoverCell(
                        _DocumentProgressBar(
                          missingCount: student.missingDocumentsCount,
                          totalCount: student.totalDocumentsCount,
                          missingDocuments: student.missingDocuments,
                        ),
                        student,
                      ),
                      DataCell(
                        _ActionButtons(
                          onOpenDocuments: () => _openDocumentsFolder(student),
                        ),
                      ),
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
  Widget _buildMobileCardList(
    List<StudentModel> students, {
    bool noSections = false,
  }) {
    if (students.isEmpty) return _buildEmptyState(noSections: noSections);

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async {
        ref.invalidate(studentPageProvider);
        // Wait for the provider to rebuild
        await ref.read(studentPageProvider.future);
      },
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, 0.02, 0.98, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: students.length,
          separatorBuilder: (ctx, index) => const SizedBox(height: AppSizes.p12),
          itemBuilder: (_, i) {
          final s = students[i];

          return GestureDetector(
            onSecondaryTapDown: defaultTargetPlatform == TargetPlatform.windows
                ? (details) => _showStudentContextMenu(
                      context,
                      details.globalPosition,
                      s,
                    )
                : null,
            child: InkWell(
              onTap: () {
        if (_showMultiSelect || _selectedStudentIds.isNotEmpty) {
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
              onLongPress: defaultTargetPlatform != TargetPlatform.windows &&
                      widget.userRole != 'teacher'
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
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : Colors.transparent),
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
                      backgroundColor: AppColors.primaryGreen.withValues(
                        alpha: 0.1,
                      ),
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
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                             if (s.is4ps) ...[
                               const Text(
                                 '4Ps',
                                 style: TextStyle(
                                   color: AppColors.primaryGreen,
                                   fontSize: 10,
                                   fontWeight: FontWeight.bold,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : Colors.grey.shade200),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: 14,
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
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
          ),
        );
      },
      ),
      ),
    );
  }

  // ================================================================
  // PAGINATION CONTROLS
  // ================================================================
  Widget _buildPagination(StudentQueryParams query, dynamic page) {
    if (_searchFocusNode.hasFocus) return const SizedBox.shrink();
    return AppPagination(
      currentPage: query.page,
      totalPages: page.totalPages as int,
      onPageChanged: (p) => ref.read(studentQueryProvider.notifier).setPage(p),
    );
  }

  Widget _buildEmptyState({bool noSections = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (noSections) {
      // Teacher has no sections assigned at all
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.class_outlined,
                size: 56,
                color: isDark ? Colors.orangeAccent : Colors.orange.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No sections assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no sections assigned to your account yet.\nContact your administrator to assign sections.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No students found.',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters.',
            style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    final clean = message.startsWith('Exception: ')
        ? message.substring(11)
        : message;
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
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = switch (status) {
      'Enrolled' => AppColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.10),
      'Graduated' => Colors.blue.withValues(alpha: isDark ? 0.25 : 0.10),
      'Transferred' => Colors.orange.withValues(alpha: isDark ? 0.25 : 0.10),
      'Dropped' => Colors.red.withValues(alpha: isDark ? 0.25 : 0.10),
      _ => isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
    };

    final fg = switch (status) {
      'Enrolled' => isDark ? Colors.green.shade300 : AppColors.primaryGreen,
      'Graduated' => isDark ? Colors.blue.shade300 : Colors.blue.shade700,
      'Transferred' => isDark ? Colors.orange.shade300 : Colors.orange.shade800,
      'Dropped' => isDark ? Colors.red.shade300 : Colors.red.shade700,
      _ => isDark ? AppColors.darkTextPrimary : Colors.grey.shade700,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          status,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int completedCount = (totalCount - missingCount).clamp(0, totalCount);

    // Prevent division by zero if totalCount is 0 (e.g. no requirements)
    final double progress = totalCount == 0 ? 1.0 : completedCount / totalCount;
    final bool isComplete = missingCount == 0 && totalCount > 0;

    String tooltipMessage = '';
    if (!isComplete && missingDocuments.isNotEmpty) {
      final jhsDocs = missingDocuments
          .where((d) => d.startsWith('[JHS]'))
          .map((d) => d.replaceFirst('[JHS] ', ''))
          .toList();
      final shsDocs = missingDocuments
          .where((d) => d.startsWith('[SHS]'))
          .map((d) => d.replaceFirst('[SHS] ', ''))
          .toList();
      final otherDocs = missingDocuments
          .where((d) => !d.startsWith('[JHS]') && !d.startsWith('[SHS]'))
          .toList();

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
                  color: isComplete
                      ? AppColors.primaryGreen
                      : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
              if (isComplete) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primaryGreen,
                  size: 14,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 100, // Fixed width to keep column formatting tidy
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              color: isComplete
                  ? AppColors.primaryGreen
                  : Colors.orange, // Orange indicates pending docs
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

  const _ActionButtons({required this.onOpenDocuments});

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
                        if (mounted)
                          setState(
                            () => _selectedAcademicYearId = years.first.id,
                          );
                      });
                    }
                    return DropdownButtonFormField<int>(
                      value: _selectedAcademicYearId,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      items: years
                          .map(
                            (y) => DropdownMenuItem<int>(
                              value: y.id,
                              child: Text(y.yearRange),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAcademicYearId = val;
                          _selectedSectionId = null;
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Academic year is required.' : null,
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  ),
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
                      items: grades
                          .map(
                            (g) => DropdownMenuItem<int>(
                              value: g.level,
                              child: Text(g.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedGradeLevel = val;
                          _selectedSectionId = null;
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Grade level is required.' : null,
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: AppSizes.p16),
                sectionsAsync.when(
                  data: (sections) {
                    final filtered = sections
                        .where(
                          (sec) =>
                              sec.academicYearId == _selectedAcademicYearId &&
                              sec.gradeLevel == _selectedGradeLevel,
                        )
                        .toList();

                    return DropdownButtonFormField<int>(
                      value: _selectedSectionId,
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        prefixIcon: Icon(Icons.segment),
                        border: OutlineInputBorder(),
                      ),
                      items: filtered
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedSectionId = val),
                      validator: (v) =>
                          v == null ? 'Section is required.' : null,
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Error: $e'),
                ),
                if (_selectedGradeLevel != null &&
                    _selectedGradeLevel! >= 11) ...[
                  const SizedBox(height: AppSizes.p16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Track & Strand (for SHS)',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _trackStrand = val.trim().isEmpty ? null : val.trim(),
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
          child: const Text(
            'CANCEL',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
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
      await ref
          .read(studentMutationProvider.notifier)
          .bulkEnroll(
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
      showErrorDialog(
        context,
        'Bulk Enrollment Failed',
        'Failed to bulk enroll: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
