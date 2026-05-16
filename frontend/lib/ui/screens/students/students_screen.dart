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

class StudentsScreen extends ConsumerStatefulWidget {
  final String userRole;
  const StudentsScreen({super.key, this.userRole = 'teacher'});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const _gradeLevels = ['All Grades', '7', '8', '9', '10', '11', '12'];
  static const _statusItems = ['All Status', 'Enrolled', 'Graduated', 'Transferred Out', 'Dropped'];
  static const _pageSizes   = [10, 20, 50];

  @override
  void initState() {
    super.initState();
    // Listen for text changes and debounce search
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
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

  // ----------------------------------------------------------------
  // DELETE CONFIRM
  // ----------------------------------------------------------------
  Future<void> _confirmDelete(StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text(
          'Are you sure you want to permanently delete '
          '"${student.fullName}"? This cannot be undone.',
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DocumentsScreen(
        userRole: widget.userRole,
        initialStudentId: studentId,
      ),
    ));
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final query    = ref.watch(studentQueryProvider);
    final pageAsync = ref.watch(studentPageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header + Controls ──
              _buildHeaderControls(context, query),
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
  Widget _buildHeaderControls(BuildContext context, StudentQueryParams query) {
    final gradeValue = query.gradeLevel.isEmpty ? 'All Grades' : query.gradeLevel;
    final statusValue = query.status.isEmpty ? 'All Status' : query.status;

    return LayoutBuilder(builder: (_, c) {
      final isDesktop = c.maxWidth > 800;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Students Directory',
                style: TextStyle(
                  fontSize:   28,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textPrimary,
                ),
              ),
              // Add Student Button
              if (widget.userRole != 'teacher')
                SizedBox(
                  width: isDesktop ? 180 : 50,
                  child: isDesktop
                      ? PrimaryButton(
                          label:     '+ ADD STUDENT',
                          onPressed: () => _openModal(),
                        )
                      : ElevatedButton(
                          onPressed: () => _openModal(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding:         const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusMedium),
                            ),
                          ),
                          child: const Icon(Icons.add),
                        ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.p16),

          // Search + Filters row
          Wrap(
            spacing:   AppSizes.p12,
            runSpacing: AppSizes.p12,
            children: [
              // Search field
              SizedBox(
                width: isDesktop ? 300 : double.infinity,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:     'Search by LRN or name…',
                    prefixIcon:   const Icon(Icons.search, color: AppColors.textSecondary),
                    filled:       true,
                    fillColor:    AppColors.surfaceWhite,
                    border:       OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      borderSide:   BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      borderSide:   BorderSide(color: Colors.grey.shade300),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon:      const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(studentQueryProvider.notifier).setSearch('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              // Grade Level filter
              _FilterDropdown(
                value:    gradeValue,
                items:    _gradeLevels,
                icon:     Icons.school_outlined,
                onChanged: (v) {
                  ref.read(studentQueryProvider.notifier)
                     .setGradeLevel(v == 'All Grades' ? '' : v);
                },
              ),

              // Status filter
              _FilterDropdown(
                value:    statusValue,
                items:    _statusItems,
                icon:     Icons.flag_outlined,
                onChanged: (v) {
                  ref.read(studentQueryProvider.notifier)
                     .setStatus(v == 'All Status' ? '' : v);
                },
              ),

              // Page size selector
              _FilterDropdown(
                value:    '${query.limit} / page',
                items:    _pageSizes.map((n) => '$n / page').toList(),
                icon:     Icons.format_list_numbered,
                onChanged: (v) {
                  final n = int.tryParse(v.split(' ').first) ?? 10;
                  ref.read(studentQueryProvider.notifier).setLimit(n);
                },
              ),
            ],
          ),
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
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.primaryGreen.withValues(alpha: 0.06),
              ),
              dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('LRN',           style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Name',          style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Grade & Sec.',  style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status',        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Missing Docs',  style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions',       style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: students.map((student) {
                return DataRow(cells: [
                  DataCell(Text(student.lrn, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(student.fullName)),
                  DataCell(Text(student.gradeSection)),
                  DataCell(_StatusChip(status: student.status)),
                  DataCell(_MissingDocsBadge(count: student.missingDocumentsCount)),
                  DataCell(_ActionButtons(
                    student:          student,
                    userRole:         widget.userRole,
                    onEdit:           () => _openModal(student: student),
                    onDelete:         () => _confirmDelete(student),
                    onViewProfile:    () => _viewProfile(student.id),
                    onOpenDocuments:  () => _openDocumentsFolder(student.id),
                  )),
                ]);
              }).toList(),
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

    return ListView.separated(
      itemCount:      students.length,
      separatorBuilder: (ctx, index) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (_, i) {
        final s = students[i];
        return Container(
          padding:    const EdgeInsets.all(AppSizes.p16),
          decoration: BoxDecoration(
            color:        AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.lrn,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color:      AppColors.primaryGreen,
                    ),
                  ),
                  _StatusChip(status: s.status),
                ],
              ),
              const SizedBox(height: AppSizes.p8),
              Text(s.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text(s.gradeSection, style: const TextStyle(color: AppColors.textSecondary)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.p12),
                child:   Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Text('Missing Docs: ', style: TextStyle(color: AppColors.textSecondary)),
                    _MissingDocsBadge(count: s.missingDocumentsCount),
                  ]),
                  _ActionButtons(
                    student:         s,
                    userRole:        widget.userRole,
                    onEdit:          () => _openModal(student: s),
                    onDelete:        () => _confirmDelete(s),
                    onViewProfile:   () => _viewProfile(s.id),
                    onOpenDocuments: () => _openDocumentsFolder(s.id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

    return Row(
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

class _FilterDropdown extends StatelessWidget {
  final String          value;
  final List<String>    items;
  final IconData        icon;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:        AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border:       Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:      value,
          icon:       const Icon(Icons.expand_more, size: 18),
          isDense:    true,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged:  (v) => onChanged(v!),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _bg {
    return switch (status) {
      'Enrolled'        => AppColors.primaryGreen.withValues(alpha: 0.10),
      'Graduated'       => Colors.blue.withValues(alpha: 0.10),
      'Transferred Out' => Colors.orange.withValues(alpha: 0.10),
      'Dropped'         => Colors.red.withValues(alpha: 0.10),
      _                 => Colors.grey.shade200,
    };
  }

  Color get _text {
    return switch (status) {
      'Enrolled'        => AppColors.primaryGreen,
      'Graduated'       => Colors.blue.shade700,
      'Transferred Out' => Colors.orange.shade800,
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

class _MissingDocsBadge extends StatelessWidget {
  final int count;
  const _MissingDocsBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 22);
    return Container(
      padding:    const EdgeInsets.all(6),
      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
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
            icon:      const Icon(Icons.person_outline, color: AppColors.primaryGreen),
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
              icon:      const Icon(Icons.edit_outlined, color: Colors.blueAccent),
              onPressed: onEdit,
            ),
          ),
          Tooltip(
            message:  'Delete Student',
            child:    IconButton(
              icon:      const Icon(Icons.delete_outline, color: AppColors.error),
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