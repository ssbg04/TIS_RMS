import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/folder_model.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/document_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/navigation_provider.dart';
import '../students/student_detail_screen.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import 'widgets/file_folder_card.dart';
import 'widgets/upload_ocr_modal.dart';
import 'widgets/print_queue_modal.dart';
import 'widgets/student_profile_modal.dart';
import 'widgets/document_preview_modal.dart';
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
  Timer? _debounce;
  bool _isGridView = false;
  bool _showFilters = false;
  late final TabController _tabController;

  // --- Windows Explorer State Variables ---
  int? _openedFolderStudentId;
  String? _openedFolderName;

  // Filter values — kept in sync with provider
  String _selectedStatus = 'All Statuses';
  String _selectedDocumentType = 'All Types';
  String _selectedGradeLevel = 'All Grades';
  String _selectedSchoolYear = 'All Years';

  // Cached doc type lists for filter expansion
  List<String> _jhsItems = [];
  List<String> _shsItems = [];

  // Selection states
  bool _isMultiSelectMode = false;
  final Set<int> _selectedDocumentIds = {};
  final Set<int> _selectedTrashIds = {};

  Timer? _pollingTimer;
  ProviderSubscription<String>? _tabListener;
  ProviderSubscription<int?>? _folderListener;

  @override
  void initState() {
    super.initState();
    // 3 tabs: 0=Folders, 1=Documents, 2=Recycle Bin
    _tabController = TabController(length: 3, vsync: this);

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        if (_tabController.index == 0) {
          ref.invalidate(foldersProvider);
          ref.invalidate(studentFoldersProvider);
        } else if (_tabController.index == 1) {
          ref.invalidate(documentPageProvider);
        } else if (_tabController.index == 2) {
          ref.invalidate(trashDocumentsProvider);
        }
      }
    });

    // If a specific student was passed, jump to Folders tab and open that folder
    if (widget.initialStudentId != null) {
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
          _showFilters = false;
          _isMultiSelectMode = false;
          _selectedTrashIds.clear();
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
          ref.read(openedFolderStudentIdProvider.notifier).setStudentId(null);
          ref.read(documentQueryProvider.notifier).setStudentId(null);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _tabListener = ref.listenManual<String>(activeTabProvider, (previous, next) {
        if (!mounted) return;
        if (next != 'Documents') {
          ref.read(openedFolderStudentIdProvider.notifier).setStudentId(null);
          setState(() {
            _openedFolderStudentId = null;
            _openedFolderName = null;
            _showFilters = false;
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

      _folderListener = ref.listenManual<int?>(openedFolderStudentIdProvider, (previous, current) {
        if (!mounted) return;
        if (current != null && current != _openedFolderStudentId) {
          setState(() {
            _openedFolderStudentId = current;
            _openedFolderName = 'Student Documents';
          });
          if (mounted && _tabController.index != 0) {
            _tabController.index = 0;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(documentQueryProvider.notifier).setStudentId(current);
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
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(documentQueryProvider.notifier).setSearch(query);
    });
  }

  void _applyFilters() {
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
      showDocumentPreview(context, document);
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
    final isRecycleBin = _tabController.index == 2;
    final count = isRecycleBin
        ? _selectedTrashIds.length
        : _selectedDocumentIds.length;
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
                      _selectedTrashIds.clear();
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
                children: isRecycleBin
                    ? [
                        _batchActionBtn(
                          icon: Icons.restore,
                          label: 'Restore',
                          color: AppColors.primaryGreen,
                          onTap: count == 0
                              ? () {}
                              : () => _handleBulkRestore(
                                  _selectedTrashIds.toList(),
                                ),
                        ),
                        _batchActionBtn(
                          icon: Icons.delete_forever,
                          label: 'Delete',
                          color: AppColors.error,
                          onTap: count == 0
                              ? () {}
                              : () => _handleBulkPermanentDelete(
                                  _selectedTrashIds.toList(),
                                ),
                        ),
                      ]
                    : [
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
              _selectedTrashIds.clear();
              _isMultiSelectMode = false;
            }),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 4),
          if (isRecycleBin) ...[
            IconButton(
              icon: const Icon(Icons.restore, color: AppColors.primaryGreen),
              tooltip: 'Restore selected',
              onPressed: count == 0
                  ? null
                  : () => _handleBulkRestore(_selectedTrashIds.toList()),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppColors.error),
              tooltip: 'Delete',
              onPressed: count == 0
                  ? null
                  : () =>
                        _handleBulkPermanentDelete(_selectedTrashIds.toList()),
            ),
          ] else ...[
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
        // FAB: visible on mobile only (Windows desktop uses the header Upload button)
        floatingActionButton:
            defaultTargetPlatform != TargetPlatform.windows &&
                (_tabController.index == 1 || isFolderOpened) &&
                !_isMultiSelectMode
            ? FloatingActionButton(
                heroTag: 'upload_fab',
                backgroundColor: AppColors.primaryGreen,
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => UploadOcrModal(
                    prefilledStudentId:
                        _openedFolderStudentId ?? widget.initialStudentId,
                  ),
                ),
                child: const Icon(Icons.cloud_upload, color: Colors.white),
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
                            .read(openedFolderStudentIdProvider.notifier)
                            .setStudentId(null);
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
                    Tab(
                      icon: Icon(Icons.delete_sweep, size: 18),
                      text: 'Recycle Bin',
                    ),
                  ],
                ),
              ),

              // ── Filter Panel ──
              if (_showFilters)
                _buildFilterPanel(
                  requirementsAsync,
                  academicYearsAsync,
                  statusesAsync,
                  isMobile,
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
                                ? _buildGridView(pageData.documents)
                                : _buildListView(pageData.documents),
                          ),
                        ),
                        // Pagination
                        docState.maybeWhen(
                          data: (p) => p.totalPages > 1
                              ? _buildPagination(p.totalPages, query.page)
                              : const SizedBox.shrink(),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),

                    // Tab 2: Recycle Bin
                    _buildRecycleBinTab(isMobile, screenW),
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
                            .read(openedFolderStudentIdProvider.notifier)
                            .setStudentId(null);
                        ref
                            .read(documentQueryProvider.notifier)
                            .setStudentId(null);
                      }
                    : null,
              ),
              const SizedBox(width: 6),

              // Screen title
              Expanded(
                child: Text(
                  _openedFolderName ??
                      (isStudentFiltered
                          ? 'Student Documents'
                          : 'Document Manager'),
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

              // Desktop action buttons (Upload available to all roles)
              if (!isMobile && _tabController.index != 2) ...[
                const SizedBox(width: 8),
                _buildPrintQueueButton(),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
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
                  onChanged: _onSearchChanged,
                  maxWidth: double.infinity,
                ),
              ),
              const SizedBox(width: 8),

              // Filter and Multi-select toggles (Documents tab, opened folder, or Recycle Bin)
              if (_tabController.index == 1 ||
                  isFolderOpened ||
                  _tabController.index == 2) ...[
                _buildIconToggle(
                  icon: Icons.tune_rounded,
                  isActive: _showFilters,
                  tooltip: 'Toggle Filters',
                  onTap: () => setState(() => _showFilters = !_showFilters),
                ),
                const SizedBox(width: 6),
                _buildIconToggle(
                  icon: _isMultiSelectMode
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  isActive: _isMultiSelectMode,
                  tooltip: 'Toggle Selection Mode',
                  onTap: () {
                    setState(() {
                      _isMultiSelectMode = !_isMultiSelectMode;
                      if (!_isMultiSelectMode) {
                        _selectedDocumentIds.clear();
                        _selectedTrashIds.clear();
                      }
                    });
                  },
                ),
              ],

              const SizedBox(width: 6),

              // Grid / List toggle (Hidden on Recycle Bin)
              if (_tabController.index != 2)
                _buildIconToggle(
                  icon: _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  isActive: false,
                  tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                  onTap: () => setState(() => _isGridView = !_isGridView),
                ),

              // Mobile-only: compact print queue button (Hidden on Recycle Bin)
              if (isMobile && _tabController.index != 2) ...[
                const SizedBox(width: 6),
                _buildPrintQueueButton(compact: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconToggle({
    required IconData icon,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.primaryGreen : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
        ),
      ),
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
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const PrintQueueModal(),
        ),
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
  // FILTER PANEL
  // ══════════════════════════════════════════════════════════════
  Widget _buildFilterPanel(
    AsyncValue<List<dynamic>> requirementsAsync,
    AsyncValue<List<dynamic>> academicYearsAsync,
    AsyncValue<List<String>> statusesAsync,
    bool isMobile,
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

    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear, size: 16, color: AppColors.error),
                label: const Text(
                  'Clear Filters',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildDropdown(
                label: 'Status',
                value: _selectedStatus,
                items: statusItems,
                onChanged: (v) {
                  setState(() => _selectedStatus = v!);
                  _applyFilters();
                },
              ),
              _buildDocumentTypeFilter(jhsReqs, shsReqs),
              _buildDropdown(
                label: 'Grade Level',
                value: _selectedGradeLevel,
                items: const ['All Grades', '7', '8', '9', '10', '11', '12'],
                onChanged: (v) {
                  setState(() => _selectedGradeLevel = v!);
                  _applyFilters();
                },
              ),
              _buildDropdown(
                label: 'School Year',
                value: _selectedSchoolYear,
                items: years,
                onChanged: (v) {
                  setState(() => _selectedSchoolYear = v!);
                  _applyFilters();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      child: DropdownButton<String>(
        value: safeValue,
        hint: Text(label, style: const TextStyle(fontSize: 13)),
        isExpanded: false,
        isDense: false,
        underline: Container(height: 1, color: Colors.grey.shade400),
        items: items
            .map(
              (i) => DropdownMenuItem(
                value: i,
                child: Text(i, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDocumentTypeFilter(List<String> jhsReqs, List<String> shsReqs) {
    final jhsItems = jhsReqs.where((e) => e != 'All JHS').toList();
    final shsItems = shsReqs.where((e) => e != 'All SHS').toList();

    // Cache for use in _applyFilters
    if (jhsItems.isNotEmpty) _jhsItems = jhsItems;
    if (shsItems.isNotEmpty) _shsItems = shsItems;

    final allOptions = ['All Types', 'All JHS', 'All SHS', ...jhsItems, ...shsItems];

    return _buildDropdown(
      label: 'Document Type',
      value: _selectedDocumentType,
      items: allOptions,
      onChanged: (v) {
        setState(() => _selectedDocumentType = v!);
        _applyFilters();
      },
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
              data: (pageData) => pageData.documents.isEmpty
                  ? _buildEmptyState()
                  : _isGridView
                  ? _buildGridView(pageData.documents)
                  : _buildListView(pageData.documents),
            ),
          ),
          docState.maybeWhen(
            data: (p) => p.totalPages > 1
                ? _buildPagination(p.totalPages, query.page)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
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

        if (!_isGridView) {
          return Container(
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
                      itemCount: folders.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (ctx, i) {
                        final folder = folders[i];
                        return InkWell(
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
            return GridView.builder(
              padding: EdgeInsets.all(isMobile ? 10 : 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: isMobile ? 10 : 16,
                mainAxisSpacing: isMobile ? 10 : 16,
                childAspectRatio: childAspect,
              ),
              itemCount: folders.length,
              itemBuilder: (ctx, i) {
                final folder = folders[i];
                return InkWell(
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
                );
              },
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

  // ══════════════════════════════════════════════════════════════
  // GRID VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildGridView(List documents) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobileGrid = screenW < 700;
    return LayoutBuilder(
      builder: (ctx, c) {
        // Mobile: always 2 columns; desktop: derive from tile width
        int cols = isMobileGrid ? 2 : (c.maxWidth / 180).floor().clamp(2, 6);
        final aspect = isMobileGrid ? 0.80 : 1.0;
        return GridView.builder(
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
              }
            },
            onActionSelected: (a) => _handleAction(a, documents[i]),
            onViewProfile: (sid) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudentDetailScreen(
                  studentId: sid,
                  userRole: widget.userRole,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LIST VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildListView(List documents) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobileList = screenW < 700;
    return Container(
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
                        'Student',
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
                itemBuilder: (ctx, i) => isMobileList
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
                          }
                        },
                        onActionSelected: (a) => _handleAction(a, documents[i]),
                        onViewProfile: (sid) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentDetailScreen(
                              studentId: sid,
                              userRole: widget.userRole,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
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

    return InkWell(
      onTap: () {
        if (_isMultiSelectMode) {
          setState(() {
            if (isSelected) {
              _selectedDocumentIds.remove(doc.id);
            } else {
              _selectedDocumentIds.add(doc.id);
            }
          });
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
                    const PopupMenuItem(
                      value: 'preview',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 16),
                          SizedBox(width: 10),
                          Text('Preview', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
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
    );
  }

  // ══════════════════════════════════════════════════════════════
  // EMPTY / ERROR STATES
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
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
    return Container(
      color: AppColors.surfaceWhite,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => ref
                      .read(documentQueryProvider.notifier)
                      .setPage(currentPage - 1)
                : null,
          ),
          ...List.generate(
            totalPages,
            (i) => i + 1,
          ).where((p) => (p - currentPage).abs() <= 2).map((p) {
            final isActive = p == currentPage;
            return GestureDetector(
              onTap: () => ref.read(documentQueryProvider.notifier).setPage(p),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? null
                      : Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => ref
                      .read(documentQueryProvider.notifier)
                      .setPage(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // RECYCLE BIN TAB
  // ══════════════════════════════════════════════════════════════
  Widget _buildRecycleBinTab(bool isMobile, double screenW) {
    final trashAsync = ref.watch(trashDocumentsProvider);

    return trashAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load Recycle Bin: $err'),
            TextButton(
              onPressed: () => ref.invalidate(trashDocumentsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (items) {
        final query = ref.read(documentQueryProvider);
        var filteredItems = items;
        if (query.search.isNotEmpty) {
          final s = query.search.toLowerCase();
          filteredItems = items
              .where(
                (i) =>
                    i.fileName.toLowerCase().contains(s) ||
                    (i.studentName ?? '').toLowerCase().contains(s),
              )
              .toList();
        }

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recycle Bin is empty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Soft-deleted documents will appear here.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final item = filteredItems[idx];
                  final isSelected = _selectedTrashIds.contains(item.id);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: _isMultiSelectMode
                        ? Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primaryGreen,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedTrashIds.add(item.id);
                                } else {
                                  _selectedTrashIds.remove(item.id);
                                }
                              });
                            },
                          )
                        : null,
                    title: Text(
                      item.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.studentName != null &&
                              item.studentName!.isNotEmpty)
                            Text(
                              'Student: ${item.studentName}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '${item.daysRemaining} days remaining',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (item.documentType != null)
                                Text(
                                  item.documentType!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: isMobile
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (val) {
                              if (val == 'restore') _handleRestore(item.id);
                              if (val == 'delete') _handlePermanentDelete(item.id);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text('Restore', style: TextStyle(color: AppColors.primaryGreen)),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('DELETE', style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.restore,
                                  color: AppColors.primaryGreen,
                                ),
                                tooltip: 'Restore document',
                                onPressed: () => _handleRestore(item.id),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: AppColors.error,
                                ),
                                tooltip: 'Delete permanently',
                                onPressed: () => _handlePermanentDelete(item.id),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRestore(int id) async {
    try {
      await ref.read(trashMutationProvider.notifier).restoreDocument(id);
      showSuccessDialog(context, message: 'Document has been restored.');
    } catch (e) {
      showErrorDialog(
        context,
        'Restore Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handleBulkRestore(List<int> ids) async {
    try {
      await ref.read(trashMutationProvider.notifier).bulkRestore(ids);
      setState(() {
        _selectedTrashIds.clear();
      });
      showSuccessDialog(
        context,
        message: 'Selected documents restored successfully.',
      );
    } catch (e) {
      showErrorDialog(
        context,
        'Bulk Restore Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handlePermanentDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Permanent Deletion'),
        content: const Text(
          'Are you sure you want to permanently delete this document? This will remove the file from the disk and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(trashMutationProvider.notifier).permanentDelete(id);
      showSuccessDialog(context, message: 'Document permanently deleted.');
    } catch (e) {
      showErrorDialog(
        context,
        'Deletion Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handleBulkPermanentDelete(List<int> ids) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Deletion'),
        content: Text(
          'Are you sure you want to permanently delete these ${ids.length} documents? This will delete the files from the disk and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(trashMutationProvider.notifier).bulkPermanentDelete(ids);
      setState(() {
        _selectedTrashIds.clear();
      });
      showSuccessDialog(
        context,
        message: 'Selected documents permanently deleted.',
      );
    } catch (e) {
      showErrorDialog(
        context,
        'Bulk Deletion Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
