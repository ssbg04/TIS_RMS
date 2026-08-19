import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../../domain/entities/dashboard_models.dart';
import '../../providers/activity_provider.dart';
import '../../shared/modals/view_activity_modal.dart';
import '../../shared/widgets/app_pagination.dart';

/// Admin-only screen — accessible from Dashboard only (not main nav).
class UserHistoryScreen extends ConsumerStatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  ConsumerState<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends ConsumerState<UserHistoryScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    ref.read(userHistoryQueryProvider.notifier).reset();
  }

  void _showFilterDialog(UserHistoryQueryParams query) {
    String pendingAction = query.action.isEmpty ? 'All Actions' : query.action;
    String pendingRole = query.role.isEmpty ? 'All Roles' : query.role;
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
                                  'Filter User History',
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
                                  'Narrow down user account logs',
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
                                'created',
                                'updated',
                                'deleted',
                                'activated',
                                'deactivated',
                                'reset_password',
                              ],
                              labelBuilder: (s) {
                                if (s == 'All Actions') return 'All Actions';
                                if (s == 'reset_password') return 'RESET PASSWORD';
                                return s.toUpperCase();
                              },
                              selectedValue: pendingAction,
                              onSelected: (v) =>
                                  setDialogState(() => pendingAction = v),
                            ),

                            _buildDivider(isDark),

                            // 3. Role Filter
                            _buildSectionHeader(
                              context,
                              label: 'Role',
                              hasActiveFilter: pendingRole != 'All Roles',
                              onReset: () => setDialogState(
                                () => pendingRole = 'All Roles',
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildChipGroup(
                              context,
                              items: const [
                                'All Roles',
                                'admin',
                                'teacher',
                              ],
                              labelBuilder: (s) => s == 'All Roles'
                                  ? 'All Roles'
                                  : s.toUpperCase(),
                              selectedValue: pendingRole,
                              onSelected: (v) =>
                                  setDialogState(() => pendingRole = v),
                            ),

                            _buildDivider(isDark),

                            // 4. Page Size
                            _buildSectionHeader(
                              context,
                              label: 'Records per Page',
                              hasActiveFilter: pendingLimit != 20,
                              onReset: () =>
                                  setDialogState(() => pendingLimit = 20),
                            ),
                            const SizedBox(height: 8),
                            _buildChipGroup(
                              context,
                              items: const ['10', '15', '20', '50'],
                              labelBuilder: (s) => '$s per page',
                              selectedValue: pendingLimit.toString(),
                              onSelected: (v) => setDialogState(
                                () => pendingLimit = int.tryParse(v) ?? 20,
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
                                  pendingRole = 'All Roles';
                                  pendingLimit = 20;
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
                                  userHistoryQueryProvider.notifier,
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
                                notifier.setRole(
                                  pendingRole == 'All Roles'
                                      ? ''
                                      : pendingRole,
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
    final historyAsync = ref.watch(userHistoryPageProvider);
    final query = ref.watch(userHistoryQueryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasActiveFilter =
        _fromDate != null ||
        _toDate != null ||
        query.action.isNotEmpty ||
        query.role.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Account History',
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
                  onPressed: () => _showFilterDialog(query),
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
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Failed to load user history: $e',
                    style: TextStyle(
                      color: isDark ? Colors.red.shade300 : Colors.red,
                    ),
                  ),
                ),
              ),
              data: (data) => data.history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.manage_accounts_rounded,
                            size: 48,
                            color: isDark
                                ? AppColors.darkTextSecondary.withValues(
                                    alpha: 0.5,
                                  )
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No user account history found.',
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
                        Expanded(child: _buildList(data.history)),
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

  Widget _buildList(List<UserHistoryEntry> history) {
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
                itemCount: history.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final h = history[index];
                  final desc = _getDisplayDescription(h);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () => ViewActivityModal.show(
                        context: context,
                        title: 'USER ACTIVITY',
                        description: desc,
                        date: pht.formatModalDate(h.createdAt),
                        performedBy:
                            h.performedByName ?? h.performedByUsername ?? 'System',
                        action: h.action,
                        actionColor: _actionColor(h.action),
                        icon: _actionIcon(h.action),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _actionColor(
                            h.action,
                          ).withValues(alpha: 0.12),
                          child: Text(
                            _getInitials(h.fullName),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _actionColor(h.action),
                            ),
                          ),
                        ),
                        title: Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              _buildActionChip(h.action),
                              const SizedBox(width: 8),
                              _buildRoleChip(h.role),
                            ],
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              desc,
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
                                  pht.formatRelative(h.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  'by ${h.performedByName ?? h.performedByUsername ?? 'System'}',
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

  String _getDisplayDescription(UserHistoryEntry h) {
    final actionLower = h.action.toLowerCase();
    if (actionLower == 'created') {
      return 'Added user: ${h.username} as ${h.role}';
    } else if (actionLower == 'updated') {
      return 'Updated user: ${h.username}';
    } else if (actionLower == 'deleted') {
      return 'Deleted user: ${h.username}';
    } else if (actionLower == 'activated') {
      return 'Activated user: ${h.username}';
    } else if (actionLower == 'deactivated') {
      return 'Deactivated user: ${h.username}';
    } else if (actionLower == 'reset_password') {
      return 'Reset password for user: ${h.username}';
    }
    return '${h.action.toUpperCase()} user: ${h.username}';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildPagination(PaginatedUserHistory data, int current) {
    return AppPagination(
      currentPage: current,
      totalPages: data.totalPages,
      onPageChanged: (p) =>
          ref.read(userHistoryQueryProvider.notifier).setPage(p),
    );
  }

  Widget _buildActionChip(String action) {
    final color = _actionColor(action);
    String label = action.toUpperCase();
    if (action.toLowerCase() == 'reset_password') label = 'RESET PASSWORD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = role.toLowerCase() == 'admin';
    final color = isAdmin
        ? (isDark ? Colors.purple.shade300 : Colors.purple)
        : (isDark ? Colors.teal.shade300 : Colors.teal);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
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
    switch (action.toLowerCase()) {
      case 'created':
      case 'activated':
        return isDark ? Colors.green.shade300 : AppColors.primaryGreen;
      case 'deleted':
      case 'deactivated':
        return isDark ? Colors.red.shade300 : Colors.red;
      case 'reset_password':
        return isDark ? Colors.blue.shade300 : Colors.blue;
      case 'updated':
      default:
        return isDark ? Colors.orange.shade300 : Colors.orange;
    }
  }

  IconData _actionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return Icons.person_add_rounded;
      case 'deleted':
        return Icons.person_off_rounded;
      case 'activated':
        return Icons.check_circle_outline_rounded;
      case 'deactivated':
        return Icons.block_rounded;
      case 'reset_password':
        return Icons.lock_reset_rounded;
      case 'updated':
      default:
        return Icons.manage_accounts_rounded;
    }
  }
}
