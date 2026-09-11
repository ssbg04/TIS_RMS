import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/document_model.dart';
import '../../../domain/entities/folder_model.dart';
import '../../../domain/repositories/document_repository.dart'
    show DocumentPage;
import '../../shared/inputs/app_search_bar.dart';
import '../../shared/widgets/app_pagination.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/horizontal_expandable_fab.dart';
import '../../providers/archives_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/student_provider.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/conversion_provider.dart';
import '../documents/widgets/bulk_operations_bar.dart';
import '../documents/widgets/document_preview_modal.dart';
import '../documents/widgets/file_folder_card.dart';
import '../documents/widgets/print_queue_modal.dart';
import '../documents/widgets/student_profile_modal.dart';
import '../documents/widgets/download_guide_dialog.dart';
import '../documents/widgets/recycle_bin_modal.dart';
import '../../shared/dialogs/document_properties_dialog.dart';
import '../../../core/utils/download_service.dart';
import '../../../core/network/api_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ArchivesScreen extends ConsumerStatefulWidget {
  final String userRole;

  const ArchivesScreen({super.key, required this.userRole});

  @override
  ConsumerState<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends ConsumerState<ArchivesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();
  Timer? _debounce;
  Timer? _pollingTimer;
  late final TabController _tabController;
  bool _isGridView = false;

  // Folder open state
  int? _openedFolderStudentId;
  String? _openedFolderName;

  // Folder pagination
  int _foldersPage = 1;
  final int _foldersPerPage = 20;

  // Filter values
  String _selectedStatus = 'All Statuses';
  String _selectedDocumentType = 'All Types';
  String _selectedGradeLevel = 'All Grades';
  String _selectedSchoolYear = 'All Years';

  String _pendingStatus = 'All Statuses';
  String _pendingDocumentType = 'All Types';
  String _pendingGradeLevel = 'All Grades';
  String _pendingSchoolYear = 'All Years';

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedStatus != 'All Statuses') count++;
    if (_selectedDocumentType != 'All Types') count++;
    if (_selectedGradeLevel != 'All Grades') count++;
    if (_selectedSchoolYear != 'All Years') count++;
    return count;
  }

  // Cached doc type lists for filter expansion
  List<String> _jhsItems = [];
  List<String> _shsItems = [];

  // Multi-select
  bool _isMultiSelectMode = false;
  final Set<int> _selectedDocumentIds = {};

  ProviderSubscription<String>? _tabListener;
  ProviderSubscription<OpenedArchiveFolderData?>? _folderListener;

  bool get _isAdmin => widget.userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          ref.read(authProvider).value != null &&
          ref.read(activeTabProvider) == 'Archives') {
        ref.invalidate(archiveStudentFoldersProvider);
        ref.invalidate(archiveDocumentPageProvider);
      }
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isMultiSelectMode = false;
          _selectedDocumentIds.clear();
        });
        _clearFilters();
        ref.invalidate(archiveDocumentPageProvider);
        ref.invalidate(archiveStudentFoldersProvider);

        if (_tabController.index != 0 && _openedFolderStudentId != null) {
          setState(() {
            _openedFolderStudentId = null;
            _openedFolderName = null;
          });
          ref.read(archiveDocumentQueryProvider.notifier).setStudentId(null);
        }
      }
    });

    final initialArchiveFolder = ref.read(openedArchiveFolderProvider);
    if (initialArchiveFolder != null) {
      _openedFolderStudentId = initialArchiveFolder.id;
      _openedFolderName = initialArchiveFolder.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(archiveDocumentQueryProvider.notifier)
            .setStudentId(initialArchiveFolder.id);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(archiveDocumentQueryProvider.notifier).setPage(1);

      _folderListener = ref.listenManual<OpenedArchiveFolderData?>(
        openedArchiveFolderProvider,
        (previous, current) {
          if (!mounted) return;
          if (current != null && current.id != _openedFolderStudentId) {
            setState(() {
              _openedFolderStudentId = current.id;
              _openedFolderName = current.name;
              if (_searchController.text.isNotEmpty) _searchController.clear();
            });
            if (mounted && _tabController.index != 0) {
              _tabController.index = 0;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(archiveDocumentQueryProvider.notifier).setSearch('');
              // Trigger refresh/fetch if needed, or query updates
              ref
                  .read(archiveDocumentQueryProvider.notifier)
                  .setStudentId(current.id);
            });
          }
        },
      );

      if (ref.read(activeTabProvider) == 'Archives') {
        _shortcutFocusNode.requestFocus();
      }

      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (next != 'Archives') {
          ref.read(openedArchiveFolderProvider.notifier).setFolder(null);
          setState(() {
            _openedFolderStudentId = null;
            _openedFolderName = null;
            _isMultiSelectMode = false;
            if (_searchController.text.isNotEmpty) _searchController.clear();
            _selectedDocumentIds.clear();
          });
          ref.read(archiveDocumentQueryProvider.notifier).reset();
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
    });
  }

  @override
  void dispose() {
    _folderListener?.close();
    _tabListener?.close();
    _pollingTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _shortcutFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(archiveDocumentQueryProvider.notifier).setSearch(query);
    });
  }

  void _onSearchSubmitted(String query) {
    _debounce?.cancel();
    ref.read(archiveDocumentQueryProvider.notifier).setSearch(query);
  }

  void _applyFilters() {
    final n = ref.read(archiveDocumentQueryProvider.notifier);
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
    ref.read(archiveDocumentQueryProvider.notifier).reset();
  }

  // ── Restore archived student (admin) ────────────────────────────
  void _handleRestoreStudent(int studentId, String studentName) async {
    if (!_isAdmin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Restore Student'),
          ],
        ),
        content: Text(
          'Restore $studentName to Active (Enrolled) status? Their documents will also be set back to Completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(archiveMutationProvider.notifier)
          .restoreArchive(studentId);
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: '$studentName has been restored to Enrolled.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Restore Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ── Preview document ────────────────────────────────────────────
  void _handlePreview(DocumentModel doc) {
    showDocumentPreview(context: context, document: doc);
  }

  // ── Document file menu (print, download, preview) ──────────────
  Future<void> _handleDocumentAction(String action, DocumentModel doc) async {
    if (action == 'preview') {
      _handlePreview(doc);
    } else if (action == 'properties') {
      DocumentPropertiesDialog.show(context, document: doc);
    } else if (action == 'select') {
      setState(() {
        _isMultiSelectMode = true;
        _selectedDocumentIds.add(doc.id);
      });
    } else if (action == 'queue' || action == 'print') {
      try {
        await ref.read(printQueueMutationProvider.notifier).addToQueue(doc.id);
      } catch (_) {
        // Already in the print list - still open the queue.
      }
      if (!mounted) return;
      PrintQueueModal.show(context);
    } else if (action == 'copy') {
      try {
        await ref.read(documentMutationProvider.notifier).copyDocument(doc.id);
        if (!mounted) return;
        showSuccessDialog(context, message: 'Document copied successfully.');
        ref.invalidate(archiveDocumentPageProvider);
      } catch (e) {
        if (!mounted) return;
        showErrorDialog(context, 'Copy Failed', e.toString());
      }
    } else if (action == 'download') {
      try {
        final token =
            await const FlutterSecureStorage().read(key: 'jwt_token');
        if (token == null) return;
        final url =
            '${ApiConstants.baseUrl}/documents/${doc.id}/view?token=$token&download=true';

        await DownloadService.downloadFile(
          url: url,
          fileName: doc.fileName,
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
    } else if (action == 'convert_pdf') {
      try {
        final converted = await ref
            .read(conversionProvider.notifier)
            .convertToPdf(doc.id);
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
    } else if (action == 'view_profile' && doc.studentId != null) {
      showStudentProfileModal(
        context,
        studentId: doc.studentId!,
        userRole: widget.userRole,
        hideEnrollmentActions: true,
      );
    } else if (action == 'restore') {
      _confirmRestoreDocument(doc);
    } else if (action == 'delete') {
      _handleDeleteDocument(doc);
    }
  }

  void _confirmRestoreDocument(DocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.unarchive_outlined, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Restore Document'),
          ],
        ),
        content: Text(
          'Are you sure you want to restore "${doc.fileName}" to active documents?',
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
                    .updateStatus(doc.id, 'Completed');
                if (!mounted) return;
                showSuccessDialog(
                  context,
                  message: 'Document restored to active documents.',
                );
                ref.invalidate(archiveDocumentPageProvider);
                ref.invalidate(archiveStudentFoldersProvider);
              } catch (e) {
                if (!mounted) return;
                showErrorDialog(context, 'Restore Failed', e.toString());
              }
            },
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteDocument(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
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
          'Are you sure you want to permanently delete this document?',
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
          .deleteDocument(doc.id);
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: 'Document deleted.',
      );
      ref.invalidate(archiveDocumentPageProvider);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, 'Delete Failed', e.toString());
    }
  }

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
      ref.invalidate(archiveDocumentPageProvider);
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

      final docs = ref.read(archiveDocumentPageProvider).value?.documents ?? [];
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
      ref.invalidate(archiveDocumentPageProvider);
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
      ref.invalidate(archiveDocumentPageProvider);
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
    final pageDocs = ref.watch(archiveDocumentPageProvider).value?.documents ?? [];
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
      onBatchRestore: () => _handleBatchStatus('Completed'),
      onBatchDelete: _handleBatchDelete,
      isArchiveScreen: true,
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

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(archiveDocumentQueryProvider);
    final docState = ref.watch(archiveDocumentPageProvider);
    final foldersAsync = ref.watch(archiveStudentFoldersProvider);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
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
        if (ref.read(activeTabProvider) != 'Archives') return;
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
          ref.read(openedArchiveFolderProvider.notifier).setFolder(null);
          ref.read(archiveDocumentQueryProvider.notifier).setStudentId(null);
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
          ref.read(openedArchiveFolderProvider.notifier).setFolder(null);
          ref.read(archiveDocumentQueryProvider.notifier).setStudentId(null);
          return;
        }
        ref.read(activeTabProvider.notifier).setTab('Dashboard');
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: (isMobile &&
                widget.userRole != 'teacher' &&
                !_isMultiSelectMode &&
                !_searchFocusNode.hasFocus)
            ? HorizontalExpandableFab(
                heroTag: 'fab_archives_menu',
                items: [
                  // Print List Action
                  FabActionItem(
                    icon: Icons.print_rounded,
                    tooltip: 'Print List',
                    badgeCount: ref.watch(printQueueProvider).value?.length ?? 0,
                    heroTag: 'fab_archives_print_list',
                    onPressed: () => PrintQueueModal.show(context),
                  ),
                  // Multi-Select Action (available on All Archived Docs tab or in opened folder)
                  if (_tabController.index == 1 || isFolderOpened)
                    FabActionItem(
                      icon: Icons.checklist_rounded,
                      tooltip: 'Select Multiple',
                      heroTag: 'fab_archives_multi_select',
                      onPressed: () {
                        setState(() {
                          _isMultiSelectMode = true;
                        });
                      },
                    ),
                ],
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header or Inline Multi-Select Header ──
              if (_isMultiSelectMode)
                _buildInlineMultiSelectHeader()
              else
                _buildTopHeader(isMobile, isFolderOpened, query),

              // ── Tab Body ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Tab 0: Student Folders
                    _buildFoldersTab(foldersAsync, docState, query, isMobile),
                    // Tab 1: All Archived Docs
                    _buildDocumentsTab(docState, query, isMobile),
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

  // ════════════════════════════════════════════════════════════════
  // TOP HEADER (Unified with Segmented Tabs, styled like Multi-Select)
  // ════════════════════════════════════════════════════════════════
  void _closeFolder() {
    setState(() {
      _openedFolderStudentId = null;
      _openedFolderName = null;
      _isMultiSelectMode = false;
      _selectedDocumentIds.clear();
    });
    ref.read(openedArchiveFolderProvider.notifier).setFolder(null);
    ref.read(archiveDocumentQueryProvider.notifier).setStudentId(null);
    _clearFilters();
    ref.invalidate(archiveDocumentPageProvider);
    ref.invalidate(archiveStudentFoldersProvider);
  }

  Widget _buildSegmentedTabSwitcher(
    bool isDark,
    bool isMobile,
    bool isMobileOrAndroid,
  ) {
    final activeIndex = _tabController.index;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE9ECEF),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentedTabItem(
            index: 0,
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder_rounded,
            label: isMobile ? 'Folders' : 'Student Folders',
            isSelected: activeIndex == 0,
            isDark: isDark,
            isMobile: isMobile,
            isMobileOrAndroid: isMobileOrAndroid,
          ),
          const SizedBox(width: 2),
          _buildSegmentedTabItem(
            index: 1,
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: isMobile ? 'Archived' : 'All Archived Docs',
            isSelected: activeIndex == 1,
            isDark: isDark,
            isMobile: isMobile,
            isMobileOrAndroid: isMobileOrAndroid,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required bool isMobile,
    required bool isMobileOrAndroid,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () {
          if (_tabController.index == index) {
            if (index == 0 && _openedFolderStudentId != null) {
              _closeFolder();
            }
          } else {
            _tabController.animateTo(index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 13,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected && !isDark && !isMobileOrAndroid
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    bool isMobile,
    bool isFolderOpened,
    ArchiveDocumentQueryParams query,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobileOrAndroid =
        isMobile || defaultTargetPlatform == TargetPlatform.android;

    return RepaintBoundary(
      child: Container(
        height: 52,
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20,
          vertical: 8,
        ),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
            width: 1.0,
          ),
          boxShadow: isMobileOrAndroid
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left side: Folder breadcrumb or Segmented Tabs
            if (isFolderOpened) ...[
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                ),
                color: AppColors.primaryGreen,
                tooltip: 'Back to Folders',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: _closeFolder,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    if (!isMobile) ...[
                      InkWell(
                        onTap: _closeFolder,
                        child: Text(
                          'Student Folders',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        ' / ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        _openedFolderName!,
                        style: TextStyle(
                          fontSize: isMobile ? 14.5 : 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildSegmentedTabSwitcher(isDark, isMobile, isMobileOrAndroid),
              const Spacer(),
            ],

            // Action buttons
            if (!isFolderOpened) ...[
              Tooltip(
                richMessage: (_searchController.text.isNotEmpty ||
                        query.search.isNotEmpty)
                    ? const TextSpan(text: 'Clear Search')
                    : const TextSpan(
                        text: 'Search Archives ',
                        children: [
                          TextSpan(
                            text: '(Ctrl+F)',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                child: IconButton(
                  icon: Icon(
                    (_searchController.text.isNotEmpty ||
                            query.search.isNotEmpty)
                        ? Icons.close
                        : Icons.search,
                    size: 20,
                    color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty ||
                        query.search.isNotEmpty) {
                      _searchController.clear();
                      ref
                          .read(archiveDocumentQueryProvider.notifier)
                          .setSearch('');
                      setState(() => _foldersPage = 1);
                      ref.invalidate(archiveStudentFoldersProvider);
                      ref.invalidate(archiveDocumentPageProvider);
                    } else {
                      _showSearchDialog(context);
                    }
                  },
                ),
              ),
            ],

            const SizedBox(width: 2),

            // Multi-Select Toggle (Desktop non-Windows only, icon only)
            if (!isMobile &&
                defaultTargetPlatform != TargetPlatform.windows &&
                widget.userRole != 'teacher' &&
                (_tabController.index == 1 || isFolderOpened)) ...[
              Tooltip(
                message: _isMultiSelectMode
                    ? 'Exit Multi-Select'
                    : 'Multi-Select',
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.all(8),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () {
                    setState(() {
                      _isMultiSelectMode = !_isMultiSelectMode;
                      if (!_isMultiSelectMode) _selectedDocumentIds.clear();
                    });
                  },
                  icon: Icon(
                    Icons.checklist_rounded,
                    size: 20,
                    color: _isMultiSelectMode
                        ? AppColors.primaryGreen
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 2),
            ],

            // Filter button (Icon only, between Search and Print)
            if (_tabController.index == 1 || isFolderOpened) ...[
              Tooltip(
                message: 'Filter Documents',
                child: IconButton(
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: _openFilterDialog,
                  icon: Badge(
                    isLabelVisible: _getActiveFilterCount() > 0,
                    label: Text(_getActiveFilterCount().toString()),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: _getActiveFilterCount() > 0
                          ? AppColors.primaryGreen
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : Colors.black87),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
            ],

            // Print List Button (Desktop non-mobile)
            if (defaultTargetPlatform != TargetPlatform.android &&
                !isMobile &&
                widget.userRole != 'teacher') ...[
              SizedBox(
                height: 36,
                child: _buildPrintQueueButton(compact: false),
              ),
              const SizedBox(width: 6),
            ],

            // Dropdown Menu
            SizedBox(
              height: 36,
              width: 36,
              child: _buildMoreOptionsDropdown(isMobile),
            ),

            if (!isMobile) ...[
              const SizedBox(width: 2),
              // Info Button for Download Guide (Desktop)
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                padding: const EdgeInsets.all(8),
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Download Guide',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const DownloadGuideDialog(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FILTER PANEL
  // ════════════════════════════════════════════════════════════════
  void _openFilterDialog() {
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
                setDialogState,
                () => Navigator.of(ctx).pop(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPanelContent(
    StateSetter setDialogState,
    VoidCallback onApply,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final academicYearsAsync = ref.watch(academicYearsProvider);
    final requirementsAsync = ref.watch(documentRequirementsProvider);

    final jhsItems = requirementsAsync.when(
      data: (reqs) =>
          reqs
              .where((r) => r.category == 'JHS')
              .map((r) => r.name)
              .toSet()
              .toList()
            ..sort(),
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    final shsItems = requirementsAsync.when(
      data: (reqs) =>
          reqs
              .where((r) => r.category == 'SHS')
              .map((r) => r.name)
              .toSet()
              .toList()
            ..sort(),
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    if (jhsItems.isNotEmpty) _jhsItems = jhsItems;
    if (shsItems.isNotEmpty) _shsItems = shsItems;

    final docTypes = [
      'All Types',
      'All JHS',
      'All SHS',
      ...jhsItems,
      ...shsItems,
    ];

    final years = academicYearsAsync.when(
      data: (y) => ['All Years', ...y.map((ay) => ay.yearRange)],
      loading: () => const ['All Years'],
      error: (_, _) => const ['All Years'],
    );

    const statusItems = [
      'All Statuses',
      'Graduated',
      'Transferred',
      'Dropped',
      'Inactive',
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
                      'Filter Archives',
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
                  // Student Status (Chip Group for 3-5 options)
                  _buildFilterSection(
                    label: 'Student Status',
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
                      value: docTypes.contains(_pendingDocumentType)
                          ? _pendingDocumentType
                          : 'All Types',
                      items: docTypes,
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
                      setState(() {
                        _selectedStatus = 'All Statuses';
                        _selectedDocumentType = 'All Types';
                        _selectedGradeLevel = 'All Grades';
                        _selectedSchoolYear = 'All Years';
                      });
                      _applyFilters();
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
                    onPressed: () {
                      setState(() {
                        _selectedStatus = _pendingStatus;
                        _selectedDocumentType = _pendingDocumentType;
                        _selectedGradeLevel = _pendingGradeLevel;
                        _selectedSchoolYear = _pendingSchoolYear;
                      });
                      _applyFilters();
                      onApply();
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
    final safeValue = items.contains(value) ? value : items.firstOrNull;

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
          value: safeValue,
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
            final isItemActive = item == safeValue;
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

  // ════════════════════════════════════════════════════════════════
  // MORE OPTIONS DROPDOWN (matches Documents screen style)
  // ════════════════════════════════════════════════════════════════
  Widget _buildMoreOptionsDropdown(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        } else if (value == 'recycle_bin') {
          showDialog(
            context: context,
            builder: (_) => const RecycleBinModal(),
          );
        } else if (value == 'download_guide') {
          showDialog(
            context: context,
            builder: (_) => const DownloadGuideDialog(),
          );
        }
      },
      itemBuilder: (context) => [
        if (!isMobile &&
            widget.userRole != 'teacher' &&
            (_tabController.index == 1 || _openedFolderStudentId != null)) ...[
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
                  _isMultiSelectMode
                      ? 'Exit Multi-Select'
                      : 'Select Multiple',
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
                _isGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
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
        if (isMobile) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'download_guide',
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.primaryGreen,
                ),
                SizedBox(width: 8),
                Text('Download Guide', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // STUDENT FOLDERS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildFoldersTab(
    AsyncValue<List<FolderModel>> foldersAsync,
    AsyncValue<DocumentPage> docState,
    ArchiveDocumentQueryParams query,
    bool isMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // If a folder is opened, show that student's documents
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
                  ? _buildEmptyState('No archived documents for this student.')
                  : _isGridView
                  ? _buildArchiveGridView(
                      pageData.documents,
                      isMobile,
                      pageData.totalPages,
                      query.page,
                    )
                  : _buildArchiveListView(
                      pageData.documents,
                      isMobile,
                      pageData.totalPages,
                      query.page,
                    ),
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
          return _buildEmptyState(
            'No archived student folders found.\nStudents that have Graduated, Transferred, Dropped, or Inactive will appear here.',
          );
        }

        final totalRows = folders.length;
        final totalPages = totalRows > 0
            ? (totalRows / _foldersPerPage).ceil()
            : 1;

        // Ensure current page is valid
        if (_foldersPage > totalPages) {
          _foldersPage = totalPages;
        } else if (_foldersPage < 1) {
          _foldersPage = 1;
        }

        final startIndex = (_foldersPage - 1) * _foldersPerPage;
        final endIndex = (startIndex + _foldersPerPage > totalRows)
            ? totalRows
            : startIndex + _foldersPerPage;
        final paginatedFolders = folders.sublist(startIndex, endIndex);

        Widget containerList = Container(
          margin: EdgeInsets.only(
            left: isMobile ? 8 : 16,
            right: isMobile ? 8 : 16,
            top: isMobile ? 12 : 16,
            bottom: isMobile ? 16 : 16,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: isMobile
                ? Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  )
                : null,
            boxShadow: isMobile
                ? null
                : [
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
                ref.invalidate(archiveStudentFoldersProvider);
                ref.invalidate(archiveDocumentPageProvider);
              },
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: paginatedFolders.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
                itemBuilder: (ctx, i) {
                  final folder = paginatedFolders[i];
                  final studentName =
                      '${folder.studentLastName ?? ''}, ${folder.studentFirstName ?? ''}';

                  return RepaintBoundary(
                    child: GestureDetector(
                      onSecondaryTapDown: (details) => _showFolderContextMenu(
                        details.globalPosition,
                        folder,
                      ),
                      onLongPressStart: (details) => _showFolderContextMenu(
                        details.globalPosition,
                        folder,
                      ),
                      child: InkWell(
                        onTap: () {
                          if (folder.studentId != null) {
                            setState(() {
                              _openedFolderStudentId = folder.studentId;
                              _openedFolderName = studentName;
                            });
                            ref
                                .read(archiveDocumentQueryProvider.notifier)
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
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withValues(
                                    alpha: isDark ? 0.16 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.folder_special_rounded,
                                    size: 22,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      studentName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${folder.documentCount ?? 0} ${folder.documentCount == 1 ? "item" : "items"}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStudentStatusChip(
                                          folder.studentStatus ?? 'Archived',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (_isAdmin)
                                _buildFolderActionMenu(
                                  folder.studentId!,
                                  studentName,
                                ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // Grid view
        Widget gridView = LayoutBuilder(
          builder: (ctx, c) {
            final cols = isMobile
                ? 2
                : (c.maxWidth / 160.0).floor().clamp(2, 6);
            return GridView.builder(
              padding: EdgeInsets.only(
                left: isMobile ? 10 : 16,
                right: isMobile ? 10 : 16,
                top: isMobile ? 14 : 16,
                bottom: isMobile ? 24 : 16,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: isMobile ? 10 : 14,
                mainAxisSpacing: isMobile ? 10 : 14,
                childAspectRatio: isMobile ? 0.85 : 0.95,
              ),
              itemCount: paginatedFolders.length,
              itemBuilder: (ctx, i) {
                final folder = paginatedFolders[i];
                final studentName =
                    '${folder.studentLastName ?? ''}, ${folder.studentFirstName ?? ''}';
                return RepaintBoundary(
                  child: GestureDetector(
                    onSecondaryTapDown: (details) => _showFolderContextMenu(
                      details.globalPosition,
                      folder,
                    ),
                    onLongPressStart: (details) => _showFolderContextMenu(
                      details.globalPosition,
                      folder,
                    ),
                    child: InkWell(
                      onTap: () {
                        if (folder.studentId != null) {
                          setState(() {
                            _openedFolderStudentId = folder.studentId;
                            _openedFolderName = studentName;
                          });
                          ref
                              .read(archiveDocumentQueryProvider.notifier)
                              .setStudentId(folder.studentId);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                          boxShadow: isMobile
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_special_rounded,
                                  size: isMobile ? 38 : 46,
                                  color: Colors.deepOrange,
                                ),
                                SizedBox(height: isMobile ? 6 : 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    studentName,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 12 : 13,
                                      height: 1.2,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildStudentStatusChip(
                                  folder.studentStatus ?? 'Archived',
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${folder.documentCount ?? 0} docs',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
              },
            );
          },
        );

        return Column(
          children: [
            Expanded(child: !_isGridView ? containerList : gridView),
            if (totalPages > 1 && !_searchFocusNode.hasFocus)
              _buildFoldersPagination(totalPages, _foldersPage),
          ],
        );
      },
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
    final studentName =
        '${folder.studentLastName ?? ''}, ${folder.studentFirstName ?? ''}';

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
              Icon(Icons.folder_open, size: 18, color: Colors.deepOrange),
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
        if (_isAdmin) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'restore',
            child: Row(
              children: [
                Icon(Icons.restore, size: 18, color: AppColors.primaryGreen),
                SizedBox(width: 12),
                Text('Restore to Active', style: TextStyle(fontSize: 14, color: AppColors.primaryGreen)),
              ],
            ),
          ),
        ],
      ],
    );

    if (!mounted || value == null) return;
    if (value == 'open') {
      setState(() {
        _openedFolderStudentId = folder.studentId;
        _openedFolderName = studentName;
      });
      ref
          .read(archiveDocumentQueryProvider.notifier)
          .setStudentId(folder.studentId);
    } else if (value == 'view_profile') {
      showStudentProfileModal(
        context,
        studentId: folder.studentId!,
        userRole: widget.userRole,
        hideEnrollmentActions: true,
      );
    } else if (value == 'restore') {
      _handleRestoreStudent(folder.studentId!, studentName);
    }
  }

  Widget _buildFolderActionMenu(int studentId, String studentName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      tooltip: 'Actions',
      onSelected: (val) {
        if (val == 'view_profile') {
          showStudentProfileModal(
            context,
            studentId: studentId,
            userRole: widget.userRole,
            hideEnrollmentActions: true,
          );
        } else if (val == 'restore') {
          _handleRestoreStudent(studentId, studentName);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'view_profile',
          child: Row(
            children: [
              Icon(Icons.person, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'View Profile',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'restore',
          child: Row(
            children: [
              Icon(Icons.restore, color: AppColors.primaryGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Restore to Active',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ALL ARCHIVED DOCS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildDocumentsTab(
    AsyncValue<DocumentPage> docState,
    ArchiveDocumentQueryParams query,
    bool isMobile,
  ) {
    return Column(
      children: [
        Expanded(
          child: docState.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
            error: (e, _) => _buildErrorState(e.toString()),
            data: (pageData) => pageData.documents.isEmpty
                ? _buildEmptyState(
                    'No archived documents found.\nAdjust filters or search terms.',
                  )
                : _isGridView
                ? _buildArchiveGridView(
                    pageData.documents,
                    isMobile,
                    pageData.totalPages,
                    query.page,
                  )
                : _buildArchiveListView(
                    pageData.documents,
                    isMobile,
                    pageData.totalPages,
                    query.page,
                  ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ARCHIVE LIST VIEW
  // ════════════════════════════════════════════════════════════════
  Widget _buildArchiveListView(
    List<DocumentModel> documents,
    bool isMobile,
    int totalPages,
    int currentPage,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: isMobile ? 8 : 16,
              right: isMobile ? 8 : 16,
              top: isMobile ? 12 : 16,
              bottom: isMobile ? 16 : 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: isMobile
                  ? Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    )
                  : null,
              boxShadow: isMobile
                  ? null
                  : [
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
                  ref.invalidate(archiveDocumentPageProvider);
                },
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: documents.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100),
                  itemBuilder: (ctx, i) {
                    final doc = documents[i];
                    return FileFolderCard(
                      document: doc,
                      isGrid: false,
                      userRole: widget.userRole,
                      isArchiveScreen: true,
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
                          _handlePreview(doc);
                        }
                      },
                      onActionSelected: (a) => _handleDocumentAction(a, doc),
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
          SizedBox(height: isMobile ? 76 : 16),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ARCHIVE GRID VIEW
  // ════════════════════════════════════════════════════════════════
  Widget _buildArchiveGridView(
    List<DocumentModel> documents,
    bool isMobile,
    int totalPages,
    int currentPage,
  ) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final isMobileGrid = isMobile;
        final cols = isMobileGrid
            ? 2
            : (c.maxWidth / 160.0).floor().clamp(2, 6);
        final aspect = isMobileGrid ? 0.82 : 0.95;
        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.only(
                  left: isMobileGrid ? 10 : 16,
                  right: isMobileGrid ? 10 : 16,
                  top: isMobileGrid ? 12 : 16,
                  bottom: isMobileGrid ? 24 : 16,
                ),
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
                  isArchiveScreen: true,
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
                      _handlePreview(documents[i]);
                    }
                  },
                  onActionSelected: (a) => _handleDocumentAction(a, documents[i]),
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
  // ════════════════════════════════════════════════════════════════
  // PAGINATION
  // ════════════════════════════════════════════════════════════════
  Widget _buildPagination(int totalPages, int currentPage) {
    if (_searchFocusNode.hasFocus) return const SizedBox.shrink();
    return AppPagination(
      currentPage: currentPage,
      totalPages: totalPages,
      onPageChanged: (p) =>
          ref.read(archiveDocumentQueryProvider.notifier).setPage(p),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return AppErrorState.fromError(
      error: error,
      onRetry: () {
        ref.invalidate(archiveDocumentPageProvider);
        ref.invalidate(archiveStudentFoldersProvider);
      },
    );
  }

  Widget _buildStudentStatusChip(String status) {
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ],
    );
  }
}
