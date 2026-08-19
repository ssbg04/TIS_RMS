import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../shared/widgets/app_pagination.dart';
import '../../../domain/entities/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/modals/view_activity_modal.dart';

class RecentActivitiesScreen extends ConsumerStatefulWidget {
  const RecentActivitiesScreen({super.key});

  @override
  ConsumerState<RecentActivitiesScreen> createState() =>
      _RecentActivitiesScreenState();
}

class _RecentActivitiesScreenState
    extends ConsumerState<RecentActivitiesScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    ref.read(activityQueryProvider.notifier).reset();
  }

  void _showFilterDialog(ActivityQueryParams query, bool isTeacher) {
    String pendingAction = query.action.isEmpty ? 'All Actions' : query.action;
    String pendingEntity =
        query.entityTypes.isEmpty ? 'All Entities' : query.entityTypes;
    DateTime? tempFrom = _fromDate;
    DateTime? tempTo = _toDate;
    int pendingLimit = query.limit;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickDateRange() async {
            final values = await showCalendarDatePicker2Dialog(
              context: ctx,
              config: CalendarDatePicker2WithActionButtonsConfig(
                calendarType: CalendarDatePicker2Type.range,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                selectedDayHighlightColor: AppColors.primaryGreen,
              ),
              dialogSize: const Size(325, 400),
              value: [
                ?tempFrom,
                ?tempTo,
              ],
              borderRadius: BorderRadius.circular(15),
            );
            if (values != null && values.isNotEmpty) {
              setDialogState(() {
                tempFrom = values[0];
                tempTo = values.length > 1 ? values[1] : values[0];
              });
            }
          }

          String dateRangeLabel = 'All Dates (No filter)';
          if (tempFrom != null && tempTo != null) {
            if (tempFrom!.year == tempTo!.year &&
                tempFrom!.month == tempTo!.month &&
                tempFrom!.day == tempTo!.day) {
              dateRangeLabel =
                  '${tempFrom!.day}/${tempFrom!.month}/${tempFrom!.year}';
            } else {
              dateRangeLabel =
                  '${tempFrom!.day}/${tempFrom!.month}/${tempFrom!.year} – ${tempTo!.day}/${tempTo!.month}/${tempTo!.year}';
            }
          } else if (tempFrom != null) {
            dateRangeLabel =
                'From ${tempFrom!.day}/${tempFrom!.month}/${tempFrom!.year}';
          } else if (tempTo != null) {
            dateRangeLabel =
                'To ${tempTo!.day}/${tempTo!.month}/${tempTo!.year}';
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: MediaQuery.of(context).size.height < 600 ? 16 : 40,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 460,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter Recent Activities',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Narrow down activity logs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.of(ctx).pop(),
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : Colors.grey.shade200,
                    ),

                    // ── Scrollable Body ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Date Range Section
                            _buildSectionHeader(
                              context,
                              label: 'Date Range',
                              hasActiveFilter:
                                  tempFrom != null || tempTo != null,
                              onReset: () => setDialogState(() {
                                tempFrom = null;
                                tempTo = null;
                              }),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: pickDateRange,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurface2
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (tempFrom != null || tempTo != null)
                                        ? AppColors.primaryGreen
                                        : (isDark
                                            ? AppColors.darkBorder
                                            : Colors.grey.shade300),
                                    width: (tempFrom != null || tempTo != null)
                                        ? 1.5
                                        : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                      color: (tempFrom != null || tempTo != null)
                                          ? AppColors.primaryGreen
                                          : (isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        dateRangeLabel,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: (tempFrom != null || tempTo != null)
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: (tempFrom != null || tempTo != null)
                                              ? (isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.textPrimary)
                                              : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                    if (tempFrom != null || tempTo != null)
                                      GestureDetector(
                                        onTap: () => setDialogState(() {
                                          tempFrom = null;
                                          tempTo = null;
                                        }),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            _buildDivider(isDark),

                            // 2. Action Filter
                            _buildSectionHeader(
                              context,
                              label: 'Action',
                              hasActiveFilter: pendingAction != 'All Actions',
                              onReset: () => setDialogState(
                                () => pendingAction = 'All Actions',
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildChipGroup(
                              context,
                              items: const [
                                'All Actions',
                                'CREATE',
                                'UPDATE',
                                'DELETE',
                              ],
                              selectedValue: pendingAction,
                              onSelected: (v) =>
                                  setDialogState(() => pendingAction = v),
                            ),

                            if (!isTeacher) ...[
                              _buildDivider(isDark),

                              // 3. Entity Type Filter
                              _buildSectionHeader(
                                context,
                                label: 'Entity Type',
                                hasActiveFilter:
                                    pendingEntity != 'All Entities',
                                onReset: () => setDialogState(
                                  () => pendingEntity = 'All Entities',
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildChipGroup(
                                context,
                                items: const [
                                  'All Entities',
                                  'student',
                                  'enrollment',
                                  'document',
                                  'user',
                                ],
                                labelBuilder: (s) => s == 'All Entities'
                                    ? 'All Entities'
                                    : s.toUpperCase(),
                                selectedValue: pendingEntity,
                                onSelected: (v) =>
                                    setDialogState(() => pendingEntity = v),
                              ),
                            ],

                            _buildDivider(isDark),

                            // 4. Page Size
                            _buildSectionHeader(
                              context,
                              label: 'Activities per Page',
                              hasActiveFilter: pendingLimit != 15,
                              onReset: () =>
                                  setDialogState(() => pendingLimit = 15),
                            ),
                            const SizedBox(height: 8),
                            _buildChipGroup(
                              context,
                              items: const ['10', '15', '20', '50'],
                              labelBuilder: (s) => '$s per page',
                              selectedValue: pendingLimit.toString(),
                              onSelected: (v) => setDialogState(
                                () => pendingLimit = int.tryParse(v) ?? 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? AppColors.darkBorder
                          : Colors.grey.shade200,
                    ),

                    // ── Footer Buttons ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  tempFrom = null;
                                  tempTo = null;
                                  pendingAction = 'All Actions';
                                  pendingEntity = 'All Entities';
                                  pendingLimit = 15;
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
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _fromDate = tempFrom;
                                  _toDate = tempTo;
                                });
                                final notifier = ref.read(
                                  activityQueryProvider.notifier,
                                );
                                if (tempFrom != null) {
                                  notifier.setDateFrom(
                                    '${tempFrom!.year}-${tempFrom!.month.toString().padLeft(2, '0')}-${tempFrom!.day.toString().padLeft(2, '0')}',
                                  );
                                } else {
                                  notifier.setDateFrom('');
                                }
                                if (tempTo != null) {
                                  notifier.setDateTo(
                                    '${tempTo!.year}-${tempTo!.month.toString().padLeft(2, '0')}-${tempTo!.day.toString().padLeft(2, '0')}',
                                  );
                                } else {
                                  notifier.setDateTo('');
                                }
                                notifier.setAction(
                                  pendingAction == 'All Actions'
                                      ? ''
                                      : pendingAction,
                                );
                                notifier.setEntityTypes(
                                  pendingEntity == 'All Entities'
                                      ? ''
                                      : pendingEntity,
                                );
                                notifier.setLimit(pendingLimit);
                                Navigator.of(ctx).pop();
                              },
                              child: const Text(
                                'Apply Filters',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required String label,
    required bool hasActiveFilter,
    required VoidCallback onReset,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        if (hasActiveFilter)
          InkWell(
            onTap: onReset,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Clear',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildChipGroup(
    BuildContext context, {
    required List<String> items,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    String Function(String)? labelBuilder,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = item == selectedValue;
        final display = labelBuilder != null ? labelBuilder(item) : item;
        return ChoiceChip(
          label: Text(
            display,
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

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(recentActivitiesPageProvider);
    final query = ref.watch(activityQueryProvider);
    final isTeacher = ref.watch(authProvider).value?.role == 'teacher';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasActiveFilter =
        _fromDate != null ||
        _toDate != null ||
        query.action.isNotEmpty ||
        query.entityTypes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recent Activities',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Filter Top Bar ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showFilterDialog(query, isTeacher),
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 16,
                  ),
                  label: Text(
                    hasActiveFilter ? 'Filtered' : 'Filter',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: hasActiveFilter
                        ? AppColors.primaryGreen.withValues(alpha: 0.1)
                        : (isDark ? AppColors.darkSurface2 : Colors.grey.shade50),
                    foregroundColor: hasActiveFilter
                        ? AppColors.primaryGreen
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                    side: BorderSide(
                      color: hasActiveFilter
                          ? AppColors.primaryGreen
                          : (isDark
                              ? AppColors.darkBorder
                              : Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (hasActiveFilter) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text(
                      'Clear Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Failed to load activities: $e',
                    style: TextStyle(
                      color: isDark ? Colors.red.shade300 : Colors.red,
                    ),
                  ),
                ),
              ),
              data: (data) => data.activities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 48,
                            color: isDark
                                ? AppColors.darkTextSecondary.withValues(
                                    alpha: 0.5,
                                  )
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No recent activities found.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildList(data.activities)),
                        if (data.totalPages > 1)
                          _buildPagination(data, query.page),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<RecentActivity> activities) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: 1,
          itemBuilder: (context, _) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final a = activities[index];

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () => ViewActivityModal.show(
                        context: context,
                        title: a.entityType.toUpperCase(),
                        description: a.description,
                        date: pht.formatModalDate(a.createdAt),
                        performedBy: a.performedBy ?? a.username ?? 'System',
                        action: a.action,
                        actionColor: _actionColor(a.action),
                        icon: _actionIcon(a.action, a.entityType),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: Icon(
                          _actionIcon(a.action, a.entityType),
                          color: _actionColor(a.action),
                          size: 26,
                        ),
                        title: Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildActionChip(a.action),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.description,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  pht.formatRelative(a.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  'by ${a.performedBy ?? a.username ?? 'System'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: isDark
                              ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPagination(PaginatedActivities data, int current) {
    return AppPagination(
      currentPage: current,
      totalPages: data.totalPages,
      onPageChanged: (p) =>
          ref.read(activityQueryProvider.notifier).setPage(p),
    );
  }

  Widget _buildActionChip(String action) {
    final color = _actionColor(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        action.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (action.toUpperCase()) {
      case 'CREATE':
        return isDark ? Colors.green.shade300 : AppColors.primaryGreen;
      case 'DELETE':
        return isDark ? Colors.red.shade300 : Colors.red;
      case 'UPDATE':
        return isDark ? Colors.orange.shade300 : Colors.orange;
      default:
        return isDark ? Colors.blue.shade300 : Colors.blue;
    }
  }

  IconData _actionIcon(String action, String entityType) {
    switch (entityType.toLowerCase()) {
      case 'student':
        return Icons.person_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'user':
        return Icons.manage_accounts_rounded;
      case 'enrollment':
        return Icons.school_rounded;
      default:
        return Icons.history_rounded;
    }
  }
}
