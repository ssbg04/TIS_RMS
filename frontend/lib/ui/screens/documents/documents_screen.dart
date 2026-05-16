import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../providers/document_provider.dart';
import '../../providers/student_provider.dart';
import '../students/student_detail_screen.dart';
import 'widgets/file_folder_card.dart';
import 'widgets/upload_ocr_modal.dart';
import 'widgets/print_queue_modal.dart';

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

  // Filter values — kept in sync with provider
  String _selectedStatus = 'All Statuses';
  String _selectedDocumentType = 'All Types';
  String _selectedGradeLevel = 'All Grades';
  String _selectedSchoolYear = 'All Years';

  @override
  void initState() {
    super.initState();
    // 2 tabs: 0=Folders, 1=Documents
    _tabController = TabController(length: 2, vsync: this);
    // If a specific student was passed, jump directly to Documents tab
    if (widget.initialStudentId != null) {
      _tabController.index = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(documentQueryProvider.notifier)
            .setStudentId(widget.initialStudentId);
      });
    }
  }

  @override
  void dispose() {
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
    n.setDocumentType(_selectedDocumentType);
    n.setGradeLevel(
        _selectedGradeLevel == 'All Grades' ? '' : _selectedGradeLevel);
    n.setSchoolYear(
        _selectedSchoolYear == 'All Years' ? '' : _selectedSchoolYear);
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
  }

  void _handleAction(String action, int documentId, int? studentId) async {
    if (action == 'view_profile' && studentId != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            StudentDetailScreen(studentId: studentId, userRole: widget.userRole),
      ));
    } else if (action == 'delete') {
      _confirmDelete(documentId);
    } else if (action == 'queue') {
      try {
        await ref
            .read(printQueueMutationProvider.notifier)
            .addToQueue(documentId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Added to Print Queue.'),
          backgroundColor: AppColors.primaryGreen,
        ));
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.warning,
        ));
      }
    } else if (action == 'preview') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preview feature coming soon.'),
        backgroundColor: Colors.blue,
      ));
    } else if (action == 'download') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Download started.'),
        backgroundColor: Colors.blue,
      ));
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Delete Document', style: TextStyle(color: AppColors.error)),
        ]),
        content:
            const Text('Are you sure you want to permanently delete this document?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(documentMutationProvider.notifier)
                    .deleteDocument(id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Document deleted.'),
                  backgroundColor: AppColors.error,
                ));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed to delete: $e'),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docState = ref.watch(documentPageProvider);
    final query = ref.watch(documentQueryProvider);
    final requirementsAsync = ref.watch(documentRequirementsProvider);
    final academicYearsAsync = ref.watch(academicYearsProvider);
    final foldersAsync = ref.watch(foldersProvider);
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 700;
    final isStudentFiltered = query.studentId != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMobile
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryGreen,
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const UploadOcrModal()),
              child: const Icon(Icons.cloud_upload, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ──
            _buildTopHeader(isMobile, isStudentFiltered, query),

            // ── TabBar ──
            Container(
              color: AppColors.surfaceWhite,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryGreen,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primaryGreen,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.folder, size: 18), text: 'Student Folders'),
                  Tab(icon: Icon(Icons.description, size: 18), text: 'All Documents'),
                ],
              ),
            ),

            // ── Filter Panel (Documents tab only) ──
            if (_showFilters && _tabController.index == 1)
              _buildFilterPanel(requirementsAsync, academicYearsAsync, isMobile),

            const Divider(height: 1),

            // ── Tab Body ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Student Folders
                  _buildFoldersTab(foldersAsync, isMobile),

                  // Tab 1: All Documents
                  Column(
                    children: [
                      Expanded(
                        child: docState.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryGreen)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TOP HEADER
  // ══════════════════════════════════════════════════════════════
  Widget _buildTopHeader(
      bool isMobile, bool isStudentFiltered, DocumentQueryParams query) {
    return Container(
      color: AppColors.surfaceWhite,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Icon(Icons.folder_open,
                  color: AppColors.primaryGreen, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isStudentFiltered
                      ? 'Student Documents'
                      : 'Document Manager',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Clear student filter badge
              if (isStudentFiltered)
                TextButton.icon(
                  onPressed: () {
                    ref
                        .read(documentQueryProvider.notifier)
                        .setStudentId(null);
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('All Students',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen),
                ),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                _buildPrintQueueButton(),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: PrimaryButton(
                    label: 'UPLOAD',
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const UploadOcrModal()),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Search + Controls row
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  hintText: 'Search by name, LRN, file…',
                  prefixIcon: Icons.search,
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),

              // Filter toggle
              _buildIconToggle(
                icon: Icons.tune,
                isActive: _showFilters,
                tooltip: 'Toggle Filters',
                onTap: () => setState(() => _showFilters = !_showFilters),
              ),
              const SizedBox(width: 6),

              // Grid/List toggle
              _buildIconToggle(
                icon: _isGridView ? Icons.view_list : Icons.grid_view,
                isActive: false,
                tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                onTap: () => setState(() => _isGridView = !_isGridView),
              ),

              if (isMobile) ...[
                const SizedBox(width: 6),
                _buildPrintQueueButton(compact: true),
              ],
            ],
          ),

          // Active filter chips
          if (_hasActiveFilters())
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildActiveFilterChips(),
            ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() =>
      _selectedStatus != 'All Statuses' ||
      _selectedDocumentType != 'All Types' ||
      _selectedGradeLevel != 'All Grades' ||
      _selectedSchoolYear != 'All Years' ||
      _searchController.text.isNotEmpty;

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];
    if (_selectedStatus != 'All Statuses')
      chips.add(_filterChip('Status: $_selectedStatus'));
    if (_selectedDocumentType != 'All Types')
      chips.add(_filterChip('Type: $_selectedDocumentType'));
    if (_selectedGradeLevel != 'All Grades')
      chips.add(_filterChip('Grade: $_selectedGradeLevel'));
    if (_selectedSchoolYear != 'All Years')
      chips.add(_filterChip('Year: $_selectedSchoolYear'));
    chips.add(TextButton(
      onPressed: _clearFilters,
      style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(horizontal: 8)),
      child: const Text('Clear All', style: TextStyle(fontSize: 12)),
    ));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  Widget _filterChip(String label) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w500)),
      );

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
              color: isActive
                  ? AppColors.primaryGreen
                  : Colors.grey.shade300,
            ),
          ),
          child: Icon(icon,
              size: 20,
              color: isActive ? AppColors.primaryGreen : AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildPrintQueueButton({bool compact = false}) {
    return Tooltip(
      message: 'Print Queue',
      child: OutlinedButton.icon(
        onPressed: () => showDialog(
            context: context, builder: (_) => const PrintQueueModal()),
        icon: const Icon(Icons.print, size: 18),
        label: compact
            ? const SizedBox.shrink()
            : const Text('Print Queue'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.grey.shade300),
          padding: compact
              ? const EdgeInsets.all(10)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
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
    bool isMobile,
  ) {
    final docTypes = requirementsAsync.when(
      data: (reqs) =>
          ['All Types', ...reqs.map((r) => r.name as String).toSet().toList()..sort()],
      loading: () => ['All Types'],
      error: (_, __) => ['All Types'],
    );
    final years = academicYearsAsync.when(
      data: (y) => ['All Years', ...y.map((ay) => ay.yearRange as String)],
      loading: () => ['All Years'],
      error: (_, __) => ['All Years'],
    );

    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildDropdown(
                label: 'Status',
                value: _selectedStatus,
                items: const [
                  'All Statuses','Pending','Verified','Draft','Archived','Rejected'
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
                items: const [
                  'All Grades','7','8','9','10','11','12'
                ],
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
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear All',
                    style: TextStyle(color: AppColors.error))),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: PrimaryButton(label: 'Apply', onPressed: _applyFilters),
            ),
          ]),
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
    // Guard: if value is not in items, use first item
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          hint: Text(label, style: const TextStyle(fontSize: 13)),
          isExpanded: false,
          isDense: true,
          items: items
              .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // FOLDERS TAB
  // ══════════════════════════════════════════════════════════════
  Widget _buildFoldersTab(AsyncValue<List<dynamic>> foldersAsync, bool isMobile) {
    return foldersAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      error: (e, _) => _buildErrorState(e.toString()),
      data: (folders) {
        if (folders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_off_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No Student Folders',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                const Text('Student folders are created automatically.',
                    style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          );
        }

        return LayoutBuilder(builder: (ctx, c) {
          int cols = (c.maxWidth / 200).floor().clamp(2, 6);
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: folders.length,
            itemBuilder: (ctx, i) {
              final folder = folders[i];
              return InkWell(
                onTap: () {
                  if (folder.studentId != null) {
                    _tabController.index = 1;
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
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder,
                          size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          folder.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${folder.documentCount ?? 0} Documents',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      },
    );
  }


  // ══════════════════════════════════════════════════════════════
  // GRID VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildGridView(List documents) {
    return LayoutBuilder(builder: (ctx, c) {
      int cols = (c.maxWidth / 180).floor().clamp(2, 6);
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: documents.length,
        itemBuilder: (ctx, i) => FileFolderCard(
          document: documents[i],
          isGrid: true,
          userRole: widget.userRole,
          onTap: () {},
          onActionSelected: (a) =>
              _handleAction(a, documents[i].id, documents[i].studentId),
          onViewProfile: (sid) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                StudentDetailScreen(studentId: sid, userRole: widget.userRole),
          )),
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════════════════
  // LIST VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildListView(List documents) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryGreen.withValues(alpha: 0.06),
              child: const Row(
                children: [
                  SizedBox(width: 44),
                  Expanded(
                      flex: 3,
                      child: Text('File Name',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary))),
                  Expanded(
                      flex: 2,
                      child: Text('Student',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary))),
                  Expanded(
                      flex: 2,
                      child: Text('Doc Type',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary))),
                  Expanded(
                      child: Text('Status',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textSecondary))),
                  SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: documents.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (ctx, i) => FileFolderCard(
                  document: documents[i],
                  isGrid: false,
                  userRole: widget.userRole,
                  onTap: () {},
                  onActionSelected: (a) =>
                      _handleAction(a, documents[i].id, documents[i].studentId),
                  onViewProfile: (sid) =>
                      Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StudentDetailScreen(
                        studentId: sid, userRole: widget.userRole),
                  )),
                ),
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
          Icon(Icons.folder_off_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No documents found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Upload a document or adjust your filters',
              style: TextStyle(color: AppColors.textSecondary)),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 16),
            TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters')),
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
          Text(clean,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: () => ref.invalidate(documentPageProvider),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white),
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
          ...List.generate(totalPages, (i) => i + 1)
              .where((p) => (p - currentPage).abs() <= 2)
              .map((p) {
            final isActive = p == currentPage;
            return GestureDetector(
              onTap: () =>
                  ref.read(documentQueryProvider.notifier).setPage(p),
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
                  child: Text('$p',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : AppColors.textSecondary)),
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
}