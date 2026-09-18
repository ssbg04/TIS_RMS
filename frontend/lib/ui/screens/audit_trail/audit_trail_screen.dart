import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../providers/dashboard_provider.dart';
import '../../providers/activity_provider.dart';
import '../../shared/modals/view_activity_modal.dart';
import '../../shared/widgets/app_pagination.dart';

enum AuditTab { recentActivities, userHistory }

class AuditTrailScreen extends ConsumerStatefulWidget {
  final String userRole;
  final AuditTab initialTab;

  const AuditTrailScreen({
    super.key,
    required this.userRole,
    this.initialTab = AuditTab.recentActivities,
  });

  @override
  ConsumerState<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends ConsumerState<AuditTrailScreen> {
  late AuditTab _selectedTab;
  final TextEditingController _searchController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;

  // Action chips: All, Add, Update, Archive, Delete
  static const List<String> _actionFilters = [
    'All',
    'Add',
    'Update',
    'Archive',
    'Delete',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.userRole == 'teacher'
        ? AuditTab.recentActivities
        : widget.initialTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _searchController.clear();
    });
    if (_selectedTab == AuditTab.recentActivities) {
      ref.read(activityQueryProvider.notifier).reset();
    } else {
      ref.read(userHistoryQueryProvider.notifier).reset();
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final values = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.range,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        selectedDayHighlightColor: AppColors.primaryGreen,
      ),
      dialogSize: const Size(325, 400),
      value: [?_fromDate, ?_toDate],
      borderRadius: BorderRadius.circular(16),
    );

    if (values != null && values.isNotEmpty) {
      setState(() {
        _fromDate = values[0];
        _toDate = values.length > 1 ? values[1] : values[0];
      });

      final fromStr = _fromDate != null
          ? "${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}"
          : '';
      final toStr = _toDate != null
          ? "${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}"
          : '';

      if (_selectedTab == AuditTab.recentActivities) {
        ref.read(activityQueryProvider.notifier).setDateFrom(fromStr);
        ref.read(activityQueryProvider.notifier).setDateTo(toStr);
      } else {
        ref.read(userHistoryQueryProvider.notifier).setDateFrom(fromStr);
        ref.read(userHistoryQueryProvider.notifier).setDateTo(toStr);
      }
    }
  }

  Color _getActionColor(String action) {
    final act = action.toUpperCase();
    if (act.contains('CREATE') || act.contains('ADD')) {
      return const Color(0xFF10B981); // Emerald Green
    }
    if (act.contains('UPDATE')) {
      return const Color(0xFF3B82F6); // Blue
    }
    if (act.contains('ARCHIVE') || act.contains('INACTIVE')) {
      return const Color(0xFFF59E0B); // Amber / Orange
    }
    if (act.contains('DELETE') || act.contains('DROP')) {
      return const Color(0xFFEF4444); // Red
    }
    return AppColors.primaryGreen;
  }

  IconData _getActionIcon(String action) {
    final act = action.toUpperCase();
    if (act.contains('CREATE') || act.contains('ADD')) {
      return Icons.add_circle_outline_rounded;
    }
    if (act.contains('UPDATE')) {
      return Icons.edit_note_rounded;
    }
    if (act.contains('ARCHIVE') || act.contains('INACTIVE')) {
      return Icons.archive_outlined;
    }
    if (act.contains('DELETE')) {
      return Icons.delete_outline_rounded;
    }
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isAdmin = widget.userRole == 'admin';

    final actQuery = ref.watch(activityQueryProvider);
    final usrQuery = ref.watch(userHistoryQueryProvider);

    final currentActionFilter = _selectedTab == AuditTab.recentActivities
        ? (actQuery.action.isEmpty ? 'All' : actQuery.action)
        : (usrQuery.action.isEmpty ? 'All' : usrQuery.action);

    final hasActiveFilters = (_selectedTab == AuditTab.recentActivities
            ? (actQuery.action.isNotEmpty ||
                actQuery.entityTypes.isNotEmpty ||
                actQuery.search.isNotEmpty ||
                actQuery.dateFrom.isNotEmpty)
            : (usrQuery.action.isNotEmpty ||
                usrQuery.role.isNotEmpty ||
                usrQuery.search.isNotEmpty ||
                usrQuery.dateFrom.isNotEmpty)) ||
        _fromDate != null ||
        _toDate != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top App Header & Controls ─────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 20,
                isMobile ? 16 : 24,
                12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: Title and Refresh / Date Range Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.manage_history_rounded,
                                  color: AppColors.primaryGreen,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Audit Trail & History',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          if (!isMobile) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Track detailed operation history, student/document activities, and user events.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          // Date Range Filter Button
                          OutlinedButton.icon(
                            onPressed: () => _pickDateRange(context),
                            icon: Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: (_fromDate != null || _toDate != null)
                                  ? AppColors.primaryGreen
                                  : null,
                            ),
                            label: Text(
                              _fromDate != null && _toDate != null
                                  ? '${_fromDate!.month}/${_fromDate!.day} - ${_toDate!.month}/${_toDate!.day}'
                                  : (_fromDate != null
                                      ? 'From ${_fromDate!.month}/${_fromDate!.day}'
                                      : 'Date Range'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: (_fromDate != null || _toDate != null)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: (_fromDate != null || _toDate != null)
                                    ? AppColors.primaryGreen
                                    : null,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: (_fromDate != null || _toDate != null)
                                    ? AppColors.primaryGreen
                                    : Theme.of(context).dividerColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Refresh Button
                          IconButton(
                            tooltip: 'Refresh',
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () {
                              if (_selectedTab == AuditTab.recentActivities) {
                                ref.invalidate(recentActivitiesPageProvider);
                              } else {
                                ref.invalidate(userHistoryPageProvider);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tab switcher (Recent Activities vs User History)
                  if (isAdmin)
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabItem(
                            label: 'Recent Activities',
                            icon: Icons.list_alt_rounded,
                            tab: AuditTab.recentActivities,
                          ),
                          _buildTabItem(
                            label: 'User History',
                            icon: Icons.account_circle_outlined,
                            tab: AuditTab.userHistory,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Row: Search field and Action Filter Chips
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      // Search box
                      SizedBox(
                        width: isMobile ? double.infinity : 280,
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: _selectedTab == AuditTab.recentActivities
                                ? 'Search description or user...'
                                : 'Search user or admin...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      if (_selectedTab == AuditTab.recentActivities) {
                                        ref
                                            .read(activityQueryProvider.notifier)
                                            .setSearch('');
                                      } else {
                                        ref
                                            .read(userHistoryQueryProvider.notifier)
                                            .setSearch('');
                                      }
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkSurfaceCard
                                : Colors.grey.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (value) {
                            if (_selectedTab == AuditTab.recentActivities) {
                              ref
                                  .read(activityQueryProvider.notifier)
                                  .setSearch(value);
                            } else {
                              ref
                                  .read(userHistoryQueryProvider.notifier)
                                  .setSearch(value);
                            }
                          },
                        ),
                      ),

                      // Action filter chips: All, Add, Update, Archive, Delete
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _actionFilters.map((actionName) {
                          final isSelected = currentActionFilter.toLowerCase() ==
                                  actionName.toLowerCase() ||
                              (actionName == 'All' &&
                                  (currentActionFilter == 'All' ||
                                      currentActionFilter.isEmpty));

                          Color chipColor = AppColors.primaryGreen;
                          if (actionName == 'Add') {
                            chipColor = const Color(0xFF10B981);
                          } else if (actionName == 'Update') {
                            chipColor = const Color(0xFF3B82F6);
                          } else if (actionName == 'Archive') {
                            chipColor = const Color(0xFFF59E0B);
                          } else if (actionName == 'Delete') {
                            chipColor = const Color(0xFFEF4444);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(actionName),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: chipColor.withValues(alpha: 0.18),
                              backgroundColor: isDark
                                  ? AppColors.darkSurfaceCard
                                  : Colors.grey.withValues(alpha: 0.08),
                              side: BorderSide(
                                color: isSelected
                                    ? chipColor
                                    : Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.2),
                                width: isSelected ? 1.5 : 1,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? chipColor
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              onSelected: (_) {
                                final target = actionName == 'All' ? '' : actionName;
                                if (_selectedTab == AuditTab.recentActivities) {
                                  ref
                                      .read(activityQueryProvider.notifier)
                                      .setAction(target);
                                } else {
                                  ref
                                      .read(userHistoryQueryProvider.notifier)
                                      .setAction(target);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),

                      // Clear filters button
                      if (hasActiveFilters)
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text('Reset', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Main Content Area ─────────────────────────────────────
            Expanded(
              child: _selectedTab == AuditTab.recentActivities
                  ? _buildRecentActivitiesTab(isDark, isMobile)
                  : _buildUserHistoryTab(isDark, isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required AuditTab tab,
  }) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        if (_selectedTab != tab) {
          setState(() {
            _selectedTab = tab;
            _searchController.clear();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TAB 1: RECENT ACTIVITIES
  // ══════════════════════════════════════════════════════════════════
  Widget _buildRecentActivitiesTab(bool isDark, bool isMobile) {
    final activitiesAsync = ref.watch(recentActivitiesPageProvider);

    return activitiesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load activities',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(recentActivitiesPageProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        if (data.activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching activity logs found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try adjusting your search, action, or date filters.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                itemCount: data.activities.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = data.activities[index];
                  final actionColor = _getActionColor(item.action);
                  final actionIcon = _getActionIcon(item.action);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ViewActivityModal.show(
                          context: context,
                          title: '${item.entityType.toUpperCase()} - ${item.action}',
                          description: item.description,
                          date: pht.formatDateTime(item.createdAt),
                          performedBy: item.performedBy ?? item.username ?? 'System',
                          action: item.action,
                          actionColor: actionColor,
                          icon: actionIcon,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Action icon avatar
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(actionIcon, color: actionColor, size: 20),
                            ),
                            const SizedBox(width: 14),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Action Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.action.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: actionColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Entity Type Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.grey.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.entityType.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Timestamp
                                      Text(
                                        pht.formatDateTime(item.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Description
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Performed By
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'By: ${item.performedBy ?? item.username ?? 'System'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
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
                },
              ),
            ),
            // Pagination Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${data.total} activities',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  AppPagination(
                    currentPage: data.page,
                    totalPages: data.totalPages,
                    onPageChanged: (newPage) {
                      ref.read(activityQueryProvider.notifier).setPage(newPage);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TAB 2: USER HISTORY
  // ══════════════════════════════════════════════════════════════════
  Widget _buildUserHistoryTab(bool isDark, bool isMobile) {
    final historyAsync = ref.watch(userHistoryPageProvider);

    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load user history',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(userHistoryPageProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        if (data.history.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching user history records',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try adjusting your search, action, or date filters.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                itemCount: data.history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = data.history[index];
                  final actionColor = _getActionColor(item.action);
                  final actionIcon = _getActionIcon(item.action);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ViewActivityModal.show(
                          context: context,
                          title: 'User ${item.action.toUpperCase()}',
                          description:
                              'User @${item.username} (${item.fullName.isNotEmpty ? item.fullName : 'No Name'}) with role "${item.role}" was ${item.action}.',
                          date: pht.formatDateTime(item.createdAt),
                          performedBy: item.performedByName ??
                              item.performedByUsername ??
                              'System',
                          action: item.action,
                          actionColor: actionColor,
                          icon: actionIcon,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Action Avatar
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(actionIcon, color: actionColor, size: 20),
                            ),
                            const SizedBox(width: 14),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Action Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.action.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: actionColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Role Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.grey.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Timestamp
                                      Text(
                                        pht.formatDateTime(item.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // User info
                                  Text(
                                    item.fullName.isNotEmpty
                                        ? '${item.fullName} (@${item.username})'
                                        : '@${item.username}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Performed By
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Performed by: ${item.performedByName ?? item.performedByUsername ?? 'System'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
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
                },
              ),
            ),
            // Pagination Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${data.total} entries',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  AppPagination(
                    currentPage: data.page,
                    totalPages: data.totalPages,
                    onPageChanged: (newPage) {
                      ref.read(userHistoryQueryProvider.notifier).setPage(newPage);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
