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

  Future<void> _pickDateRange({StateSetter? setDialogState}) async {
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
      if (setDialogState != null) setDialogState(() {});
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
                          const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDateRange(setDialogState: setDialogState),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(_getDateRangeText()),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                foregroundColor: (_fromDate != null || _toDate != null) ? AppColors.primaryGreen : Colors.black87,
                                side: BorderSide(color: (_fromDate != null || _toDate != null) ? AppColors.primaryGreen : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Action', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['All Actions', 'CREATE', 'UPDATE', 'DELETE'].map((v) {
                              final isSelected = pendingAction == v;
                              return ChoiceChip(
                                label: Text(v),
                                selected: isSelected,
                                selectedColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                                onSelected: (_) => setDialogState(() => pendingAction = v),
                              );
                            }).toList(),
                          ),
                          if (!isTeacher) ...[
                            const SizedBox(height: 16),
                            const Text('Entity Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['All Entities', 'student', 'document'].map((v) {
                                final isSelected = pendingEntity == v;
                                return ChoiceChip(
                                  label: Text(v.toUpperCase()),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                                  onSelected: (_) => setDialogState(() => pendingEntity = v),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              final actionToSet = pendingAction == 'All Actions' ? '' : pendingAction;
                              final entityToSet = pendingEntity == 'All Entities' ? '' : pendingEntity;
                              ref.read(activityQueryProvider.notifier).setAction(actionToSet);
                              ref.read(activityQueryProvider.notifier).setEntityTypes(entityToSet);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen, 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Apply Filters'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                  label: const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.primaryGreen,
                  onPressed: () => _showFilterDialog(query, isTeacher),
                  side: BorderSide.none,
                ),
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
                          _buildPagination(data, query.page),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDateRangeText() {
    String text = 'Select Date Range';
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
    return text;
  }

  Widget _buildList(List<RecentActivity> activities) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          separatorBuilder: (_, _s) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final a = activities[i];
            
            final DateTime parsedDate = pht.parseToPht(a.createdAt);
            final dateStr = intl.DateFormat('MMM d, yyyy').format(parsedDate);
            final timeStr = intl.DateFormat('hh:mm a').format(parsedDate);

            return InkWell(
              onTap: () {
                ViewActivityModal.show(
                  context: context,
                  title: a.entityType.toUpperCase(),
                  description: a.description,
                  date: pht.formatModalDate(a.createdAt),
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
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _actionChip(a.action),
                          Text('$dateStr • $timeStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        a.description,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Entity Type', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    a.entityType.toUpperCase(),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Performed By', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                Text(
                                  a.performedBy ?? a.username ?? 'System',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        action.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
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
