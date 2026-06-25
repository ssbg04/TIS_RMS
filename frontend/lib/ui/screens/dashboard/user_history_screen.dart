import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../../domain/entities/dashboard_models.dart';
import '../../providers/activity_provider.dart';
import '../../shared/modals/view_activity_modal.dart';

/// Admin-only screen — accessible from Dashboard only (not main nav).
class UserHistoryScreen extends ConsumerStatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  ConsumerState<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends ConsumerState<UserHistoryScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final fmt =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    if (isFrom) {
      ref.read(userHistoryQueryProvider.notifier).setDateFrom(fmt);
    } else {
      ref.read(userHistoryQueryProvider.notifier).setDateTo(fmt);
    }
  }

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
                          const Text('Filter User History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            items: ['All Actions', 'CREATED', 'UPDATED', 'DELETED']
                                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setDialogState(() => pendingAction = v!),
                          ),
                          const SizedBox(height: 16),
                          const Text('Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: pendingRole,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: ['All Roles', 'admin', 'teacher']
                                .map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase())))
                                .toList(),
                            onChanged: (v) => setDialogState(() => pendingRole = v!),
                          ),
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
                              final roleToSet = pendingRole == 'All Roles' ? '' : pendingRole;
                              ref.read(userHistoryQueryProvider.notifier).setAction(actionToSet);
                              ref.read(userHistoryQueryProvider.notifier).setRole(roleToSet);
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
    final historyAsync = ref.watch(userHistoryPageProvider);
    final query = ref.watch(userHistoryQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Account History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(userHistoryPageProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar ───────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                  label: const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.primaryGreen,
                  onPressed: () => _showFilterDialog(query),
                  side: BorderSide.none,
                ),
                _dateChip('From', _fromDate, () => _pickDate(true)),
                _dateChip('To', _toDate, () => _pickDate(false)),
                if (_fromDate != null || _toDate != null || query.action.isNotEmpty || query.role.isNotEmpty)
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
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (data) => data.history.isEmpty
                  ? const Center(
                      child: Text(
                        'No user history found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildList(data.history)),
                        _buildPagination(data, query.page),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label, DateTime? date, VoidCallback onTap) {
    final text = date == null
        ? label
        : '$label: ${date.day}/${date.month}/${date.year}';
    return ActionChip(
      avatar: const Icon(Icons.calendar_today, size: 16),
      label: Text(text),
      onPressed: onTap,
      backgroundColor: date != null
          ? AppColors.primaryGreen.withValues(alpha: 0.1)
          : null,
      labelStyle: TextStyle(
        color: date != null ? AppColors.primaryGreen : Colors.black87,
      ),
    );
  }

  Widget _buildList(List<UserHistoryEntry> history) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) return _buildTable(history);
        return _buildCards(history);
      },
    );
  }

  Widget _buildTable(List<UserHistoryEntry> history) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
          columns: const [
            DataColumn(
              label: Text(
                'Action',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Username',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Full Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Role',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Performed By',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: history
              .map(
                (h) => DataRow(
                  onSelectChanged: (_) {
                    ViewActivityModal.show(
                      context: context,
                      title: 'USER ACTIVITY',
                      description: 'Action performed on ${h.fullName} (@${h.username})',
                      date: _formatDate(h.createdAt),
                      performedBy: h.performedByName ?? h.performedByUsername ?? 'System',
                      action: h.action,
                      actionColor: _actionColor(h.action),
                      icon: _actionIcon(h.action),
                    );
                  },
                  cells: [
                    DataCell(_actionChip(h.action)),
                    DataCell(
                      Text(
                        h.username,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(h.fullName, style: const TextStyle(fontSize: 13)),
                    ),
                    DataCell(_roleChip(h.role)),
                    DataCell(
                      Text(
                        h.performedByName ?? h.performedByUsername ?? '—',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatDate(h.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCards(List<UserHistoryEntry> history) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: history.length,
      separatorBuilder: (_, _s) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final h = history[i];
        return InkWell(
          onTap: () {
            ViewActivityModal.show(
              context: context,
              title: 'USER ACTIVITY',
              description: 'Action performed on ${h.fullName} (@${h.username})',
              date: _formatDate(h.createdAt),
              performedBy: h.performedByName ?? h.performedByUsername ?? 'System',
              action: h.action,
              actionColor: _actionColor(h.action),
              icon: _actionIcon(h.action),
            );
          },
          child: Card(
            elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _actionChip(h.action),
                    const SizedBox(width: 8),
                    _roleChip(h.role),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  h.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '@${h.username}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'by ${h.performedByName ?? h.performedByUsername ?? 'System'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(h.createdAt),
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

  Widget _buildPagination(PaginatedUserHistory data, int current) {
    if (data.totalPages <= 1) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: current > 1
                ? () => ref.read(userHistoryQueryProvider.notifier).setPage(current - 1)
                : null,
          ),
          ...List.generate(data.totalPages, (i) => i + 1)
              .where((p) => (p - current).abs() <= 2)
              .map((p) {
            final isActive = p == current;
            return GestureDetector(
              onTap: () => ref.read(userHistoryQueryProvider.notifier).setPage(p),
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive ? null : Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: current < data.totalPages
                ? () => ref.read(userHistoryQueryProvider.notifier).setPage(current + 1)
                : null,
          ),
        ],
      ),
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

  Widget _roleChip(String role) {
    final isAdmin = role == 'admin';
    final color = isAdmin ? Colors.purple : Colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return AppColors.primaryGreen;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _actionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return Icons.person_add;
      case 'deleted':
        return Icons.person_off;
      default:
        return Icons.manage_accounts;
    }
  }

  String _formatDate(String raw) => pht.formatDateTime(raw);
}
