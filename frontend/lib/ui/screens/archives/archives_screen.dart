import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/document_model.dart';
import '../../../domain/entities/folder_model.dart';
import '../../../domain/repositories/document_repository.dart'
    show DocumentPage;
import '../../shared/inputs/app_search_bar.dart';
import '../../providers/archives_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/student_provider.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../documents/widgets/document_preview_modal.dart';

class ArchivesScreen extends ConsumerStatefulWidget {
  final String userRole;

  const ArchivesScreen({super.key, required this.userRole});

  @override
  ConsumerState<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends ConsumerState<ArchivesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _pollingTimer;
  late final TabController _tabController;
  bool _isGridView = false;
  bool _showFilters = false;

  // Folder open state
  int? _openedFolderStudentId;
  String? _openedFolderName;

  // Filter values
  String _selectedStatus = 'All Statuses';
  String _selectedDocumentType = 'All Types';
  String _selectedGradeLevel = 'All Grades';
  String _selectedSchoolYear = 'All Years';

  // Cached doc type lists for filter expansion
  List<String> _jhsItems = [];
  List<String> _shsItems = [];

  // Multi-select
  bool _isMultiSelectMode = false;
  final Set<int> _selectedDocumentIds = {};

  ProviderSubscription<String>? _tabListener;

  bool get _isAdmin => widget.userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      ref.invalidate(archiveStudentFoldersProvider);
      ref.invalidate(archiveDocumentPageProvider);
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _showFilters = false;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabListener = ref.listenManual<String>(activeTabProvider, (previous, next) {
        if (!mounted) return;
        if (next == 'Archives' && previous != 'Archives') {
          if (_openedFolderStudentId != null) {
            setState(() {
              _openedFolderStudentId = null;
              _openedFolderName = null;
            });
          }
          if (_tabController.index != 0) {
            _tabController.animateTo(0);
          }
          ref.invalidate(archiveStudentFoldersProvider);
          ref.invalidate(archiveDocumentPageProvider);
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
    _pollingTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(archiveDocumentQueryProvider.notifier).setSearch(query);
    });
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

  // ── Purge archived student (admin) ──────────────────────────────
  void _handlePurgeStudent(int studentId, String studentName) async {
    if (!_isAdmin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: AppColors.error),
            SizedBox(width: 8),
            Text('Permanent Purge', style: TextStyle(color: AppColors.error)),
          ],
        ),
        content: Text(
          'Permanently delete $studentName and ALL their documents? This CANNOT be undone.',
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
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // ── Password Confirmation ──
    if (!mounted) return;
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? errorMessage;

    final passwordConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.security, color: AppColors.error),
              SizedBox(width: 8),
              Text('Security Verification', style: TextStyle(color: AppColors.error)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please enter your admin password to confirm the permanent purge:'),
              const SizedBox(height: 16),
              CustomTextField(
                hintText: 'Admin Password',
                prefixIcon: Icons.lock_outline,
                controller: passwordController,
                isPassword: true,
                obscureText: obscurePassword,
                onToggleVisibility: () => setState(() => obscurePassword = !obscurePassword),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
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
              onPressed: () async {
                final pwd = passwordController.text;
                if (pwd.isEmpty) {
                  setState(() => errorMessage = 'Password is required');
                  return;
                }
                try {
                  final isVerified = await ref.read(authProvider.notifier).verifyPassword(pwd);
                  if (isVerified) {
                    Navigator.pop(ctx, true);
                  } else {
                    setState(() => errorMessage = 'Incorrect password');
                  }
                } catch (e) {
                   setState(() => errorMessage = 'Error verifying password');
                }
              },
              child: const Text('CONFIRM PURGE'),
            ),
          ],
        ),
      ),
    );

    if (passwordConfirmed != true) return;

    try {
      await ref.read(archiveMutationProvider.notifier).purgeArchive(studentId);
      if (!mounted) return;
      showSuccessDialog(
        context,
        message: '$studentName has been permanently purged.',
      );
      if (_openedFolderStudentId == studentId) {
        setState(() {
          _openedFolderStudentId = null;
          _openedFolderName = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Purge Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ── Preview document ────────────────────────────────────────────
  void _handlePreview(DocumentModel doc) {
    showDocumentPreview(context, doc);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(archiveDocumentQueryProvider);
    final docState = ref.watch(archiveDocumentPageProvider);
    final foldersAsync = ref.watch(archiveStudentFoldersProvider);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final isFolderOpened = _openedFolderStudentId != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: _isMultiSelectMode
            ? _buildBatchActionsBar(isMobile)
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header ──
              _buildTopHeader(isMobile, isFolderOpened, query),

              // ── TabBar ──
              Container(
                color: AppColors.surfaceWhite,
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    if (index == _tabController.index &&
                        index == 0 &&
                        _openedFolderStudentId != null) {
                      setState(() {
                        _openedFolderStudentId = null;
                        _openedFolderName = null;
                      });
                      ref
                          .read(archiveDocumentQueryProvider.notifier)
                          .setStudentId(null);
                      _clearFilters();
                      ref.invalidate(archiveDocumentPageProvider);
                      ref.invalidate(archiveStudentFoldersProvider);
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
                      icon: Icon(Icons.folder_special_rounded, size: 18),
                      text: 'Student Folders',
                    ),
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      text: 'All Archived Docs',
                    ),
                  ],
                ),
              ),

              // ── Filter Panel ──
              if (_showFilters) _buildFilterPanel(isMobile),

              const Divider(height: 1),

              // ── Tab Body ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
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
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TOP HEADER
  // ════════════════════════════════════════════════════════════════
  Widget _buildTopHeader(
    bool isMobile,
    bool isFolderOpened,
    ArchiveDocumentQueryParams query,
  ) {
    final hPad = isMobile ? 12.0 : 20.0;
    return Container(
      color: AppColors.surfaceWhite,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back / archive icon
              IconButton(
                icon: Icon(
                  isFolderOpened
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.archive_rounded,
                  size: 20,
                ),
                color: AppColors.primaryGreen,
                tooltip: isFolderOpened ? 'Back to Folders' : null,
                onPressed: isFolderOpened
                    ? () {
                        setState(() {
                          _openedFolderStudentId = null;
                          _openedFolderName = null;
                          _showFilters = false;
                          _isMultiSelectMode = false;
                          _selectedDocumentIds.clear();
                        });
                        ref
                            .read(archiveDocumentQueryProvider.notifier)
                            .setStudentId(null);
                      }
                    : null,
              ),
              const SizedBox(width: 6),

              // Screen title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _openedFolderName ?? 'System Archive',
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 21,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isFolderOpened)
                      const Text(
                        'Graduated · Transferred · Dropped · Enrolled Archived Docs',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),

              // Desktop view toggle (not on mobile, not when folder is opened)
              if (!isMobile) ...[
                const SizedBox(width: 8),
                _buildIconToggle(
                  icon: _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  isActive: false,
                  tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                  onTap: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // ── Search + Icon-controls row ──
          Row(
            children: [
              Expanded(
                child: AppSearchBar(
                  hint: 'Search by name, LRN, file…',
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  maxWidth: double.infinity,
                ),
              ),
              const SizedBox(width: 8),

              // Filter toggle (only on documents tab or when a folder is opened)
              if (_tabController.index == 1 || isFolderOpened) ...[
                _buildIconToggle(
                  icon: Icons.tune_rounded,
                  isActive: _showFilters,
                  tooltip: 'Toggle Filters',
                  onTap: () => setState(() => _showFilters = !_showFilters),
                ),
                const SizedBox(width: 6),
              ],

              // Multi-select toggle (docs tab or folder opened) - Hidden per user request
              /*
              if (_tabController.index == 1 || isFolderOpened) ...[
                _buildIconToggle(
                  icon: _isMultiSelectMode
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  isActive: _isMultiSelectMode,
                  tooltip: 'Toggle Selection Mode',
                  onTap: () {
                    setState(() {
                      _isMultiSelectMode = !_isMultiSelectMode;
                      if (!_isMultiSelectMode) _selectedDocumentIds.clear();
                    });
                  },
                ),
                const SizedBox(width: 6),
              ],
              */

              // Mobile view toggle
              if (isMobile) ...[
                _buildIconToggle(
                  icon: _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  isActive: false,
                  tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                  onTap: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FILTER PANEL
  // ════════════════════════════════════════════════════════════════
  Widget _buildFilterPanel(bool isMobile) {
    final academicYearsAsync = ref.watch(academicYearsProvider);
    final requirementsAsync = ref.watch(documentRequirementsProvider);

    final jhsItems = requirementsAsync.when(
      data: (reqs) => reqs.where((r) => r.category == 'JHS').map((r) => r.name as String).toSet().toList()..sort(),
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    final shsItems = requirementsAsync.when(
      data: (reqs) => reqs.where((r) => r.category == 'SHS').map((r) => r.name as String).toSet().toList()..sort(),
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    // Cache for use in _applyFilters
    if (jhsItems.isNotEmpty) _jhsItems = jhsItems;
    if (shsItems.isNotEmpty) _shsItems = shsItems;

    final docTypes = ['All Types', 'All JHS', 'All SHS', ...jhsItems, ...shsItems];

    final years = academicYearsAsync.when(
      data: (y) => ['All Years', ...y.map((ay) => ay.yearRange)],
      loading: () => const ['All Years'],
      error: (_, _) => const ['All Years'],
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
                label: 'Student Status',
                value: _selectedStatus,
                items: const [
                  'All Statuses',
                  'Graduated',
                  'Transferred',
                  'Dropped',
                ],
                onChanged: (v) {
                  setState(() => _selectedStatus = v!);
                  _applyFilters();
                },
              ),
              _buildDropdown(
                label: 'Document Type',
                value: _selectedDocumentType,
                items: docTypes,
                onChanged: (v) {
                  setState(() => _selectedDocumentType = v!);
                  _applyFilters();
                },
              ),
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

  // ════════════════════════════════════════════════════════════════
  // ICON TOGGLE (matches Documents screen style)
  // ════════════════════════════════════════════════════════════════
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

  // ════════════════════════════════════════════════════════════════
  // STUDENT FOLDERS TAB
  // ════════════════════════════════════════════════════════════════
  Widget _buildFoldersTab(
    AsyncValue<List<FolderModel>> foldersAsync,
    AsyncValue<DocumentPage> docState,
    ArchiveDocumentQueryParams query,
    bool isMobile,
  ) {
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
                  ? _buildArchiveGridView(pageData.documents, isMobile)
                  : _buildArchiveListView(pageData.documents, isMobile),
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
          return _buildEmptyState(
            'No archived student folders found.\nStudents that have Graduated, Transferred, or Dropped will appear here.',
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
                  // Table header
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
                          flex: 3,
                          child: Text(
                            'Student Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (!isMobile) ...[
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
                          const Expanded(
                            child: Text(
                              'Documents',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        if (_isAdmin) const SizedBox(width: 80),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: folders.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (ctx, i) {
                        final folder = folders[i];
                        final studentName =
                            '${folder.studentLastName ?? ''}, ${folder.studentFirstName ?? ''}';

                        return InkWell(
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
                                const Icon(
                                  Icons.folder_special_rounded,
                                  size: 28,
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        folder.studentLrn ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isMobile) ...[
                                  Expanded(
                                    child: _buildStudentStatusChip('Archived'),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${folder.documentCount ?? 0} docs',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                                if (_isAdmin)
                                  _buildFolderActionMenu(
                                    folder.studentId!,
                                    studentName,
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

        // Grid view
        return LayoutBuilder(
          builder: (ctx, c) {
            final tileBase = isMobile ? 140.0 : 180.0;
            final cols = isMobile
                ? 2
                : (c.maxWidth / tileBase).floor().clamp(2, 6);
            return GridView.builder(
              padding: EdgeInsets.all(isMobile ? 10 : 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: isMobile ? 10 : 16,
                mainAxisSpacing: isMobile ? 10 : 16,
                childAspectRatio: isMobile ? 0.85 : 0.95,
              ),
              itemCount: folders.length,
              itemBuilder: (ctx, i) {
                final folder = folders[i];
                final studentName =
                    '${folder.studentLastName ?? ''}, ${folder.studentFirstName ?? ''}';
                return InkWell(
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
                          Icons.folder_special_rounded,
                          size: isMobile ? 36 : 48,
                          color: Colors.deepOrange,
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            studentName,
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
                        const SizedBox(height: 4),
                        Text(
                          '${folder.documentCount ?? 0} docs',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 4),
                          _buildFolderActionMenu(
                            folder.studentId!,
                            studentName,
                          ),
                        ],
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

  Widget _buildFolderActionMenu(int studentId, String studentName) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
      tooltip: 'Actions',
      onSelected: (val) {
        if (val == 'restore') _handleRestoreStudent(studentId, studentName);
        if (val == 'purge') _handlePurgeStudent(studentId, studentName);
      },
      itemBuilder: (ctx) => [
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
        const PopupMenuItem(
          value: 'purge',
          child: Row(
            children: [
              Icon(Icons.delete_forever, color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text(
                'Permanently Purge',
                style: TextStyle(color: AppColors.error),
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
                ? _buildArchiveGridView(pageData.documents, isMobile)
                : _buildArchiveListView(pageData.documents, isMobile),
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

  // ════════════════════════════════════════════════════════════════
  // ARCHIVE LIST VIEW
  // ════════════════════════════════════════════════════════════════
  Widget _buildArchiveListView(List<DocumentModel> documents, bool isMobile) {
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
            // Table header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: 10,
              ),
              color: AppColors.primaryGreen.withValues(alpha: 0.06),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  const SizedBox(width: 8),
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
                  if (!isMobile) ...[
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
                  ],
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
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (ctx, i) => isMobile
                    ? _buildMobileListRow(documents[i])
                    : _buildDesktopListRow(documents[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopListRow(DocumentModel doc) {
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
        } else {
          _handlePreview(doc);
        }
      },
      child: Container(
        color: isSelected
            ? AppColors.primaryGreen.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (_isMultiSelectMode)
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
              )
            else
              _buildFileIcon(doc.documentType),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _formatDate(doc.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.studentName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (doc.studentLrn != null)
                    Text(
                      doc.studentLrn!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                doc.documentType ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(child: _buildStatusChip(doc.status)),
            SizedBox(
              width: 40,
              child: IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                color: AppColors.textSecondary,
                tooltip: 'Preview',
                onPressed: () => _handlePreview(doc),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileListRow(DocumentModel doc) {
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
        } else {
          _handlePreview(doc);
        }
      },
      child: Container(
        color: isSelected
            ? AppColors.primaryGreen.withValues(alpha: 0.06)
            : Colors.transparent,
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

            // File icon always visible
            _buildFileIcon(doc.documentType),
            const SizedBox(width: 10),

            // Stacked info: file name + student + doc type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.fileName,
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
                    doc.studentName ??
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
                  if (doc.documentType != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      doc.documentType!,
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
            // Status and action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusChip(doc.status),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _handlePreview(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ARCHIVE GRID VIEW
  // ════════════════════════════════════════════════════════════════
  Widget _buildArchiveGridView(List<DocumentModel> documents, bool isMobile) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = isMobile ? 2 : (c.maxWidth / 180).floor().clamp(2, 6);
        return GridView.builder(
          padding: EdgeInsets.all(isMobile ? 10 : 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: isMobile ? 10 : 12,
            mainAxisSpacing: isMobile ? 10 : 12,
            childAspectRatio: isMobile ? 0.85 : 1.0,
          ),
          itemCount: documents.length,
          itemBuilder: (ctx, i) {
            final doc = documents[i];
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
                } else {
                  _handlePreview(doc);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen.withValues(alpha: 0.08)
                      : AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Colors.grey.shade200,
                  ),
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
                    if (_isMultiSelectMode)
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
                      )
                    else
                      _buildFileIcon(
                        doc.documentType,
                        size: isMobile ? 32 : 40,
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        doc.fileName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(doc.status),
                    if (doc.studentName != null) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          doc.studentName!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // BATCH ACTIONS BAR (multi-select)
  // ════════════════════════════════════════════════════════════════
  Widget _buildBatchActionsBar(bool isMobile) {
    final count = _selectedDocumentIds.length;

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
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isMultiSelectMode = false;
                        _selectedDocumentIds.clear();
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Desktop bar
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.surfaceWhite,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count selected',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _isMultiSelectMode = false;
                _selectedDocumentIds.clear();
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // PAGINATION
  // ════════════════════════════════════════════════════════════════
  Widget _buildPagination(int totalPages, int currentPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => ref
                      .read(archiveDocumentQueryProvider.notifier)
                      .setPage(currentPage - 1)
                : null,
          ),
          Text(
            'Page $currentPage of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => ref
                      .read(archiveDocumentQueryProvider.notifier)
                      .setPage(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String? docType, {double size = 28}) {
    final ext = (docType ?? '').toLowerCase();
    IconData icon;
    Color color;
    if (ext.contains('pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (ext.contains('image') ||
        ext.contains('jpg') ||
        ext.contains('png')) {
      icon = Icons.image;
      color = Colors.purple;
    } else if (ext.contains('word') || ext.contains('doc')) {
      icon = Icons.description;
      color = Colors.blue;
    } else if (ext.contains('excel') ||
        ext.contains('sheet') ||
        ext.contains('xls')) {
      icon = Icons.table_chart;
      color = Colors.green;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.blueGrey;
    }
    return Icon(icon, size: size, color: color);
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    if (status == 'Completed') {
      bg = AppColors.primaryGreen.withValues(alpha: 0.1);
      fg = AppColors.primaryGreen;
    } else if (status == 'Archived') {
      bg = Colors.orange.withValues(alpha: 0.1);
      fg = Colors.orange.shade700;
    } else {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildStudentStatusChip(String status) {
    final colorMap = {
      'Graduated': Colors.blue.shade700,
      'Transferred': Colors.purple.shade600,
      'Dropped': Colors.red.shade600,
      'Enrolled': AppColors.primaryGreen,
    };
    final color = colorMap[status] ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
