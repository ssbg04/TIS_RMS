import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../shared/widgets/app_pagination.dart';
import 'package:intl/intl.dart' as intl;

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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final values = await showCalendarDatePicker2Dialog(
      context: context,
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.range,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        selectedDayHighlightColor: AppColors.primaryGreen,
      ),
      dialogSize: const Size(325, 400),
      value: [
        if (_fromDate != null) _fromDate!,
        if (_toDate != null) _toDate!,
      ],
      borderRadius: BorderRadius.circular(15),
    );
    if (values != null && values.isNotEmpty) {
      setState(() {
        _fromDate = values[0];
        _toDate = values.length > 1 ? values[1] : values[0];
      });
      final notifier = ref.read(activityQueryProvider.notifier);
      if (_fromDate != null) {
        final f = _fromDate!;
        notifier.setDateFrom('${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}');
      }
      if (_toDate != null) {
        final t = _toDate!;
        notifier.setDateTo('${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}');
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    ref.read(activityQueryProvider.notifier).reset();
  }

  void _showFilterDialog(ActivityQueryParams query, bool isTeacher) {
    String pendingAction = query.action.isEmpty ? 'All Actions' : query.action;
    String pendingEntity = query.entityTypes.isEmpty ? 'All Entities' : query.entityTypes;

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
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          const Text('Filter Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Action', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: pendingAction,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: ['All Actions', 'CREATE', 'UPDATE', 'DELETE']
                                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => pendingAction = v!),
                          ),
                          if (!isTeacher) ...[
                            const SizedBox(height: 16),
                            const Text('Entity Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: pendingEntity,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: ['All Entities', 'student', 'document']
                                  .map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase())))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => pendingEntity = v!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final actionToSet = pendingAction == 'All Actions' ? '' : pendingAction;
                              final entityToSet = pendingEntity == 'All Entities' ? '' : pendingEntity;
                              ref.read(activityQueryProvider.notifier).setAction(actionToSet);
                              ref.read(activityQueryProvider.notifier).setEntityTypes(entityToSet);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                            child: const Text('Apply Filters'),
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

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(recentActivitiesPageProvider);
    final query = ref.watch(activityQueryProvider);
    final isTeacher = ref.watch(authProvider).value?.role == 'teacher';

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
          // ── Filter Bar ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                  label: const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.primaryGreen,
                  onPressed: () => _showFilterDialog(query, isTeacher),
                  side: BorderSide.none,
                ),
                _dateRangeChip(),
                if (_fromDate != null || _toDate != null || query.action.isNotEmpty || query.entityTypes.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                    backgroundColor: Colors.red.shade50,
                    labelStyle: TextStyle(color: Colors.red.shade700),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (data) => data.activities.isEmpty
                  ? const Center(
                      child: Text(
                        'No activities found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildList(data.activities)),
                        if (data.totalPages > 1)
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildPagination(data, query.page),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRangeChip() {
    final hasDates = _fromDate != null || _toDate != null;
    String text = 'Date Range';
    if (_fromDate != null && _toDate != null) {
      if (_fromDate!.year == _toDate!.year && _fromDate!.month == _toDate!.month && _fromDate!.day == _toDate!.day) {
        text = '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}';
      } else {
        text = '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year} - ${_toDate!.day}/${_toDate!.month}/${_toDate!.year}';
      }
    } else if (_fromDate != null) {
      text = 'From ${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}';
    } else if (_toDate != null) {
      text = 'To ${_toDate!.day}/${_toDate!.month}/${_toDate!.year}';
    }

    return ActionChip(
      avatar: const Icon(Icons.calendar_today, size: 16),
      label: Text(text),
      onPressed: _pickDateRange,
      backgroundColor: hasDates
          ? AppColors.primaryGreen.withValues(alpha: 0.1)
          : null,
      labelStyle: TextStyle(
        color: hasDates ? AppColors.primaryGreen : Colors.black87,
      ),
    );
  }

  Widget _buildList(List<RecentActivity> activities) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) return _buildTable(activities);
        return _buildCards(activities);
      },
    );
  }

  Widget _buildTable(List<RecentActivity> activities) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
            // Sticky Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade50,
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Entity Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 4, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('Performed By', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable Rows
            Expanded(
              child: ListView.separated(
                itemCount: activities.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final a = activities[index];
                  
                  // Format Date and Time
                  final DateTime parsedDate = DateTime.tryParse(a.createdAt) ?? DateTime.now();
                  // [Month Day, Year] -> MMM dd, yyyy
                  final dateStr = intl.DateFormat('MMM dd, yyyy').format(parsedDate);
                  // [12-hour format] -> hh:mm a
                  final timeStr = intl.DateFormat('hh:mm a').format(parsedDate);

                  return InkWell(
                    onTap: () {
                      ViewActivityModal.show(
                        context: context,
                        title: a.entityType.toUpperCase(),
                        description: a.description,
                        date: '$dateStr $timeStr',
                        performedBy: a.performedBy ?? a.username ?? 'System',
                        action: a.action,
                        actionColor: _actionColor(a.action),
                        icon: _actionIcon(a.action, a.entityType),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _actionChip(a.action))),
                          Expanded(flex: 2, child: Text(a.entityType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          Expanded(flex: 4, child: Text(a.description, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Expanded(flex: 3, child: Text(a.performedBy ?? a.username ?? '—', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(dateStr, style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(timeStr, style: const TextStyle(fontSize: 13, color: Colors.grey))),
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

  Widget _buildCards(List<RecentActivity> activities) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: activities.length,
      separatorBuilder: (_, _s) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = activities[i];
        return InkWell(
          onTap: () {
            ViewActivityModal.show(
              context: context,
              title: a.entityType.toUpperCase(),
              description: a.description,
              date: _formatDate(a.createdAt),
              performedBy: a.performedBy ?? a.username ?? 'System',
              action: a.action,
              actionColor: _actionColor(a.action),
              icon: _actionIcon(a.action, a.entityType),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _actionChip(a.action),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        a.entityType,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  a.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      a.performedBy ?? a.username ?? 'System',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(a.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildPagination(PaginatedActivities data, int current) {
    return AppPagination(
      currentPage: current,
      totalPages: data.totalPages,
      onPageChanged: (p) => ref.read(activityQueryProvider.notifier).setPage(p),
    );
  }

  Widget _actionChip(String action) {
    final color = _actionColor(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        action.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return AppColors.primaryGreen;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _actionIcon(String action, String entityType) {
    if (entityType == 'user') {
      switch (action.toUpperCase()) {
        case 'CREATE': return Icons.person_add;
        case 'DELETE': return Icons.person_off;
        default:       return Icons.manage_accounts;
      }
    }
    if (entityType == 'student') {
      switch (action.toUpperCase()) {
        case 'CREATE': return Icons.school;
        case 'DELETE': return Icons.delete_forever;
        default:       return Icons.edit;
      }
    }
    switch (action.toUpperCase()) {
      case 'CREATE': return Icons.upload_file;
      case 'DELETE': return Icons.delete;
      default:       return Icons.description;
    }
  }

  String _formatDate(String raw) => pht.formatDateTime(raw);
}
