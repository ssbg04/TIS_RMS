import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/folder_model.dart';
import '../../shared/menus/profile_dropdown_menu.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/document_provider.dart';
import '../../providers/student_provider.dart';
import '../../shared/widgets/app_pagination.dart';
import '../../providers/navigation_provider.dart';

import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import 'widgets/file_folder_card.dart';
import 'widgets/upload_ocr_modal.dart';
import 'widgets/print_queue_modal.dart';
import 'widgets/student_profile_modal.dart';
import 'widgets/document_preview_modal.dart';
import 'widgets/recycle_bin_modal.dart';
import '../../../domain/entities/document_model.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  final String userRole;

  /// When set, the screen auto-filters to this student's documents
  final int? initialStudentId;

  const DocumentsScreen({
    super.key,
    this.userRole = 'teacher',
    this.initialStudentId,
  });

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isGridView = false;
  late final TabController _tabController;

  // --- Windows Explorer State Variables ---
  int? _openedFolderStudentId;
  String? _openedFolderName;

  // Filter values — kept in sync with provider
  String _selectedStatus = 'All Statuses';
  String _selectedDocumentType = 'All Types';
  String _selectedGradeLevel = 'All Grades';
  String _selectedSchoolYear = 'All Years';

  String _pendingStatus = 'All Statuses';
  String _pendingDocumentType = 'All Types';
  String _pendingGradeLevel = 'All Grades';
  String _pendingSchoolYear = 'All Years';

  // Cached doc type lists for filter expansion
  List<String> _jhsItems = [];
  List<String> _shsItems = [];

  // Selection states
  bool _isMultiSelectMode = false;
  final Set<int> _selectedDocumentIds = {};

  Timer? _pollingTimer;
  ProviderSubscription<String>? _tabListener;
  ProviderSubscription<OpenedFolderData?>? _folderListener;

  // Pagination for folders
  int _foldersPage = 1;
  final int _foldersPerPage = 20;

  @override
  void initState() {
    super.initState();
    // 2 tabs: 0=Folders, 1=Documents
    _tabController = TabController(length: 2, vsync: this);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        if (_tabController.index == 0) {
          ref.invalidate(foldersProvider);
          ref.invalidate(studentFoldersProvider);
        } else if (_tabController.index == 1) {
          ref.invalidate(documentPageProvider);
        }
      }
    });

    // If a specific student was passed, jump to Folders tab and open that folder
    final initialFolder = ref.read(openedFolderProvider);
    if (initialFolder != null) {
      _openedFolderStudentId = initialFolder.id;
      _openedFolderName = initialFolder.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(documentQueryProvider.notifier).setStudentId(initialFolder.id);
      });
    } else if (widget.initialStudentId != null) {
      _openedFolderStudentId = widget.initialStudentId;
      _openedFolderName = 'Student Documents';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(documentQueryProvider.notifier)
            .setStudentId(widget.initialStudentId);
      });
    }

    _tabController.addListener(() {
      // Refresh and reset states strictly when the tab transition has completed
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isMultiSelectMode = false;
          _selectedDocumentIds.clear();
        });

        _clearFilters();

        // Refresh data to keep UI real-time
        ref.invalidate(documentPageProvider);
        ref.invalidate(foldersProvider);
        ref.invalidate(studentFoldersProvider);
        ref.invalidate(trashDocumentsProvider);

        if (_tabController.index != 0 && _openedFolderStudentId != null) {
          setState(() {
            _openedFolderStudentId = null;
            _openedFolderName = null;
          });
          ref.read(openedFolderProvider.notifier).setFolder(null);
          ref.read(documentQueryProvider.notifier).setStudentId(null);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(documentQueryProvider.notifier).setPage(1);

      _tabListener = ref.listenManual<String>(activeTabProvider, (previous, next) {
        if (!mounted) return;
        if (next != 'Documents') {
          ref.read(openedFolderProvider.notifier).setFolder(null);
          setState(() {
            _openedFolderStudentId = null;
            _openedFolderName = null;
            _isMultiSelectMode = false;
            if (_searchController.text.isNotEmpty) _searchController.clear();
            _selectedDocumentIds.clear();
          });
          ref.read(documentQueryProvider.notifier).reset();
          if (mounted && _tabController.index != 0) {
            _tabController.index = 0;
          }
        }
      });

      _folderListener = ref.listenManual<OpenedFolderData?>(openedFolderProvider, (previous, current) {
        if (!mounted) return;
        if (current != null && current.id != _openedFolderStudentId) {
          setState(() {
            _openedFolderStudentId = current.id;
            _openedFolderName = current.name;
          });
          if (mounted && _tabController.index != 0) {
            _tabController.index = 0;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(documentQueryProvider.notifier).setStudentId(current.id);
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
    _folderListener?.close();
    _pollingTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _foldersPage = 1);
      ref.read(documentQueryProvider.notifier).setSearch(query);
    });
  }

  void _applyFilters() {
    setState(() => _foldersPage = 1);
    final n = ref.read(documentQueryProvider.notifier);
    n.setStatus(_selectedStatus);

    String docTypeFilter = '';
    if (_selectedDocumentType == 'All JHS') {
      docTypeFilter = _jhsItems.join(',');
    } else if (_selectedDocumentType == 'All SHS') {
      docTypeFilter = _shsItems.join(',');
    } else if (_selectedDocumentType != 'All Types') {
      docTypeFilter = _selectedDocumentType;
    }
    n.setDocumentType(docTypeFilter);

    n.setGradeLevel(
      _selectedGradeLevel == 'All Grades' ? '' : _selectedGradeLevel,
    );
    n.setSchoolYear(
      _selectedSchoolYear == 'All Years' ? '' : _selectedSchoolYear,
    );
  }

  void _clearFilters() {
    setState(() {
      _foldersPage = 1;
      _selectedStatus = 'All Statuses';
      _selectedDocumentType = 'All Types';
      _selectedGradeLevel = 'All Grades';
      _selectedSchoolYear = 'All Years';
      _searchController.clear();
    });
    ref.read(documentQueryProvider.notifier).reset();
    _applyFilters();
  }

  void _handleAction(String action, DocumentModel document) async {
    final documentId = document.id;
    final studentId = document.studentId;

    if (action == 'view_profile' && studentId != null) {
      showStudentProfileModal(
        context,
        studentId: studentId,
        userRole: widget.userRole,
      );
    } else if (action == 'delete') {
      _confirmDelete(documentId);
    } else if (action == 'queue') {
      try {
        await ref
            .read(printQueueMutationProvider.notifier)
            .addToQueue(documentId);
        if (!mounted) return;
        showSuccessDialog(context, message: 'Added to Print List.');
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString().replaceFirst('Exception: ', '');
        showErrorDialog(context, 'Failed to Add', msg);
      }
    } else if (action == 'copy') {
      try {
        await ref
            .read(documentMutationProvider.notifier)
            .copyDocument(documentId);
        if (!mounted) return;
        showSuccessDialog(context, message: 'Document copied.');
      } catch (e) {
        if (!mounted) return;
        showErrorDialog(context, 'Copy Failed', e.toString());
      }
    } else if (action == 'preview') {
      showDocumentPreview(context: context, document: document);
    } else if (action == 'download') {
      showSuccessDialog(context, message: 'Download started.');
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Document', style: TextStyle(color: AppColors.error)),
          ],
        ),
        content: const Text(
          'Are you sure you want to move this document to the Recycle Bin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(documentMutationProvider.notifier)
                    .deleteDocument(id);
                if (!mounted) return;
                showSuccessDialog(
                  context,
                  message: 'Document moved to Recycle Bin.',
                );
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Delete Failed', e.toString());
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // NEW FOLDER & BATCH ACTIONS HELPERS
  // ══════════════════════════════════════════════════════════════

  Future<void> _handleBatchPrint() async {
    try {
      await ref
          .read(documentMutationProvider.notifier)
          .bulkAddToPrintQueue(_selectedDocumentIds.toList());
      setState(() {
        _selectedDocumentIds.clear();
        _isMultiSelectMode = false;
      });
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Selected documents added to Print List.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Print Queue Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handleBatchCopy() async {
    try {
      await ref
          .read(documentMutationProvider.notifier)
          .bulkCopy(_selectedDocumentIds.toList());
      setState(() {
        _selectedDocumentIds.clear();
        _isMultiSelectMode = false;
      });
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Selected documents copied successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Copy Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handleBatchStatus(String status) async {
    try {
      await ref
          .read(documentMutationProvider.notifier)
          .bulkUpdateStatus(_selectedDocumentIds.toList(), status);
      setState(() {
        _selectedDocumentIds.clear();
        _isMultiSelectMode = false;
      });
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Status updated to "$status" for selected documents.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Status Update Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handleBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Delete Selected Documents',
                style: TextStyle(color: AppColors.error, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete these ${_selectedDocumentIds.length} documents?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(documentMutationProvider.notifier)
          .bulkDelete(_selectedDocumentIds.toList());
      setState(() {
        _selectedDocumentIds.clear();
        _isMultiSelectMode = false;
      });
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Selected documents deleted successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Delete Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Widget _buildBatchActionsBar() {
    final count = _selectedDocumentIds.length;
    final isAdmin = widget.userRole != 'teacher';
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;

    // ── Mobile: compact 2-row layout ─────────────────────────────
    if (isMobile) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: count + clear
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count == 0 ? 'Tap items to select' : '$count selected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: count == 0
                            ? AppColors.textSecondary
                            : AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedDocumentIds.clear();
                      _isMultiSelectMode = false;
                    }),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            // Row 2: action buttons
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _batchActionBtn(
                    icon: Icons.print_rounded,
                    label: 'Print',
                    color: AppColors.primaryGreen,
                    onTap: count == 0 ? () {} : _handleBatchPrint,
                  ),
                  _batchActionBtn(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    color: Colors.blue,
                    onTap: count == 0 ? () {} : _handleBatchCopy,
                  ),
                  _batchActionBtn(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Complete',
                    color: AppColors.success,
                    onTap: count == 0
                        ? () {}
                        : () => _handleBatchStatus('Completed'),
                  ),
                  _batchActionBtn(
                    icon: Icons.archive_outlined,
                    label: 'Archive',
                    color: Colors.orange,
                    onTap: count == 0
                        ? () {}
                        : () => _handleBatchStatus('Archived'),
                  ),
                  // Delete is always visible in mobile multi-select
                  _batchActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: AppColors.error,
                    onTap: count == 0 ? () {} : _handleBatchDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Desktop: single-row layout ───────────────────────────────
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count == 0
                  ? 'Tap items to select'
                  : '$count item${count > 1 ? 's' : ''} selected',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: count == 0
                    ? AppColors.textSecondary
                    : AppColors.primaryGreen,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              _selectedDocumentIds.clear();
              _isMultiSelectMode = false;
            }),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.print_rounded,
              color: AppColors.primaryGreen,
            ),
            tooltip: 'Add to Print List',
            onPressed: count == 0 ? null : _handleBatchPrint,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.blue),
            tooltip: 'Copy',
            onPressed: count == 0 ? null : _handleBatchCopy,
          ),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
            ),
            tooltip: 'Mark as Completed',
            onPressed: count == 0
                ? null
                : () => _handleBatchStatus('Completed'),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Colors.orange),
            tooltip: 'Archive',
            onPressed: count == 0
                ? null
                : () => _handleBatchStatus('Archived'),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              tooltip: 'Delete',
              onPressed: count == 0 ? null : _handleBatchDelete,
            ),
        ],
      ),
    );
  }

  /// Icon + label button used in the mobile batch actions row.
  Widget _batchActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docState = ref.watch(documentPageProvider);
    final query = ref.watch(documentQueryProvider);
    final requirementsAsync = ref.watch(documentRequirementsProvider);
    final academicYearsAsync = ref.watch(academicYearsProvider);
    final statusesAsync = ref.watch(documentStatusesProvider);
    final foldersAsync = ref.watch(foldersProvider);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final isStudentFiltered = query.studentId != null;
    final isFolderOpened = _openedFolderStudentId != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: (defaultTargetPlatform != TargetPlatform.windows &&
                _tabController.index != 2 &&
                !_isMultiSelectMode)
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left FAB: Print List
                    Badge(
                      label: Text('${ref.watch(printQueueProvider).value?.length ?? 0}'),
                      isLabelVisible: (ref.watch(printQueueProvider).value?.length ?? 0) > 0,
                      backgroundColor: AppColors.error,
                      offset: const Offset(4, -4),
                      child: FloatingActionButton(
                        heroTag: 'fab-print-list',
                        backgroundColor: AppColors.primaryGreen,
                        shape: const CircleBorder(),
                        onPressed: () {
                          PrintQueueModal.show(context);
                        },
                        child: const Icon(Icons.print, color: Colors.white),
                      ),
                    ),
                    // Right FAB: Upload Document
                    if (_tabController.index == 1 || isFolderOpened)
                      FloatingActionButton(
                        heroTag: 'fab-upload-doc',
                        backgroundColor: AppColors.primaryGreen,
                        shape: const CircleBorder(),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => UploadOcrModal(
                              prefilledStudentId: _openedFolderStudentId ?? widget.initialStudentId,
                            ),
                          );
                        },
                        child: const Icon(Icons.cloud_upload, color: Colors.white),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              )
            : null,
        bottomNavigationBar: _isMultiSelectMode
            ? _buildBatchActionsBar()
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header ──
              _buildTopHeader(
                isMobile,
                isStudentFiltered,
                query,
                isFolderOpened,
                requirementsAsync,
                academicYearsAsync,
                statusesAsync,
              ),

              // ── TabBar ──
              Container(
                color: AppColors.surfaceWhite,
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    // Only run reset behavior if tapping the already active tab
                    if (index == _tabController.index) {
                      if (index == 0 && _openedFolderStudentId != null) {
                        setState(() {
                          _openedFolderStudentId = null;
                          _openedFolderName = null;
                        });
                        ref
                            .read(openedFolderProvider.notifier)
                            .setFolder(null);
                        ref
                            .read(documentQueryProvider.notifier)
                            .setStudentId(null);
                        _clearFilters();
                        ref.invalidate(documentPageProvider);
                        ref.invalidate(foldersProvider);
                        ref.invalidate(studentFoldersProvider);
                      }
                    }
                  },
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryGreen,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.folder, size: 18),
                      text: 'Student Folders',
                    ),
                    Tab(
                      icon: Icon(Icons.description, size: 18),
                      text: 'All Documents',
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Tab Body ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                    children: [
                    // Tab 0: Student Folders
                    _buildFoldersTab(
                      foldersAsync,
                      docState,
                      query,
                      isMobile,
                      screenW,
                    ),

                    // Tab 1: All Documents
                    Column(
                      children: [
                        Expanded(
                          child: docState.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            error: (e, _) => _buildErrorState(e.toString()),
                            data: (pageData) => pageData.documents.isEmpty
                                ? _buildEmptyState()
                                : _isGridView
                                ? _buildGridView(pageData.documents, pageData.totalPages, query.page)
                                : _buildListView(pageData.documents, pageData.totalPages, query.page),
                          ),
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
  }

  // ══════════════════════════════════════════════════════════════
  // TOP HEADER
  // ══════════════════════════════════════════════════════════════
  Widget _buildTopHeader(
    bool isMobile,
    bool isStudentFiltered,
    DocumentQueryParams query,
    bool isFolderOpened,
    AsyncValue<List<dynamic>> requirementsAsync,
    AsyncValue<List<dynamic>> academicYearsAsync,
    AsyncValue<List<String>> statusesAsync,
  ) {
    final hPad = isMobile ? 12.0 : 20.0;

    return Container(
      color: AppColors.surfaceWhite,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title + Action Buttons row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back / folder icon
              IconButton(
                icon: Icon(
                  isFolderOpened
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.folder_open_rounded,
                  size: 20,
                ),
                color: AppColors.primaryGreen,
                tooltip: isFolderOpened ? 'Back to Folders' : null,
                onPressed: isFolderOpened
                    ? () {
                        setState(() {
                          _openedFolderStudentId = null;
                          _openedFolderName = null;
                        });
                        ref
                            .read(openedFolderProvider.notifier)
                            .setFolder(null);
                        ref
                            .read(documentQueryProvider.notifier)
                            .setStudentId(null);
                      }
                    : null,
              ),
              const SizedBox(width: 6),

              // Screen title
              Expanded(
                child: _openedFolderName != null
                    ? Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _openedFolderStudentId = null;
                                _openedFolderName = null;
                              });
                              ref
                                  .read(openedFolderProvider.notifier)
                                  .setFolder(null);
                              ref
                                  .read(documentQueryProvider.notifier)
                                  .setStudentId(null);
                            },
                            child: Text(
                              'Student Folders',
                              style: TextStyle(
                                fontSize: isMobile ? 17 : 21,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            ' / ',
                            style: TextStyle(
                              fontSize: isMobile ? 17 : 21,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _openedFolderName!,
                              style: TextStyle(
                                fontSize: isMobile ? 17 : 21,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _tabController.index == 0
                            ? 'Student Folders'
                            : _tabController.index == 1
                                ? (isStudentFiltered
                                    ? 'Student Documents'
                                    : 'All Documents')
                                : 'Recycle Bin',
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 21,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),

              // Clear student filter chip (compact)
              if (isStudentFiltered && !isFolderOpened) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: TextButton.icon(
                    onPressed: () => ref
                        .read(documentQueryProvider.notifier)
                        .setStudentId(null),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'All Students',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],

            ],
          ),

          const SizedBox(height: 10),

          // ── Search + Icon-controls row ──
          Row(
            children: [
              // Custom search bar (expands to fill available width)
              Expanded(
                child: AppSearchBar(
                  hint: 'Search by name, LRN, file…',
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  maxWidth: double.infinity,
                ),
              ),
              const SizedBox(width: 8),

              if (!_searchFocusNode.hasFocus) ...[
                // Filter button
                if (_tabController.index == 1 || isFolderOpened) ...[
                  SizedBox(
                    height: 42,
                    child: Tooltip(
                      message: 'Filter Documents',
                      child: InkWell(
                        onTap: () => _openFilterDialog(
                          requirementsAsync,
                          academicYearsAsync,
                          statusesAsync,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Badge(
                                isLabelVisible: _getActiveFilterCount() > 0,
                                label: Text(_getActiveFilterCount().toString()),
                                child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryGreen),
                              ),
                              if (!isMobile) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  'Filter',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Multi-select toggle (Documents tab, opened folder, or Recycle Bin)
                if (_tabController.index == 1 || isFolderOpened) ...[
                  _buildMultiSelectToggle(isMobile),
                  const SizedBox(width: 8),
                ],
                
                // Desktop action buttons (Upload available to all roles)
                if (!isMobile && _tabController.index != 2) ...[
                  SizedBox(height: 42, child: _buildPrintQueueButton()),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    width: 120,
                    child: PrimaryButton(
                      label: 'UPLOAD',
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => UploadOcrModal(
                          prefilledStudentId:
                              _openedFolderStudentId ?? widget.initialStudentId,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Dropdown Menu
                SizedBox(height: 42, child: _buildMoreOptionsDropdown(isMobile)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedStatus != 'All Statuses') count++;
    if (_selectedDocumentType != 'All Types') count++;
    if (_selectedGradeLevel != 'All Grades') count++;
    if (_selectedSchoolYear != 'All Years') count++;
    return count;
  }


  Widget _buildMultiSelectToggle(bool isIconOnly) {
    return Tooltip(
      message: 'Toggle Multi-Select',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isMultiSelectMode = !_isMultiSelectMode;
            if (!_isMultiSelectMode) {
              _selectedDocumentIds.clear();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(
            horizontal: isIconOnly ? 12 : 14,
            vertical: 8,
          ),
          height: 42,
          decoration: BoxDecoration(
            color: _isMultiSelectMode
                ? AppColors.primaryGreen.withValues(alpha: 0.08)
                : AppColors.surfaceWhite,
            border: Border.all(
              color: _isMultiSelectMode
                  ? AppColors.primaryGreen
                  : Colors.grey.shade300,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isMultiSelectMode
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 16,
                color: _isMultiSelectMode
                    ? AppColors.primaryGreen
                    : AppColors.textSecondary,
              ),
              if (!isIconOnly) ...[
                const SizedBox(width: 6),
                Text(
                  'Select',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isMultiSelectMode
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsDropdown(bool isMobile) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      tooltip: 'More Options',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'grid_list') {
          setState(() => _isGridView = !_isGridView);
        } else if (value == 'recycle_bin') {
          showDialog(
            context: context,
            builder: (_) => const RecycleBinModal(),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'grid_list',
          child: Row(
            children: [
              Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _isGridView ? 'Switch to List' : 'Switch to Grid',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'recycle_bin',
          child: Row(
            children: [
              Icon(
                Icons.delete_sweep,
                size: 20,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                'Recycle Bin',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildPrintQueueButton({bool compact = false}) {
    final queueAsync = ref.watch(printQueueProvider);
    final count = queueAsync.maybeWhen(
      data: (items) => items.length,
      orElse: () => 0,
    );

    return Tooltip(
      message: 'Print List',
      child: OutlinedButton.icon(
        onPressed: () => PrintQueueModal.show(context),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count.toString()),
          child: const Icon(Icons.print, size: 18),
        ),
        label: compact
            ? const SizedBox.shrink()
            : Text(count > 0 ? 'Print List ($count)' : 'Print List'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.grey.shade300),
          padding: compact
              ? const EdgeInsets.all(10)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // FILTER MODAL
  // ══════════════════════════════════════════════════════════════
  void _openFilterDialog(
    AsyncValue<List<dynamic>> requirementsAsync,
    AsyncValue<List<dynamic>> academicYearsAsync,
    AsyncValue<List<String>> statusesAsync,
  ) {
    setState(() {
      _pendingStatus = _selectedStatus;
      _pendingDocumentType = _selectedDocumentType;
      _pendingGradeLevel = _selectedGradeLevel;
      _pendingSchoolYear = _selectedSchoolYear;
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
                requirementsAsync,
                academicYearsAsync,
                statusesAsync,
                setDialogState,
                () {
                  setState(() {
                    _selectedStatus = _pendingStatus;
                    _selectedDocumentType = _pendingDocumentType;
                    _selectedGradeLevel = _pendingGradeLevel;
                    _selectedSchoolYear = _pendingSchoolYear;
                  });
                  _applyFilters();
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPanelContent(
    AsyncValue<List<dynamic>> requirementsAsync,
    AsyncValue<List<dynamic>> academicYearsAsync,
    AsyncValue<List<String>> statusesAsync,
    StateSetter setDialogState,
    VoidCallback onApply,
  ) {
    final statusItems = statusesAsync.when(
      data: (s) => ['All Statuses', ...s],
      loading: () => const ['All Statuses'],
      error: (_, st) => const ['All Statuses'],
    );
    final jhsReqs = requirementsAsync.when(
      data: (reqs) => [
        'All JHS',
        ...reqs
            .where((r) => r.category == 'JHS')
            .map((r) => r.name as String)
            .toSet()
            .toList()
          ..sort(),
      ],
      loading: () => ['All JHS'],
      error: (err, stack) => ['All JHS'],
    );
    final shsReqs = requirementsAsync.when(
      data: (reqs) => [
        'All SHS',
        ...reqs
            .where((r) => r.category == 'SHS')
            .map((r) => r.name as String)
            .toSet()
            .toList()
          ..sort(),
      ],
      loading: () => ['All SHS'],
      error: (err, stack) => ['All SHS'],
    );
    final years = academicYearsAsync.when(
      data: (y) => ['All Years', ...y.map((ay) => ay.yearRange as String)],
      loading: () => ['All Years'],
      error: (err, stack) => ['All Years'],
    );

    final jhsItems = jhsReqs.where((e) => e != 'All JHS').toList();
    final shsItems = shsReqs.where((e) => e != 'All SHS').toList();

    // Cache for use in _applyFilters
    if (jhsItems.isNotEmpty) _jhsItems = jhsItems;
    if (shsItems.isNotEmpty) _shsItems = shsItems;

    final docTypeOptions = [
      'All Types',
      'All JHS',
      'All SHS',
      ...jhsItems,
      ...shsItems
    ];

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
                  'Filter Documents',
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

          // Status
          _buildFilterSection(
            label: 'Status',
            onReset: () => setDialogState(() => _pendingStatus = 'All Statuses'),
            child: _buildFilterDropdown(
              value: statusItems.contains(_pendingStatus) ? _pendingStatus : 'All Statuses',
              items: statusItems,
              onChanged: (v) => setDialogState(() => _pendingStatus = v!),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // Document Type
          _buildFilterSection(
            label: 'Document Type',
            onReset: () => setDialogState(() => _pendingDocumentType = 'All Types'),
            child: _buildFilterDropdown(
              value: docTypeOptions.contains(_pendingDocumentType) ? _pendingDocumentType : 'All Types',
              items: docTypeOptions,
              onChanged: (v) => setDialogState(() => _pendingDocumentType = v!),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // Grade Level
          _buildFilterSection(
            label: 'Grade Level',
            onReset: () => setDialogState(() => _pendingGradeLevel = 'All Grades'),
            child: _buildFilterDropdown(
              value: const ['All Grades', '7', '8', '9', '10', '11', '12'].contains(_pendingGradeLevel) ? _pendingGradeLevel : 'All Grades',
              items: const ['All Grades', '7', '8', '9', '10', '11', '12'],
              onChanged: (v) => setDialogState(() => _pendingGradeLevel = v!),
            ),
          ),

          const Divider(height: 1, indent: 20, endIndent: 20),

          // School Year
          _buildFilterSection(
            label: 'School Year',
            onReset: () => setDialogState(() => _pendingSchoolYear = 'All Years'),
            child: _buildFilterDropdown(
              value: years.contains(_pendingSchoolYear) ? _pendingSchoolYear : 'All Years',
              items: years,
              onChanged: (v) => setDialogState(() => _pendingSchoolYear = v!),
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
                        _pendingStatus = 'All Statuses';
                        _pendingDocumentType = 'All Types';
                        _pendingGradeLevel = 'All Grades';
                        _pendingSchoolYear = 'All Years';
                      });
                      _clearFilters();
                      Navigator.of(context).pop();
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
                    onPressed: onApply,
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
                    child: Text(i, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // FOLDERS TAB
  // ══════════════════════════════════════════════════════════════
  Widget _buildFoldersTab(
    AsyncValue<List<dynamic>> foldersAsync,
    AsyncValue<dynamic> docState,
    DocumentQueryParams query,
    bool isMobile,
    double screenW,
  ) {
    // If a folder is opened, show documents inline in this same tab
    if (_openedFolderStudentId != null) {
      return Column(
        children: [
          Expanded(
            child: docState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
              error: (e, _) => _buildErrorState(e.toString()),
              data: (pageData) {
                final hasNoSections = widget.userRole == 'teacher' &&
                    query.search.isEmpty &&
                    query.status.isEmpty &&
                    query.documentType.isEmpty &&
                    query.gradeLevel.isEmpty &&
                    query.schoolYear.isEmpty &&
                    pageData.total == 0;
                return pageData.documents.isEmpty
                    ? _buildEmptyState(noSections: hasNoSections)
                    : _isGridView
                        ? _buildGridView(pageData.documents, pageData.totalPages, query.page)
                        : _buildListView(pageData.documents, pageData.totalPages, query.page);
              },
            ),
          ),
        ],
      );
    }

    return foldersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (e, _) => _buildErrorState(e.toString()),
      data: (folders) {
        if (folders.isEmpty) {
          final hasNoSections = widget.userRole == 'teacher' &&
              query.search.isEmpty &&
              query.status.isEmpty &&
              query.documentType.isEmpty &&
              query.gradeLevel.isEmpty &&
              query.schoolYear.isEmpty;
          
          if (hasNoSections) {
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
                  const Text(
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
                Icon(
                  Icons.folder_off_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Student Folders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        bool isFuzzyMatch(String text, String search) {
          if (search.isEmpty) return true;
          int j = 0;
          for (int i = 0; i < text.length && j < search.length; i++) {
            if (text[i].toLowerCase() == search[j].toLowerCase()) {
              j++;
            }
          }
          return j == search.length;
        }

        final filteredFolders = query.search.isEmpty
            ? folders
            : folders.where((f) => isFuzzyMatch(f.name, query.search)).toList();

        final int totalPages = (filteredFolders.length / _foldersPerPage).ceil();
        final int startIndex = (_foldersPage - 1) * _foldersPerPage;
        final int endIndex = (startIndex + _foldersPerPage > filteredFolders.length)
            ? filteredFolders.length
            : startIndex + _foldersPerPage;
        final List<dynamic> paginatedFolders = filteredFolders.isEmpty ? [] : filteredFolders.sublist(startIndex, endIndex);

        if (!_isGridView) {
          return Column(
            children: [
              Expanded(
                child: Container(
            margin: EdgeInsets.all(isMobile ? 8 : 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  // Table header — hide progress column on mobile
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: 10,
                    ),
                    color: AppColors.primaryGreen.withValues(alpha: 0.06),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Folder Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (!isMobile)
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Requirement Progress',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: paginatedFolders.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (ctx, i) {
                        final folder = paginatedFolders[i];
                        return GestureDetector(
                          onSecondaryTapDown: (details) => _showFolderContextMenu(context, details.globalPosition, folder),
                          onLongPressStart: (details) => _showFolderContextMenu(context, details.globalPosition, folder),
                          child: InkWell(

                          onTap: () {
                            if (folder.studentId != null) {
                              setState(() {
                                _openedFolderStudentId = folder.studentId;
                                _openedFolderName = folder.name;
                              });
                              ref
                                  .read(documentQueryProvider.notifier)
                                  .setStudentId(folder.studentId);
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: isMobile ? 10 : 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.folder_rounded,
                                  size: 28,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                // On mobile: stack name + badges vertically
                                Expanded(
                                  child: isMobile
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              folder.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            _buildFolderCompletionBadge(folder),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                folder.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child:
                                                    _buildFolderCompletionBadge(
                                                      folder,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (totalPages > 1) _buildFoldersPagination(totalPages, _foldersPage),
      ],
    );
        }

        return LayoutBuilder(
          builder: (ctx, c) {
            // On mobile use 2 columns with a narrower tile width base
            final tileBase = isMobile ? 140.0 : 200.0;
            int cols = isMobile
                ? 2
                : (c.maxWidth / tileBase).floor().clamp(2, 6);
            final childAspect = isMobile ? 0.85 : 0.95;
            final grid = GridView.builder(
              padding: EdgeInsets.all(isMobile ? 10 : 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: isMobile ? 10 : 16,
                mainAxisSpacing: isMobile ? 10 : 16,
                childAspectRatio: childAspect,
              ),
              itemCount: paginatedFolders.length,
              itemBuilder: (ctx, i) {
                final folder = paginatedFolders[i];
                return GestureDetector(
                  onSecondaryTapDown: (details) => _showFolderContextMenu(context, details.globalPosition, folder),
                  onLongPressStart: (details) => _showFolderContextMenu(context, details.globalPosition, folder),
                  child: InkWell(

                  onTap: () {
                    if (folder.studentId != null) {
                      setState(() {
                        _openedFolderStudentId = folder.studentId;
                        _openedFolderName = folder.name;
                      });
                      ref
                          .read(documentQueryProvider.notifier)
                          .setStudentId(folder.studentId);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_rounded,
                          size: isMobile ? 36 : 48,
                          color: Colors.orange,
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            folder.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 11 : 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildFolderCompletionBadge(folder),
                        ),
                      ],
                    ),
                    ),
                  ),
                );
              },
            );
            return Column(
              children: [
                Expanded(child: grid),
                if (totalPages > 1) _buildFoldersPagination(totalPages, _foldersPage),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFolderCompletionBadge(dynamic folder) {
    final FolderModel f = folder as FolderModel;
    final pills = <Widget>[];

    // JHS Pill
    final jhsTotal = f.jhsTotal;
    final jhsDone = f.jhsCompleted;
    final jhsComplete = jhsTotal > 0 && jhsDone >= jhsTotal;
    final jhsColor = jhsComplete ? Colors.green : Colors.orange;
    pills.add(
      Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: jhsColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: jhsColor.withValues(alpha: 0.35)),
        ),
        child: Text(
          'JHS $jhsDone/$jhsTotal',
          style: TextStyle(
            fontSize: 10,
            color: jhsColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    // SHS Pill
    final shsTotal = f.shsTotal;
    final shsDone = f.shsCompleted;
    final shsComplete = shsTotal > 0 && shsDone >= shsTotal;
    final shsColor = shsComplete ? Colors.green : Colors.blue.shade700;
    pills.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: shsColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: shsColor.withValues(alpha: 0.35)),
        ),
        child: Text(
          'SHS $shsDone/$shsTotal',
          style: TextStyle(
            fontSize: 10,
            color: shsColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (pills.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: pills);
  }

  Widget _buildGridView(List documents, int totalPages, int currentPage) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobileGrid = screenW < 700;
    return LayoutBuilder(
      builder: (ctx, c) {
        // Mobile: always 2 columns; desktop: derive from tile width
        int cols = isMobileGrid ? 2 : (c.maxWidth / 180).floor().clamp(2, 6);
        final aspect = isMobileGrid ? 0.80 : 1.0;
        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(isMobileGrid ? 10 : 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: isMobileGrid ? 10 : 12,
                  mainAxisSpacing: isMobileGrid ? 10 : 12,
                  childAspectRatio: aspect,
                ),
                itemCount: documents.length,
                itemBuilder: (ctx, i) => FileFolderCard(
                  document: documents[i],
                  isGrid: true,
                  userRole: widget.userRole,
                  isMultiSelectMode: _isMultiSelectMode,
                  isSelected: _selectedDocumentIds.contains(documents[i].id),
                  onSelectedChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedDocumentIds.add(documents[i].id);
                      } else {
                        _selectedDocumentIds.remove(documents[i].id);
                      }
                    });
                  },
                  onTap: () {
                    if (_isMultiSelectMode) {
                      setState(() {
                        if (_selectedDocumentIds.contains(documents[i].id)) {
                          _selectedDocumentIds.remove(documents[i].id);
                        } else {
                          _selectedDocumentIds.add(documents[i].id);
                        }
                      });
                    } else {
                      showDocumentPreview(context: context, document: documents[i]);
                    }
                  },
                  onActionSelected: (a) => _handleAction(a, documents[i]),
                  onViewProfile: (sid) => showStudentProfileModal(context, studentId: sid, userRole: widget.userRole),
                ),
              ),
            ),
            if (totalPages > 1)
              Container(
                child: _buildPagination(totalPages, currentPage),
              ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LIST VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildListView(List documents, int totalPages, int currentPage) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobileList = screenW < 700;
    return Column(
      children: [
        Expanded(
          child: Container(
      margin: EdgeInsets.all(isMobileList ? 8 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table header — simplified for mobile
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobileList ? 12 : 16,
                vertical: 10,
              ),
              color: AppColors.primaryGreen.withValues(alpha: 0.06),
              child: Row(
                children: [
                  // Icon placeholder
                  const SizedBox(width: 40),
                  const SizedBox(width: 8),
                  // File name always visible
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'File Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Student column — hidden on mobile
                  if (!isMobileList)
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Folder Path',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  // Doc type — hidden on mobile
                  if (!isMobileList)
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Doc Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  // Status always visible
                  const Expanded(
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: documents.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (ctx, i) {
                  return isMobileList
                      ? _buildMobileListRow(documents[i], i)
                      : FileFolderCard(
                          document: documents[i],
                          isGrid: false,
                          userRole: widget.userRole,
                          isMultiSelectMode: _isMultiSelectMode,
                          isSelected: _selectedDocumentIds.contains(
                            documents[i].id,
                          ),
                          onSelectedChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedDocumentIds.add(documents[i].id);
                              } else {
                                _selectedDocumentIds.remove(documents[i].id);
                              }
                            });
                          },
                          onTap: () {
                            if (_isMultiSelectMode) {
                              setState(() {
                                if (_selectedDocumentIds.contains(
                                  documents[i].id,
                                )) {
                                  _selectedDocumentIds.remove(documents[i].id);
                                } else {
                                  _selectedDocumentIds.add(documents[i].id);
                                }
                              });
                            } else {
                              showDocumentPreview(context: context, document: documents[i]);
                            }
                          },
                          onActionSelected: (a) => _handleAction(a, documents[i]),
                          onViewProfile: (sid) => showStudentProfileModal(context, studentId: sid, userRole: widget.userRole),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    if (totalPages > 1)
      Container(
        child: _buildPagination(totalPages, currentPage),
      ),
  ],
);
  }

  /// Compact card row for mobile list view – stacks info vertically.
  Widget _buildMobileListRow(dynamic doc, int i) {
    Color fileColor;
    IconData fileIcon;
    final name = doc.fileName.toLowerCase() as String;
    if (name.endsWith('.pdf')) {
      fileColor = Colors.redAccent;
      fileIcon = Icons.picture_as_pdf;
    } else if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      fileColor = Colors.blueAccent;
      fileIcon = Icons.image;
    } else {
      fileColor = AppColors.primaryGreen;
      fileIcon = Icons.insert_drive_file;
    }

    Color statusColor;
    switch (doc.status as String) {
      case 'Completed':
        statusColor = AppColors.success;
        break;
      case 'Archived':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    final isSelected = _selectedDocumentIds.contains(doc.id);

    return GestureDetector(
      onSecondaryTapDown: (details) => _showDocumentContextMenu(context, details.globalPosition, doc as DocumentModel),
      onLongPressStart: (details) => _showDocumentContextMenu(context, details.globalPosition, doc as DocumentModel),
      child: InkWell(
        onTap: () {
          if (_isMultiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedDocumentIds.remove(doc.id);
              } else {
                _selectedDocumentIds.add(doc.id);
              }
            });
          } else {
            showDocumentPreview(context: context, document: doc as DocumentModel);
          }
        },
        child: Container(
        color: isSelected
            ? AppColors.primaryGreen.withValues(alpha: 0.05)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Multi-select checkbox
            if (_isMultiSelectMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primaryGreen,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedDocumentIds.add(doc.id);
                    } else {
                      _selectedDocumentIds.remove(doc.id);
                    }
                  });
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
            ],

            // File icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(fileIcon, size: 18, color: fileColor),
            ),
            const SizedBox(width: 10),

            // Stacked info: file name + student + doc type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.fileName as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doc.studentName as String? ??
                        (doc.studentLrn != null
                            ? 'LRN: ${doc.studentLrn}'
                            : '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if ((doc.documentType as String?) != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      doc.documentType as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                doc.status as String,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Actions menu
            if (!_isMultiSelectMode)
              SizedBox(
                width: 30,
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (a) => _handleAction(a, doc as DocumentModel),
                  itemBuilder: (_) => [
                    // removed preview
                    const PopupMenuItem(
                      value: 'queue',
                      child: Row(
                        children: [
                          Icon(Icons.print, size: 16),
                          SizedBox(width: 10),
                          Text('Print List', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 16),
                          SizedBox(width: 10),
                          Text('Download', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'view_profile',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Student Profile',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.userRole != 'teacher') ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 16,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    ));
  }

  // ══════════════════════════════════════════════════════════════
  // EMPTY / ERROR STATES
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmptyState({bool noSections = false}) {
    if (noSections) {
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
            const Text(
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
          Icon(
            Icons.folder_off_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No documents found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a document or adjust your filters',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (_selectedStatus != 'All Statuses' ||
              _selectedDocumentType != 'All Types' ||
              _selectedGradeLevel != 'All Grades' ||
              _selectedSchoolYear != 'All Years' ||
              _searchController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
            onPressed: () => ref.invalidate(documentPageProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PAGINATION
  // ══════════════════════════════════════════════════════════════
  Widget _buildPagination(int totalPages, int currentPage) {
    return SafeArea(
      top: false,
      child: AppPagination(
        currentPage: currentPage,
        totalPages: totalPages,
        onPageChanged: (p) => ref.read(documentQueryProvider.notifier).setPage(p),
      ),
    );
  }

  Widget _buildFoldersPagination(int totalPages, int currentPage) {
    return SafeArea(
      top: false,
      child: AppPagination(
        currentPage: currentPage,
        totalPages: totalPages,
        onPageChanged: (p) => setState(() => _foldersPage = p),
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context, Offset position, dynamic folder) {
    if (folder.studentId == null) return;
    
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18, color: Colors.orange),
              SizedBox(width: 12),
              Text('Open Folder', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'view_profile',
          child: Row(
            children: [
              Icon(Icons.person, size: 18, color: AppColors.primaryGreen),
              SizedBox(width: 12),
              Text('View Student Profile', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'open') {
        setState(() {
          _openedFolderStudentId = folder.studentId;
          _openedFolderName = folder.name;
        });
        ref.read(documentQueryProvider.notifier).setStudentId(folder.studentId);
      } else if (value == 'view_profile') {
        showStudentProfileModal(
          context,
          studentId: folder.studentId!,
          userRole: widget.userRole,
        );
      }
    });
  }

  void _showDocumentContextMenu(BuildContext context, Offset position, DocumentModel doc) {
    if (_isMultiSelectMode) return;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'queue',
        child: Row(
          children: [
            Icon(Icons.print, size: 18),
            SizedBox(width: 12),
            Text('Add to Print List', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'copy',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            SizedBox(width: 12),
            Text('Copy', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'download',
        child: Row(
          children: [
            Icon(Icons.download, size: 18),
            SizedBox(width: 12),
            Text('Download', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'view_profile',
        child: Row(
          children: [
            Icon(Icons.person, size: 18, color: AppColors.primaryGreen),
            SizedBox(width: 12),
            Text('View Student Profile', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    ];
    
    if (widget.userRole != 'teacher') {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: AppColors.error),
            SizedBox(width: 12),
            Text('Delete', style: TextStyle(fontSize: 14, color: AppColors.error)),
          ],
        ),
      ));
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: items,
    ).then((value) {
      if (value != null) {
        _handleAction(value, doc);
      }
    });
  }
}
