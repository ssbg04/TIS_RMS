import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/folder_model.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../providers/document_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/dialogs/document_properties_dialog.dart';
import '../../shared/widgets/app_pagination.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/horizontal_expandable_fab.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/conversion_provider.dart';

import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import 'widgets/file_folder_card.dart';
import 'widgets/upload_ocr_modal.dart';
import 'widgets/print_queue_modal.dart';
import 'widgets/student_profile_modal.dart';
import 'widgets/document_preview_modal.dart';
import 'widgets/download_guide_dialog.dart';
import '../../../core/utils/download_service.dart';
import '../../../core/network/api_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'widgets/recycle_bin_modal.dart';
import 'widgets/student_archives_modal.dart';
import 'widgets/bulk_operations_bar.dart';
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
  final FocusNode _shortcutFocusNode = FocusNode();
  final GlobalKey _searchBarKey = GlobalKey();
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
      if (mounted &&
          ref.read(authProvider).value != null &&
          ref.read(activeTabProvider) == 'Documents') {
        if (_tabController.index == 0) {
          ref.invalidate(foldersProvider);
          ref.invalidate(studentFoldersProvider);
        } else if (_tabController.index == 1) {
          ref.invalidate(documentPageProvider);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // If a specific student was passed, jump to Folders tab and open that folder
      final initialFolder = ref.read(openedFolderProvider);
      if (initialFolder != null) {
        setState(() {
          _openedFolderStudentId = initialFolder.id;
          _openedFolderName = initialFolder.name;
        });
        ref.read(documentQueryProvider.notifier).setStudentId(initialFolder.id);
      } else if (widget.initialStudentId != null) {
        setState(() {
          _openedFolderStudentId = widget.initialStudentId;
          _openedFolderName = 'Student Documents';
        });
        ref
            .read(documentQueryProvider.notifier)
            .setStudentId(widget.initialStudentId);
      }
    });

    _tabController.addListener(() {
      setState(() {}); // Ensure header title updates immediately on tab change
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
      if (ref.read(activeTabProvider) == 'Documents') {
        _shortcutFocusNode.requestFocus();
      }
      ref.read(documentQueryProvider.notifier).setPage(1);

      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
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
        } else {
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) {
              _shortcutFocusNode.requestFocus();
            }
          });
        }
      });

      _folderListener = ref.listenManual<OpenedFolderData?>(
        openedFolderProvider,
        (previous, current) {
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
        },
      );
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
    _shortcutFocusNode.dispose();
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

  void _onSearchSubmitted(String query) {
    _debounce?.cancel();
    setState(() => _foldersPage = 1);
    ref.read(documentQueryProvider.notifier).setSearch(query);
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

    if (action == 'select') {
      setState(() {
        _isMultiSelectMode = true;
        _selectedDocumentIds.add(documentId);
      });
    } else if (action == 'properties') {
      DocumentPropertiesDialog.show(context, document: document);
    } else if (action == 'view_profile' && studentId != null) {
      showStudentProfileModal(
        context,
        studentId: studentId,
        userRole: widget.userRole,
        hideEnrollmentActions: true,
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
      try {
        final token = await const FlutterSecureStorage().read(key: 'jwt_token');
        if (token == null) return;
        final url =
            '${ApiConstants.baseUrl}/documents/${document.id}/view?token=$token&download=true';

        await DownloadService.downloadFile(
          url: url,
          fileName: document.fileName,
        );
        if (!mounted) return;
        showSuccessDialog(
          context,
          message: 'Document downloaded successfully.',
        );
      } catch (e) {
        if (!mounted) return;
        showErrorDialog(context, 'Download Failed', e.toString());
      }
    } else if (action == 'archive') {
      _confirmArchive(document);
    } else if (action == 'convert_pdf') {
      try {
        final converted = await ref
            .read(conversionProvider.notifier)
            .convertToPdf(documentId);
        if (!mounted) return;
        showSuccessDialog(
          context,
          message: 'Excel converted to PDF successfully as "${converted.fileName}".',
        );
      } catch (e) {
        if (!mounted) return;
        showErrorDialog(
          context,
          'Conversion Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _confirmArchive(DocumentModel document) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Archive Document'),
          ],
        ),
        content: Text(
          'Are you sure you want to archive "${document.fileName}"?\n\nIt will be moved to the Archive Screen and hidden from active documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(documentMutationProvider.notifier)
                    .updateStatus(document.id, 'Archived');
                if (!mounted) return;
                showSuccessDialog(
                  context,
                  message: 'Document moved to Archive Screen.',
                );
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Archive Failed', e.toString());
              }
            },
            child: const Text('ARCHIVE'),
          ),
        ],
      ),
    );
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

  Future<void> _handleBatchDownload() async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'jwt_token');
      if (token == null) return;

      final docs = ref.read(documentPageProvider).value?.documents ?? [];
      int successCount = 0;

      for (final docId in _selectedDocumentIds) {
        final doc = docs.firstWhere((d) => d.id == docId);
        final url =
            '${ApiConstants.baseUrl}/documents/${doc.id}/view?token=$token&download=true';
        await DownloadService.downloadFile(url: url, fileName: doc.fileName);
        successCount++;
      }

      setState(() {
        _selectedDocumentIds.clear();
        _isMultiSelectMode = false;
      });
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Successfully downloaded $successCount documents.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Download Failed',
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

  Widget _buildInlineMultiSelectHeader() {
    final pageDocs = ref.watch(documentPageProvider).value?.documents ?? [];
    final pageIds = pageDocs.map((d) => d.id).toSet();
    final bool allSelected = pageIds.isNotEmpty && pageIds.every((id) => _selectedDocumentIds.contains(id));

    return BulkOperationsBar(
      selectedCount: _selectedDocumentIds.length,
      allSelected: allSelected,
      isAdmin: widget.userRole != 'teacher',
      onCancel: () => setState(() {
        _selectedDocumentIds.clear();
        _isMultiSelectMode = false;
      }),
      onToggleSelectAll: pageDocs.isEmpty
          ? () {}
          : () {
              setState(() {
                if (allSelected) {
                  _selectedDocumentIds.clear();
                } else {
                  _selectedDocumentIds.addAll(pageIds);
                }
              });
            },
      onBatchPrint: _handleBatchPrint,
      onBatchCopy: _handleBatchCopy,
      onBatchDownload: _handleBatchDownload,
      onBatchStatus: _handleBatchStatus,
      onBatchArchive: () => _handleBatchStatus('Archived'),
      onBatchDelete: _handleBatchDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        if (ref.read(activeTabProvider) != 'Documents') return;
        if (_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = false;
            _selectedDocumentIds.clear();
            if (_openedFolderStudentId != null) {
              _openedFolderStudentId = null;
              _openedFolderName = null;
              if (_tabController.index != 0) {
                _tabController.index = 0;
              }
            }
          });
          ref.read(openedFolderProvider.notifier).setFolder(null);
          ref.read(documentQueryProvider.notifier).setStudentId(null);
          return;
        }
        if (_openedFolderStudentId != null) {
          setState(() {
            _openedFolderStudentId = null;
            _openedFolderName = null;
            if (_tabController.index != 0) {
              _tabController.index = 0;
            }
          });
          ref.read(openedFolderProvider.notifier).setFolder(null);
          ref.read(documentQueryProvider.notifier).setStudentId(null);
          return;
        }
        ref.read(activeTabProvider.notifier).setTab('Dashboard');
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: (isMobile &&
                !_isMultiSelectMode &&
                !_searchFocusNode.hasFocus)
            ? HorizontalExpandableFab(
                heroTag: 'fab_documents_menu',
                items: [
                  // Print List Action (available for admin only)
                  if (widget.userRole != 'teacher')
                    FabActionItem(
                      icon: Icons.print_rounded,
                      tooltip: 'Print List',
                      badgeCount: ref.watch(printQueueProvider).value?.length ?? 0,
                      heroTag: 'fab_docs_print_list',
                      onPressed: () => PrintQueueModal.show(context),
                    ),
                  // Multi-Select Action (available for admin on All Documents or in opened folder)
                  if (widget.userRole != 'teacher' && (_tabController.index == 1 || isFolderOpened))
                    FabActionItem(
                      icon: Icons.checklist_rounded,
                      tooltip: 'Select Multiple',
                      heroTag: 'fab_docs_multi_select',
                      onPressed: () {
                        setState(() {
                          _isMultiSelectMode = true;
                        });
                      },
                    ),
                  // Upload Document Action (available on All Documents or in opened folder for both admin and teacher)
                  if (_tabController.index == 1 || isFolderOpened)
                    FabActionItem(
                      icon: Icons.cloud_upload_rounded,
                      tooltip: 'Upload Document',
                      heroTag: 'fab_docs_upload',
                      onPressed: () {
                        UploadOcrModal.show(
                          context,
                          prefilledStudentId:
                              _openedFolderStudentId ??
                              widget.initialStudentId,
                        );
                      },
                    ),
                ],
              )
            : null,
        bottomNavigationBar: null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header or Inline Multi-Select Header ──
              if (_isMultiSelectMode)
                _buildInlineMultiSelectHeader()
              else
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
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
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
                        ref.read(openedFolderProvider.notifier).setFolder(null);
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
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  indicatorColor: AppColors.primaryGreen,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      text: 'Student Folders',
                    ),
                    Tab(
                      text: 'All Documents',
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Tab Body ──
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
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
                                  error: (e, _) =>
                                      _buildErrorState(e.toString()),
                                  data: (pageData) => pageData.documents.isEmpty
                                      ? _buildEmptyState()
                                      : _isGridView
                                      ? _buildGridView(
                                          pageData.documents,
                                          pageData.totalPages,
                                          query.page,
                                        )
                                      : _buildListView(
                                          pageData.documents,
                                          pageData.totalPages,
                                          query.page,
                                        ),
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
            ],
          ),
        ),
      ),
      ),
      ),
      ),
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                key: _searchBarKey,
                hint: 'Search by name, LRN, file…',
                controller: _searchController,
                focusNode: _searchFocusNode,
                collapsible: false,
                maxWidth: 600,
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  Navigator.of(context).pop();
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button if folder opened
          if (isFolderOpened) ...[
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
              ),
              color: AppColors.primaryGreen,
              tooltip: 'Back to Folders',
              onPressed: () {
                setState(() {
                  _openedFolderStudentId = null;
                  _openedFolderName = null;
                });
                ref.read(openedFolderProvider.notifier).setFolder(null);
                ref.read(documentQueryProvider.notifier).setStudentId(null);
              },
            ),
            const SizedBox(width: 6),
          ],

          // Screen title
          Expanded(
            child: _openedFolderName != null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMobile) ...[
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
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          ' / ',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          _openedFolderName!,
                          style: TextStyle(
                            fontSize: isMobile ? 17 : 21,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
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
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // Clear student filter chip (compact)
          if (isStudentFiltered && !isFolderOpened) ...[
            const SizedBox(width: 12),
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

          if (!isFolderOpened) ...[
            Tooltip(
              richMessage: (_searchController.text.isNotEmpty || query.search.isNotEmpty)
                  ? const TextSpan(text: 'Clear Search')
                  : const TextSpan(
                      text: 'Search Documents ',
                      children: [
                        TextSpan(
                          text: '(Ctrl+F)',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
              child: IconButton(
                icon: Icon(
                  (_searchController.text.isNotEmpty || query.search.isNotEmpty)
                      ? Icons.close
                      : Icons.search,
                  size: 28,
                  color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                ),
                onPressed: () {
                  if (_searchController.text.isNotEmpty ||
                      query.search.isNotEmpty) {
                    _searchController.clear();
                    ref.read(documentQueryProvider.notifier).setSearch('');
                    setState(() => _foldersPage = 1);
                    ref.invalidate(foldersProvider);
                    ref.invalidate(studentFoldersProvider);
                    ref.invalidate(documentPageProvider);
                  } else {
                    _showSearchDialog(context);
                  }
                },
              ),
            ),
          ],

          const SizedBox(width: 4),

          // Multi-Select Toggle (Desktop only, icon only, no background, no border)
          if (!isMobile && widget.userRole != 'teacher' && (_tabController.index == 1 || isFolderOpened)) ...[
            Tooltip(
              message: _isMultiSelectMode ? 'Exit Multi-Select' : 'Multi-Select',
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  shadowColor: Colors.transparent,
                ),
                onPressed: () {
                  setState(() {
                    _isMultiSelectMode = !_isMultiSelectMode;
                    if (!_isMultiSelectMode) _selectedDocumentIds.clear();
                  });
                },
                icon: Icon(
                  Icons.checklist_rounded,
                  size: 22,
                  color: _isMultiSelectMode
                      ? AppColors.primaryGreen
                      : (isDark ? AppColors.darkTextPrimary : AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Filter button (Icon only, between Multi-Select and Upload/Bulk Add)
          if (_tabController.index == 1 || isFolderOpened) ...[
            Tooltip(
              message: 'Filter Documents',
              child: IconButton(
                onPressed: () => _openFilterDialog(
                  requirementsAsync,
                  academicYearsAsync,
                  statusesAsync,
                ),
                icon: Badge(
                  isLabelVisible: _getActiveFilterCount() > 0,
                  label: Text(_getActiveFilterCount().toString()),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Desktop action buttons (Upload available to admins and teachers)
          if (!isMobile && _tabController.index != 2) ...[
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => UploadOcrModal.show(
                  context,
                  prefilledStudentId:
                      _openedFolderStudentId ?? widget.initialStudentId,
                ),
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: const Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          if (defaultTargetPlatform != TargetPlatform.android && !isMobile && widget.userRole != 'teacher') ...[
            SizedBox(
              height: 36,
              child: _buildPrintQueueButton(compact: false),
            ),
            const SizedBox(width: 8),
          ],

          // Dropdown Menu
          SizedBox(height: 38, child: _buildMoreOptionsDropdown(isMobile)),

          const SizedBox(width: 4),

          // Info Button for Download Guide (Moved to right end)
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            tooltip: 'Download Guide',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const DownloadGuideDialog(),
              );
            },
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

  Widget _buildMoreOptionsDropdown(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFolderOpened = _openedFolderStudentId != null;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      tooltip: 'More Options',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'multi_select') {
          setState(() {
            _isMultiSelectMode = !_isMultiSelectMode;
            if (!_isMultiSelectMode) {
              _selectedDocumentIds.clear();
            }
          });
        } else if (value == 'grid_list') {
          setState(() => _isGridView = !_isGridView);
        } else if (value == 'archives') {
          if (_openedFolderStudentId != null) {
            StudentArchivesModal.show(
              context,
              studentId: _openedFolderStudentId!,
              studentName: _openedFolderName ?? 'Student',
              userRole: widget.userRole,
            );
          }
        } else if (value == 'recycle_bin') {
          showDialog(context: context, builder: (_) => const RecycleBinModal());
        }
      },
      itemBuilder: (context) => [
        if (!isMobile &&
            widget.userRole != 'teacher' &&
            (_tabController.index == 1 || isFolderOpened)) ...[
          PopupMenuItem(
            value: 'multi_select',
            child: Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isMultiSelectMode ? 'Exit Multi-Select' : 'Select Multiple',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: 'grid_list',
          child: Row(
            children: [
              Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _isGridView ? 'Switch to List' : 'Switch to Grid',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        if (isFolderOpened) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'archives',
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text('Archives', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'recycle_bin',
          child: Row(
            children: [
              Icon(
                Icons.delete_sweep,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text('Recycle Bin', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrintQueueButton({bool compact = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          child: const Icon(Icons.print_outlined, size: 16),
        ),
        label: compact
            ? const SizedBox.shrink()
            : Text(
                count > 0 ? 'Print List ($count)' : 'Print List',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
          padding: compact
              ? const EdgeInsets.all(10)
              : const EdgeInsets.symmetric(horizontal: 14),
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isSmallScreen = MediaQuery.of(context).size.height < 600;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isSmallScreen ? 16 : 36,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const defaultStatuses = [
      'All Statuses',
      'Completed',
    ];
    final statusItems = statusesAsync.when(
      data: (s) => (defaultStatuses.toSet()
            ..addAll(s.where((item) {
              final lower = item.toLowerCase();
              return lower != 'verified' &&
                  lower != 'draft' &&
                  lower != 'pending' &&
                  lower != 'archived';
            })))
          .toList(),
      loading: () => defaultStatuses,
      error: (_, st) => defaultStatuses,
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
      ...shsItems,
    ];

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
          // Header (Fixed)
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
                      'Filter Documents',
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

          // Scrollable middle section for filter items
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status
                  _buildFilterSection(
                    label: 'Status',
                    hasActiveFilter: _pendingStatus != 'All Statuses',
                    onReset: () =>
                        setDialogState(() => _pendingStatus = 'All Statuses'),
                    child: _buildFilterChipGroup(
                      items: statusItems,
                      selectedValue: statusItems.contains(_pendingStatus)
                          ? _pendingStatus
                          : 'All Statuses',
                      onSelected: (v) =>
                          setDialogState(() => _pendingStatus = v),
                    ),
                  ),

                  _buildDivider(isDark),

                  // Document Type
                  _buildFilterSection(
                    label: 'Document Type',
                    hasActiveFilter: _pendingDocumentType != 'All Types',
                    onReset: () =>
                        setDialogState(() => _pendingDocumentType = 'All Types'),
                    child: _buildFilterDropdown(
                      value: docTypeOptions.contains(_pendingDocumentType)
                          ? _pendingDocumentType
                          : 'All Types',
                      items: docTypeOptions,
                      onChanged: (v) =>
                          setDialogState(() => _pendingDocumentType = v!),
                    ),
                  ),

                  _buildDivider(isDark),

                  // Grade Level
                  _buildFilterSection(
                    label: 'Grade Level',
                    hasActiveFilter: _pendingGradeLevel != 'All Grades',
                    onReset: () =>
                        setDialogState(() => _pendingGradeLevel = 'All Grades'),
                    child: _buildFilterDropdown(
                      value: const [
                        'All Grades',
                        '7',
                        '8',
                        '9',
                        '10',
                        '11',
                        '12',
                      ].contains(_pendingGradeLevel)
                          ? _pendingGradeLevel
                          : 'All Grades',
                      items: const ['All Grades', '7', '8', '9', '10', '11', '12'],
                      labelBuilder: (g) =>
                          (g == 'All Grades' || g.toLowerCase().startsWith('grade'))
                              ? g
                              : 'Grade $g',
                      onChanged: (v) =>
                          setDialogState(() => _pendingGradeLevel = v!),
                    ),
                  ),

                  _buildDivider(isDark),

                  // School Year
                  _buildFilterSection(
                    label: 'School Year',
                    hasActiveFilter: _pendingSchoolYear != 'All Years',
                    onReset: () =>
                        setDialogState(() => _pendingSchoolYear = 'All Years'),
                    child: _buildFilterDropdown(
                      value: years.contains(_pendingSchoolYear)
                          ? _pendingSchoolYear
                          : 'All Years',
                      items: years,
                      onChanged: (v) =>
                          setDialogState(() => _pendingSchoolYear = v!),
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

          // Footer buttons (Fixed at bottom)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              children: [
                // Reset all
                Expanded(
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
                      setDialogState(() {
                        _pendingStatus = 'All Statuses';
                        _pendingDocumentType = 'All Types';
                        _pendingGradeLevel = 'All Grades';
                        _pendingSchoolYear = 'All Years';
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
                // Apply
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
                    onPressed: onApply,
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

  Widget _buildFilterDropdown({
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
                : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            size: 22,
          ),
          hint: hint != null
              ? Text(
                  hint,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                )
              : null,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: enabled
                ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                final hasNoSections =
                    widget.userRole == 'teacher' &&
                    query.search.isEmpty &&
                    query.status.isEmpty &&
                    query.documentType.isEmpty &&
                    query.gradeLevel.isEmpty &&
                    query.schoolYear.isEmpty &&
                    pageData.total == 0;
                final activeDocuments = pageData.documents
                    .where((d) => (d as DocumentModel).status != 'Archived')
                    .toList();
                return activeDocuments.isEmpty
                    ? _buildEmptyState(noSections: hasNoSections)
                    : _isGridView
                    ? _buildGridView(
                        activeDocuments,
                        pageData.totalPages,
                        query.page,
                      )
                    : _buildListView(
                        activeDocuments,
                        pageData.totalPages,
                        query.page,
                      );
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
          final hasNoSections =
              widget.userRole == 'teacher' &&
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
                      color: isDark ? AppColors.darkSurface2 : Colors.orange.shade50,
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
                Icon(
                  Icons.folder_off_outlined,
                  size: 64,
                  color: isDark ? AppColors.darkTextMuted : Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Student Folders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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

        final int totalPages = (filteredFolders.length / _foldersPerPage)
            .ceil();
        final int startIndex = (_foldersPage - 1) * _foldersPerPage;
        final int endIndex =
            (startIndex + _foldersPerPage > filteredFolders.length)
            ? filteredFolders.length
            : startIndex + _foldersPerPage;
        final List<dynamic> paginatedFolders = filteredFolders.isEmpty
            ? []
            : filteredFolders.sublist(startIndex, endIndex);

        if (!_isGridView) {
          return Column(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(isMobile ? 8 : 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
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
                    child: ListView.separated(
                      itemCount: paginatedFolders.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
                      itemBuilder: (ctx, i) {
                              final folder = paginatedFolders[i];
                              return GestureDetector(
                                onSecondaryTapDown: widget.userRole == 'teacher'
                                    ? null
                                    : (details) => _showFolderContextMenu(
                                        details.globalPosition,
                                        folder,
                                      ),
                                onLongPressStart: widget.userRole == 'teacher'
                                    ? null
                                    : (details) => _showFolderContextMenu(
                                        details.globalPosition,
                                        folder,
                                      ),
                                child: InkWell(
                                  onTap: () {
                                    if (folder.studentId != null) {
                                      setState(() {
                                        _openedFolderStudentId =
                                            folder.studentId;
                                        _openedFolderName = folder.name;
                                      });
                                      ref
                                          .read(documentQueryProvider.notifier)
                                          .setStudentId(folder.studentId);
                                      _searchFocusNode.unfocus();
                                      _searchController.clear();
                                      ref
                                          .read(documentQueryProvider.notifier)
                                          .setSearch('');
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
                                        // Column: name + count files inside + JHS/SHS badges
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                folder.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? AppColors.darkTextPrimary
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${folder.documentCount ?? 0} ${folder.documentCount == 1 ? "item" : "items"}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? AppColors.darkTextSecondary
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              _buildFolderCompletionBadge(
                                                folder,
                                              ),
                                            ],
                                          ),
                                        ),
                                         Icon(
                                           Icons.chevron_right,
                                           size: 18,
                                           color: isDark
                                               ? AppColors.darkTextMuted
                                               : AppColors.textMuted,
                                         ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ),
                ),
                if (totalPages > 1 && !_searchFocusNode.hasFocus)
                  _buildFoldersPagination(totalPages, _foldersPage),
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
                  onSecondaryTapDown: widget.userRole == 'teacher'
                      ? null
                      : (details) => _showFolderContextMenu(
                          details.globalPosition,
                          folder,
                        ),
                  onLongPressStart: widget.userRole == 'teacher'
                      ? null
                      : (details) => _showFolderContextMenu(
                          details.globalPosition,
                          folder,
                        ),
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
                        _searchFocusNode.unfocus();
                        _searchController.clear();
                        ref.read(documentQueryProvider.notifier).setSearch('');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
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
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                if (totalPages > 1 && !_searchFocusNode.hasFocus)
                  _buildFoldersPagination(totalPages, _foldersPage),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFolderCompletionBadge(dynamic folder) {
    final FolderModel f = folder as FolderModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pills = <Widget>[];

    // JHS Pill
    final jhsTotal = f.jhsTotal;
    final jhsDone = f.jhsCompleted;
    final jhsComplete = jhsTotal > 0 && jhsDone >= jhsTotal;
    final jhsColor = jhsComplete
        ? (isDark ? Colors.green.shade300 : Colors.green)
        : (isDark ? Colors.orange.shade300 : Colors.orange);
    pills.add(
      Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: jhsColor.withValues(alpha: isDark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: jhsColor.withValues(alpha: isDark ? 0.45 : 0.35)),
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
    final shsColor = shsComplete
        ? (isDark ? Colors.green.shade300 : Colors.green)
        : (isDark ? Colors.blue.shade300 : Colors.blue.shade700);
    pills.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: shsColor.withValues(alpha: isDark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: shsColor.withValues(alpha: isDark ? 0.45 : 0.35)),
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
                      showDocumentPreview(
                        context: context,
                        document: documents[i],
                      );
                    }
                  },
                  onActionSelected: (a) => _handleAction(a, documents[i]),
                  onViewProfile: (sid) => showStudentProfileModal(
                    context,
                    studentId: sid,
                    userRole: widget.userRole,
                    hideEnrollmentActions: true,
                  ),
                ),
              ),
            ),
            if (totalPages > 1 && !_searchFocusNode.hasFocus)
              _buildPagination(totalPages, currentPage)
            else if (_openedFolderStudentId != null)
              SizedBox(height: isMobileGrid ? 76 : 16),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LIST VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildListView(List documents, int totalPages, int currentPage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobileList = screenW < 700;
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.all(isMobileList ? 8 : 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
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
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(documentPageProvider);
                },
                child: ListView.separated(
                  itemCount: documents.length,
                  separatorBuilder: (ctx, i) =>
                      Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
                  itemBuilder: (ctx, i) {
                    final doc = documents[i] as DocumentModel;
                    return FileFolderCard(
                      document: doc,
                      isGrid: false,
                      userRole: widget.userRole,
                      isMultiSelectMode: _isMultiSelectMode,
                      isSelected: _selectedDocumentIds.contains(doc.id),
                      onSelectedChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedDocumentIds.add(doc.id);
                          } else {
                            _selectedDocumentIds.remove(doc.id);
                          }
                        });
                      },
                      onTap: () {
                        if (_isMultiSelectMode) {
                          setState(() {
                            if (_selectedDocumentIds.contains(doc.id)) {
                              _selectedDocumentIds.remove(doc.id);
                            } else {
                              _selectedDocumentIds.add(doc.id);
                            }
                          });
                        } else {
                          showDocumentPreview(
                            context: context,
                            document: doc,
                          );
                        }
                      },
                      onActionSelected: (a) => _handleAction(a, doc),
                      onViewProfile: (sid) => showStudentProfileModal(
                        context,
                        studentId: sid,
                        userRole: widget.userRole,
                        hideEnrollmentActions: true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (totalPages > 1 && !_searchFocusNode.hasFocus)
          _buildPagination(totalPages, currentPage)
        else if (_openedFolderStudentId != null)
          SizedBox(height: isMobileList ? 76 : 16),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // EMPTY / ERROR STATES
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmptyState({bool noSections = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Icon(
            Icons.folder_off_outlined,
            size: 72,
            color: isDark ? AppColors.darkTextMuted : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No documents found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a document or adjust your filters',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
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
    return AppErrorState.fromError(
      error: message,
      onRetry: () {
        ref.invalidate(documentPageProvider);
        ref.invalidate(foldersProvider);
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PAGINATION
  // ══════════════════════════════════════════════════════════════
  Widget _buildPagination(int totalPages, int currentPage) {
    if (_searchFocusNode.hasFocus) return const SizedBox.shrink();
    return AppPagination(
      currentPage: currentPage,
      totalPages: totalPages,
      onPageChanged: (p) =>
          ref.read(documentQueryProvider.notifier).setPage(p),
    );
  }

  Widget _buildFoldersPagination(int totalPages, int currentPage) {
    if (_searchFocusNode.hasFocus) return const SizedBox.shrink();
    return AppPagination(
      currentPage: currentPage,
      totalPages: totalPages,
      onPageChanged: (p) => setState(() => _foldersPage = p),
    );
  }

  Future<void> _showFolderContextMenu(
    Offset position,
    dynamic folder,
  ) async {
    if (folder.studentId == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<String>(
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
    );

    if (!mounted || value == null) return;
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
        hideEnrollmentActions: true,
      );
    }
  }
}
