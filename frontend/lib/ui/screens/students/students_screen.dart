import 'dart:async';
import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../domain/entities/student_model.dart';
import '../../../domain/entities/setup_models.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/student_provider.dart';
import '../documents/widgets/student_profile_modal.dart';
import 'widgets/add_student_modal.dart';
import 'widgets/edit_student_modal.dart';
import 'widgets/bulk_ocr_import_dialog.dart';
import 'widgets/student_filter_dialog.dart';
import '../../providers/setup_provider.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/archives_provider.dart';

import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/widgets/app_pagination.dart';
import '../../shared/widgets/app_error_state.dart';
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
  final FocusNode _shortcutFocusNode = FocusNode();
  Timer? _debounce;

  final List<int> _selectedStudentIds = [];
  bool _showMultiSelect = false;
  bool _isDragOver = false;
  Timer? _dragResetTimer;
  ProviderSubscription<String>? _tabListener;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Sync initial search text if it was set externally (e.g. from Dashboard)
      final initialQuery = ref.read(studentQueryProvider).search;
      if (initialQuery.isNotEmpty) {
        _searchController.text = initialQuery;
      }
      if (ref.read(activeTabProvider) == 'Students') {
        _shortcutFocusNode.requestFocus();
      }
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
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) {
              _shortcutFocusNode.requestFocus();
            }
          });
          // Invalidate setup providers so dropdowns and filters always have fresh data
          ref.invalidate(academicYearsListProvider);
          ref.invalidate(gradeLevelsListProvider);
          ref.invalidate(sectionsListProvider);
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
    _shortcutFocusNode.dispose();
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
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
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
                  child: const Text('DELETE'),
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
      if (widget.userRole == 'teacher') {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Inactive Record'),
            content: Text(
              '${student.listDisplayName} is currently marked as ${student.status}. Archived records are only accessible by Administrators.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _showSearchDialog(context);
        },
      },
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        child: PopScope(
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
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:
          (widget.userRole == 'teacher' ||
              _showMultiSelect ||
              _searchFocusNode.hasFocus)
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
                  data: (page) => page.totalPages > 1
                      ? _buildPagination(query, page)
                      : SizedBox(
                          height: (MediaQuery.of(context).size.width < 700 ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.android)
                              ? 76
                              : 16,
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
    ),
    ),
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
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

    if (mounted) {
      _shortcutFocusNode.requestFocus();
    }
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
            Tooltip(
              richMessage: query.search.isNotEmpty
                  ? const TextSpan(text: 'Clear Search')
                  : const TextSpan(
                      text: 'Search Students ',
                      children: [
                        TextSpan(
                          text: '(Ctrl+F)',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
              child: IconButton(
                icon: Icon(
                  query.search.isNotEmpty ? Icons.close : Icons.search,
                  size: 28,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
                onPressed: () {
                  if (query.search.isNotEmpty) {
                    _searchController.clear();
                    ref.read(studentQueryProvider.notifier).setSearch('');
                  } else {
                    _showSearchDialog(context);
                  }
                },
              ),
            ),
            ...[
              if (widget.userRole != 'teacher') ...[
                const SizedBox(width: 4),
                _buildMultiSelectToggle(true),
              ],
              const SizedBox(width: 4),
              // Filter icon (icon only, no background)
              IconButton(
                onPressed: () =>
                    StudentFilterDialog.show(context, query: query),
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text(activeCount.toString()),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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
                const SizedBox(width: 4),
              ],
            ],
          ],
        );
      },
    );
  }

  // ================================================================
  // MULTI-SELECT TOGGLE
  // ================================================================
  Widget _buildMultiSelectToggle(bool isIconOnly) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: _showMultiSelect ? 'Exit Multi-Select' : 'Multi-Select',
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          shadowColor: Colors.transparent,
        ),
        onPressed: () {
          setState(() {
            _showMultiSelect = !_showMultiSelect;
            if (!_showMultiSelect) _selectedStudentIds.clear();
          });
        },
        icon: Icon(
          Icons.checklist_rounded,
          size: 24,
          color: _showMultiSelect
              ? AppColors.primaryGreen
              : (isDark ? AppColors.darkTextPrimary : AppColors.textSecondary),
        ),
      ),
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
    } else if (query.sortBy == '4ps' || query.sortBy == 'is_4ps') {
      students.sort((a, b) {
        final aVal = a.is4ps ? 1 : 0;
        final bVal = b.is4ps ? 1 : 0;
        final comp = aVal.compareTo(bVal);
        return query.sortOrder == 'desc' ? -comp : comp;
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
        final headingColor = isDark
            ? Color.alphaBlend(
                AppColors.primaryGreen.withValues(alpha: 0.12),
                AppColors.darkSurfaceCard,
              )
            : Color.alphaBlend(
                AppColors.primaryGreen.withValues(alpha: 0.08),
                AppColors.surfaceWhite,
              );

        Widget buildSortableHeader(String label, String columnKey) {
          final isSorted = query.sortBy == columnKey;
          final isAsc = query.sortOrder == 'asc';
          final isDesc = query.sortOrder == 'desc';

          IconData iconData = Icons.unfold_more_rounded;
          Color iconColor = isDark ? AppColors.darkTextMuted : Colors.grey.shade400;

          if (isSorted && isAsc) {
            iconData = Icons.arrow_upward_rounded;
            iconColor = AppColors.primaryGreen;
          } else if (isSorted && isDesc) {
            iconData = Icons.arrow_downward_rounded;
            iconColor = AppColors.primaryGreen;
          }

          void toggleSort() {
            if (isSorted) {
              if (isAsc) {
                ref.read(studentQueryProvider.notifier).setSort(columnKey, 'desc');
              } else if (isDesc) {
                ref.read(studentQueryProvider.notifier).setSort('', '');
              } else {
                ref.read(studentQueryProvider.notifier).setSort(columnKey, 'asc');
              }
            } else {
              ref.read(studentQueryProvider.notifier).setSort(columnKey, 'asc');
            }
          }

          return InkWell(
            onTap: toggleSort,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSorted
                          ? AppColors.primaryGreen
                          : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    iconData,
                    size: 16,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          );
        }

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
                fixedTopRows: 1,
                minWidth: 950,
                columnSpacing: 12,
                horizontalMargin: 16,
                headingRowHeight: 52,
                headingRowColor: WidgetStateProperty.all(headingColor),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontSize: 13,
                ),
                showBottomBorder: true,
                isVerticalScrollBarVisible: true,
                isHorizontalScrollBarVisible: true,
                empty: _buildEmptyState(noSections: noSections),
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
                    label: buildSortableHeader('LRN', 'lrn'),
                  ),
                  DataColumn2(
                    size: ColumnSize.L,
                    label: buildSortableHeader('Name', 'name'),
                  ),
                  DataColumn2(
                    size: ColumnSize.M,
                    label: buildSortableHeader('Grade & Sec.', 'grade_section'),
                  ),
                  DataColumn2(
                    size: ColumnSize.S,
                    label: buildSortableHeader('4Ps', '4ps'),
                  ),
                  DataColumn2(
                    size: ColumnSize.M,
                    label: Row(
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: query.status.isNotEmpty
                                ? AppColors.primaryGreen
                                : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: query.status.isNotEmpty
                                ? AppColors.primaryGreen
                                : (isDark
                                    ? AppColors.darkTextPrimary
                                    : Colors.black87),
                          ),
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
                    label: buildSortableHeader('Doc Status', 'doc_status'),
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
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? const Color(0xFF8B8ED8)
                                          : AppColors.fourPs)
                                      .withValues(alpha: isDark ? 0.2 : 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (isDark
                                            ? const Color(0xFF8B8ED8)
                                            : AppColors.fourPs)
                                        .withValues(alpha: isDark ? 0.6 : 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: isDark
                                          ? const Color(0xFF8B8ED8)
                                          : AppColors.fourPs,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '4Ps',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF8B8ED8)
                                            : AppColors.fourPs,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : Colors.grey.shade500,
                                  ),
                                ),
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
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(sectionsListProvider);
        // Wait for the provider to rebuild
        await ref.read(studentPageProvider.future);
      },
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF8B8ED8)
                                          : AppColors.fourPs)
                                      .withValues(
                                    alpha: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 0.2
                                        : 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF8B8ED8)
                                            : AppColors.fourPs)
                                        .withValues(
                                      alpha: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? 0.6
                                          : 0.35,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '4Ps',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF8B8ED8)
                                        : AppColors.fourPs,
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
    return AppErrorState.fromError(
      error: message,
      onRetry: () => ref.invalidate(studentPageProvider),
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

    InlineSpan richMessage;
    if (!isComplete && missingDocuments.isNotEmpty) {
      final jhsDocs = missingDocuments
          .where((d) => d.toUpperCase().startsWith('[JHS]'))
          .map((d) => d.replaceFirst(RegExp(r'^\[JHS\]\s*', caseSensitive: false), '').trim())
          .toList();
      final shsDocs = missingDocuments
          .where((d) => d.toUpperCase().startsWith('[SHS]'))
          .map((d) => d.replaceFirst(RegExp(r'^\[SHS\]\s*', caseSensitive: false), '').trim())
          .toList();
      final otherDocs = missingDocuments
          .where((d) =>
              !d.toUpperCase().startsWith('[JHS]') &&
              !d.toUpperCase().startsWith('[SHS]'))
          .map((d) => d.trim())
          .toList();

      final spanChildren = <InlineSpan>[
        TextSpan(
          text: 'Missing Documents ($missingCount):\n',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
          ),
        ),
      ];

      if (jhsDocs.isNotEmpty) {
        spanChildren.add(
          TextSpan(
            text: '\nJHS Requirements:\n',
            style: TextStyle(
              color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        );
        for (final doc in jhsDocs) {
          spanChildren.add(
            TextSpan(
              text: '  • $doc\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          );
        }
      }

      if (shsDocs.isNotEmpty) {
        spanChildren.add(
          TextSpan(
            text: '\nSHS Requirements:\n',
            style: TextStyle(
              color: isDark ? const Color(0xFFB39DDB) : const Color(0xFF6A1B9A),
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        );
        for (final doc in shsDocs) {
          spanChildren.add(
            TextSpan(
              text: '  • $doc\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          );
        }
      }

      if (otherDocs.isNotEmpty) {
        if (jhsDocs.isNotEmpty || shsDocs.isNotEmpty) {
          spanChildren.add(
            TextSpan(
              text: '\nOther Requirements:\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          );
        }
        for (final doc in otherDocs) {
          spanChildren.add(
            TextSpan(
              text: '  • $doc\n',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          );
        }
      }

      richMessage = TextSpan(children: spanChildren);
    } else if (isComplete) {
      richMessage = TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: isDark ? const Color(0xFF76BA8A) : Colors.green.shade700,
              ),
            ),
          ),
          TextSpan(
            text: 'All documents completed',
            style: TextStyle(
              color: isDark ? const Color(0xFF76BA8A) : Colors.green.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      );
    } else {
      richMessage = TextSpan(
        text: 'No documents required',
        style: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          fontSize: 12,
        ),
      );
    }

    return Tooltip(
      richMessage: richMessage,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      preferBelow: false,
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(sectionsListProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsListProvider);
    final gradeLevelsAsync = ref.watch(gradeLevelsListProvider);
    final sectionsAsync = ref.watch(sectionsListProvider);

    final years = yearsAsync.value ?? [];
    final allGrades =
        List<GradeLevelModel>.from(gradeLevelsAsync.value ?? [])
          ..sort((a, b) => a.level.compareTo(b.level));
    final allSections = sectionsAsync.value ?? [];

    // 1. Determine active/effective Academic Year
    final activeYears =
        years.where((y) => y.status.toLowerCase() == 'active').toList();
    final defaultYearId = (activeYears.isNotEmpty
        ? activeYears.last
        : (years.isNotEmpty ? years.last : null))?.id;

    final effectiveYearId = _selectedAcademicYearId != null &&
            years.any((y) => y.id == _selectedAcademicYearId)
        ? _selectedAcademicYearId
        : defaultYearId;

    if (_selectedAcademicYearId != effectiveYearId && effectiveYearId != null) {
      _selectedAcademicYearId = effectiveYearId;
    }

    // 2. Determine available Grade Levels for the selected Academic Year
    final sectionsInYear = effectiveYearId != null
        ? allSections.where((s) => s.academicYearId == effectiveYearId).toList()
        : <SectionModel>[];

    List<GradeLevelModel> availableGrades;
    if (sectionsInYear.isNotEmpty) {
      final gradesInYear = sectionsInYear.map((s) => s.gradeLevel).toSet();
      availableGrades =
          allGrades.where((g) => gradesInYear.contains(g.level)).toList();
      if (availableGrades.isEmpty) {
        availableGrades = allGrades;
      }
    } else {
      availableGrades = allGrades;
    }

    // 3. Determine effective Grade Level
    int? effectiveGradeLevel;
    if (_selectedGradeLevel != null &&
        availableGrades.any((g) => g.level == _selectedGradeLevel)) {
      effectiveGradeLevel = _selectedGradeLevel;
    } else {
      effectiveGradeLevel = availableGrades.any((g) => g.level == 7)
          ? 7
          : (availableGrades.isNotEmpty ? availableGrades.first.level : null);
      _selectedGradeLevel = effectiveGradeLevel;
    }

    // 4. Determine available Sections
    final filteredSections =
        (effectiveYearId != null && effectiveGradeLevel != null)
            ? allSections
                .where((sec) =>
                    sec.academicYearId == effectiveYearId &&
                    sec.gradeLevel == effectiveGradeLevel)
                .toList()
            : <SectionModel>[];
    filteredSections.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    // 5. Determine effective Section
    int? effectiveSectionId;
    if (_selectedSectionId != null &&
        filteredSections.any((s) => s.id == _selectedSectionId)) {
      effectiveSectionId = _selectedSectionId;
    } else {
      effectiveSectionId = null;
      _selectedSectionId = null;
    }

    return AlertDialog(
      title: Text('Bulk Enroll ${widget.studentIds.length} Students'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: (yearsAsync.isLoading ||
                  gradeLevelsAsync.isLoading ||
                  sectionsAsync.isLoading)
              ? const Padding(
                  padding: EdgeInsets.all(AppSizes.p24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Academic Year
                      DropdownButtonFormField<int>(
                        key: ValueKey('bulk_enroll_ay_$effectiveYearId'),
                        initialValue: effectiveYearId,
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
                          ref.invalidate(academicYearsListProvider);
                          ref.invalidate(sectionsListProvider);
                          ref.invalidate(gradeLevelsListProvider);
                          setState(() {
                            _selectedAcademicYearId = val;
                            final yearSecs = val != null
                                ? allSections.where((s) => s.academicYearId == val).toList()
                                : <SectionModel>[];
                            final validGrades = yearSecs.isNotEmpty
                                ? allGrades
                                    .where((g) => yearSecs.any((s) => s.gradeLevel == g.level))
                                    .toList()
                                : allGrades;
                            if (!validGrades.any((g) => g.level == _selectedGradeLevel)) {
                              _selectedGradeLevel = validGrades.any((g) => g.level == 7)
                                  ? 7
                                  : (validGrades.isNotEmpty ? validGrades.first.level : null);
                            }
                            _selectedSectionId = null;
                            if (_selectedGradeLevel != null && _selectedGradeLevel! < 11) {
                              _trackStrand = null;
                            }
                          });
                        },
                        validator: (v) => (v == null && effectiveYearId == null)
                            ? 'Academic year is required.'
                            : null,
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Grade Level
                      DropdownButtonFormField<int>(
                        key: ValueKey('bulk_enroll_grade_${effectiveYearId}_$effectiveGradeLevel'),
                        initialValue: effectiveGradeLevel,
                        decoration: const InputDecoration(
                          labelText: 'Grade Level',
                          prefixIcon: Icon(Icons.grade),
                          border: OutlineInputBorder(),
                        ),
                        items: availableGrades
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
                            if (val != null && val < 11) {
                              _trackStrand = null;
                            }
                          });
                        },
                        validator: (v) => (v == null && effectiveGradeLevel == null)
                            ? 'Grade level is required.'
                            : null,
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Section
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                            'bulk_enroll_sec_${effectiveYearId}_${effectiveGradeLevel}_$effectiveSectionId'),
                        initialValue: effectiveSectionId,
                        decoration: InputDecoration(
                          labelText: 'Section',
                          prefixIcon: const Icon(Icons.segment),
                          border: const OutlineInputBorder(),
                          hintText: filteredSections.isEmpty
                              ? 'No sections available'
                              : 'Select section',
                        ),
                        items: filteredSections
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: filteredSections.isEmpty
                            ? null
                            : (val) =>
                                setState(() => _selectedSectionId = val),
                        validator: (v) => (v == null && effectiveSectionId == null)
                            ? 'Section is required.'
                            : null,
                      ),

                      // Track & Strand for SHS
                      if (effectiveGradeLevel != null &&
                          effectiveGradeLevel >= 11) ...[
                        const SizedBox(height: AppSizes.p16),
                        TextFormField(
                          key: ValueKey('bulk_enroll_strand_$effectiveGradeLevel'),
                          initialValue: _trackStrand,
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
