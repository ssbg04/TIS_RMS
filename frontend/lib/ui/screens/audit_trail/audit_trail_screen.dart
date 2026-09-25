import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../providers/dashboard_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/login_sessions_provider.dart';
import '../../shared/modals/view_activity_modal.dart';
import '../../shared/widgets/app_pagination.dart';
import '../../shared/inputs/app_search_bar.dart';

enum AuditTab { activities, users, sessions }

class AuditTrailScreen extends ConsumerStatefulWidget {
  final String userRole;
  final AuditTab initialTab;

  const AuditTrailScreen({
    super.key,
    required this.userRole,
    this.initialTab = AuditTab.activities,
  });

  @override
  ConsumerState<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends ConsumerState<AuditTrailScreen> {
  late AuditTab _selectedTab;
  final TextEditingController _searchController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;


  @override
  void initState() {
    super.initState();
    _selectedTab = widget.userRole == 'teacher'
        ? AuditTab.activities
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
    if (_selectedTab == AuditTab.activities) {
      ref.read(activityQueryProvider.notifier).reset();
    } else if (_selectedTab == AuditTab.users) {
      ref.read(userHistoryQueryProvider.notifier).reset();
    } else {
      ref.read(loginSessionsQueryProvider.notifier).reset();
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

  String _getBasicActionTitle(String action) {
    final act = action.toLowerCase();
    if (act.contains('create') || act.contains('add')) {
      return 'Added user';
    }
    if (act.contains('update') || act.contains('edit')) {
      return 'Updated user';
    }
    if (act.contains('deactivate')) {
      return 'Deactivated user';
    }
    if (act.contains('activate')) {
      return 'Activated user';
    }
    if (act.contains('delete')) {
      return 'Deleted user';
    }
    if (act.contains('reset')) {
      return 'Reset user password';
    }
    return '$action user';
  }

  void _applySearch(String val) {
    if (_selectedTab == AuditTab.activities) {
      ref.read(activityQueryProvider.notifier).setSearch(val);
    } else if (_selectedTab == AuditTab.users) {
      ref.read(userHistoryQueryProvider.notifier).setSearch(val);
    } else {
      ref.read(loginSessionsQueryProvider.notifier).setSearch(val);
    }
  }

  void _refreshCurrentTab() {
    if (_selectedTab == AuditTab.activities) {
      ref.invalidate(recentActivitiesPageProvider);
    } else if (_selectedTab == AuditTab.users) {
      ref.invalidate(userHistoryPageProvider);
    } else {
      ref.invalidate(loginSessionsPageProvider);
    }
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hint = _selectedTab == AuditTab.activities
        ? 'Search description or user...'
        : _selectedTab == AuditTab.users
            ? 'Search user or admin...'
            : 'Search username or name...';

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                hint: hint,
                controller: _searchController,
                collapsible: false,
                maxWidth: 600,
                onSubmitted: (val) {
                  Navigator.of(ctx).pop();
                  _applySearch(val);
                },
                onChanged: (val) {
                  _applySearch(val);
                },
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actQuery = ref.read(activityQueryProvider);
    final usrQuery = ref.read(userHistoryQueryProvider);

    DateTime? tempFrom = _fromDate;
    DateTime? tempTo = _toDate;
    String tempAction = _selectedTab == AuditTab.activities
        ? actQuery.action
        : _selectedTab == AuditTab.users
            ? usrQuery.action
            : '';
    String tempRole = _selectedTab == AuditTab.users ? usrQuery.role : '';

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isActivities = _selectedTab == AuditTab.activities;
          final isUsers = _selectedTab == AuditTab.users;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: MediaQuery.of(context).size.height < 600 ? 16 : 40,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
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
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isActivities
                                  ? 'Filter Activities'
                                  : isUsers
                                      ? 'Filter User Events'
                                      : 'Filter Login Sessions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Range Picker
                            Text(
                              'Date Range',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final values = await showCalendarDatePicker2Dialog(
                                  context: ctx,
                                  config: CalendarDatePicker2WithActionButtonsConfig(
                                    calendarType: CalendarDatePicker2Type.range,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(const Duration(days: 1)),
                                    selectedDayHighlightColor: AppColors.primaryGreen,
                                  ),
                                  dialogSize: const Size(325, 400),
                                  value: [?tempFrom, ?tempTo],
                                  borderRadius: BorderRadius.circular(16),
                                );
                                if (values != null && values.isNotEmpty) {
                                  setDialogState(() {
                                    tempFrom = values[0];
                                    tempTo = values.length > 1 ? values[1] : values[0];
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: (tempFrom != null || tempTo != null)
                                        ? AppColors.primaryGreen
                                        : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  color: (tempFrom != null || tempTo != null)
                                      ? AppColors.primaryGreen.withValues(alpha: 0.06)
                                      : (isDark ? AppColors.darkSurface2 : Colors.grey.shade50),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 16,
                                      color: (tempFrom != null || tempTo != null)
                                          ? AppColors.primaryGreen
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        tempFrom != null && tempTo != null
                                            ? '${tempFrom!.month}/${tempFrom!.day}/${tempFrom!.year} - ${tempTo!.month}/${tempTo!.day}/${tempTo!.year}'
                                            : tempFrom != null
                                                ? 'From ${tempFrom!.month}/${tempFrom!.day}/${tempFrom!.year}'
                                                : 'Select date range...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: (tempFrom != null || tempTo != null)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: (tempFrom != null || tempTo != null)
                                              ? AppColors.primaryGreen
                                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                    if (tempFrom != null || tempTo != null)
                                      GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            tempFrom = null;
                                            tempTo = null;
                                          });
                                        },
                                        child: const Icon(Icons.close_rounded, size: 16),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Action Filter Section (Activities and Users)
                            if (isActivities || isUsers) ...[
                              const SizedBox(height: 18),
                              Text(
                                'Action',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (isActivities
                                        ? ['All', 'Add', 'Update', 'Archive', 'Delete']
                                        : ['All', 'Add', 'Update', 'Deactivate', 'Activate', 'Delete'])
                                    .map((act) {
                                  final isSel = (act == 'All' && (tempAction.isEmpty || tempAction == 'All')) ||
                                      tempAction.toLowerCase() == act.toLowerCase();
                                  return ChoiceChip(
                                    label: Text(act),
                                    selected: isSel,
                                    showCheckmark: false,
                                    selectedColor: AppColors.primaryGreen.withValues(alpha: 0.18),
                                    backgroundColor: isDark
                                        ? AppColors.darkSurface2
                                        : Colors.grey.shade100,
                                    side: BorderSide(
                                      color: isSel
                                          ? AppColors.primaryGreen
                                          : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                                    ),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      color: isSel
                                          ? AppColors.primaryGreen
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        tempAction = (act == 'All' || !selected) ? '' : act;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],

                            // Role Filter Section (Users tab only)
                            if (isUsers) ...[
                              const SizedBox(height: 18),
                              Text(
                                'User Role',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ['All', 'Admin', 'Teacher', 'Staff'].map((role) {
                                  final isSel = (role == 'All' && (tempRole.isEmpty || tempRole == 'All')) ||
                                      tempRole.toLowerCase() == role.toLowerCase();
                                  return ChoiceChip(
                                    label: Text(role),
                                    selected: isSel,
                                    showCheckmark: false,
                                    selectedColor: AppColors.primaryGreen.withValues(alpha: 0.18),
                                    backgroundColor: isDark
                                        ? AppColors.darkSurface2
                                        : Colors.grey.shade100,
                                    side: BorderSide(
                                      color: isSel
                                          ? AppColors.primaryGreen
                                          : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                                    ),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      color: isSel
                                          ? AppColors.primaryGreen
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        tempRole = (role == 'All' || !selected) ? '' : role;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Footer Buttons
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                tempFrom = null;
                                tempTo = null;
                                tempAction = '';
                                tempRole = '';
                              });
                            },
                            child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            ),
                            onPressed: () {
                              setState(() {
                                _fromDate = tempFrom;
                                _toDate = tempTo;
                              });

                              final fromStr = tempFrom != null
                                  ? "${tempFrom!.year}-${tempFrom!.month.toString().padLeft(2, '0')}-${tempFrom!.day.toString().padLeft(2, '0')}"
                                  : '';
                              final toStr = tempTo != null
                                  ? "${tempTo!.year}-${tempTo!.month.toString().padLeft(2, '0')}-${tempTo!.day.toString().padLeft(2, '0')}"
                                  : '';

                              if (isActivities) {
                                ref.read(activityQueryProvider.notifier).setDateFrom(fromStr);
                                ref.read(activityQueryProvider.notifier).setDateTo(toStr);
                                ref.read(activityQueryProvider.notifier).setAction(tempAction);
                              } else if (isUsers) {
                                ref.read(userHistoryQueryProvider.notifier).setDateFrom(fromStr);
                                ref.read(userHistoryQueryProvider.notifier).setDateTo(toStr);
                                ref.read(userHistoryQueryProvider.notifier).setAction(tempAction);
                                ref.read(userHistoryQueryProvider.notifier).setRole(tempRole);
                              } else {
                                ref.read(loginSessionsQueryProvider.notifier).setDateFrom(fromStr);
                                ref.read(loginSessionsQueryProvider.notifier).setDateTo(toStr);
                              }

                              Navigator.of(ctx).pop();
                            },
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

  Widget _buildTabSwitcher(bool isDark, {bool isMobile = false}) {
    return Container(
      height: isMobile ? 34 : 36,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabItem(
            label: 'Activities',
            icon: Icons.list_alt_rounded,
            tab: AuditTab.activities,
            isMobile: isMobile,
          ),
          _buildTabItem(
            label: 'Users',
            icon: Icons.account_circle_outlined,
            tab: AuditTab.users,
            isMobile: isMobile,
          ),
          _buildTabItem(
            label: 'Sessions',
            icon: Icons.devices_rounded,
            tab: AuditTab.sessions,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersStrip(BuildContext context, bool isDark) {
    final actQuery = ref.watch(activityQueryProvider);
    final usrQuery = ref.watch(userHistoryQueryProvider);
    final sesQuery = ref.watch(loginSessionsQueryProvider);

    final currentSearch = _selectedTab == AuditTab.activities
        ? actQuery.search
        : _selectedTab == AuditTab.users
            ? usrQuery.search
            : sesQuery.search;

    final currentAction = _selectedTab == AuditTab.activities
        ? actQuery.action
        : _selectedTab == AuditTab.users
            ? usrQuery.action
            : '';

    final currentRole = _selectedTab == AuditTab.users ? usrQuery.role : '';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_fromDate != null || _toDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                avatar: const Icon(Icons.calendar_today_rounded, size: 13),
                label: Text(
                  _fromDate != null && _toDate != null
                      ? '${_fromDate!.month}/${_fromDate!.day} - ${_toDate!.month}/${_toDate!.day}'
                      : 'From ${_fromDate!.month}/${_fromDate!.day}',
                  style: const TextStyle(fontSize: 11),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                  });
                  if (_selectedTab == AuditTab.activities) {
                    ref.read(activityQueryProvider.notifier).setDateFrom('');
                    ref.read(activityQueryProvider.notifier).setDateTo('');
                  } else if (_selectedTab == AuditTab.users) {
                    ref.read(userHistoryQueryProvider.notifier).setDateFrom('');
                    ref.read(userHistoryQueryProvider.notifier).setDateTo('');
                  } else {
                    ref.read(loginSessionsQueryProvider.notifier).setDateFrom('');
                    ref.read(loginSessionsQueryProvider.notifier).setDateTo('');
                  }
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          if (currentAction.isNotEmpty && currentAction != 'All')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                avatar: const Icon(Icons.bolt_rounded, size: 13),
                label: Text(
                  'Action: $currentAction',
                  style: const TextStyle(fontSize: 11),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  if (_selectedTab == AuditTab.activities) {
                    ref.read(activityQueryProvider.notifier).setAction('');
                  } else if (_selectedTab == AuditTab.users) {
                    ref.read(userHistoryQueryProvider.notifier).setAction('');
                  }
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          if (currentRole.isNotEmpty && currentRole != 'All')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                avatar: const Icon(Icons.badge_rounded, size: 13),
                label: Text(
                  'Role: $currentRole',
                  style: const TextStyle(fontSize: 11),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(userHistoryQueryProvider.notifier).setRole('');
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          if (currentSearch.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(
                avatar: const Icon(Icons.search, size: 13),
                label: Text(
                  '"$currentSearch"',
                  style: const TextStyle(fontSize: 11),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  _searchController.clear();
                  _applySearch('');
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Reset', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isAdmin = widget.userRole == 'admin';

    final actQuery = ref.watch(activityQueryProvider);
    final usrQuery = ref.watch(userHistoryQueryProvider);
    final sesQuery = ref.watch(loginSessionsQueryProvider);

    final currentSearch = _selectedTab == AuditTab.activities
        ? actQuery.search
        : _selectedTab == AuditTab.users
            ? usrQuery.search
            : sesQuery.search;

    final currentAction = _selectedTab == AuditTab.activities
        ? actQuery.action
        : _selectedTab == AuditTab.users
            ? usrQuery.action
            : '';

    final currentRole = _selectedTab == AuditTab.users ? usrQuery.role : '';

    int activeFilterCount = 0;
    if (_fromDate != null || _toDate != null) activeFilterCount++;
    if (currentAction.isNotEmpty && currentAction != 'All') activeFilterCount++;
    if (currentRole.isNotEmpty && currentRole != 'All') activeFilterCount++;
    if (currentSearch.isNotEmpty) activeFilterCount++;

    final hasActiveFilters = activeFilterCount > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Compact Header & Controls ─────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 8 : 10,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMobile) ...[
                    // Mobile Layout: Full-width segmented tab switcher
                    if (isAdmin)
                      Container(
                        width: double.infinity,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabItem(
                                label: 'Activities',
                                icon: Icons.list_alt_rounded,
                                tab: AuditTab.activities,
                                isMobile: true,
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                label: 'Users',
                                icon: Icons.account_circle_outlined,
                                tab: AuditTab.users,
                                isMobile: true,
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                label: 'Sessions',
                                icon: Icons.devices_rounded,
                                tab: AuditTab.sessions,
                                isMobile: true,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Activities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    const SizedBox(height: 6),

                    // Sub-row: Section title or filter chips on left, Search/Filter/Refresh on right
                    Row(
                      children: [
                        if (hasActiveFilters)
                          Expanded(
                            child: _buildActiveFiltersStrip(context, isDark),
                          )
                        else ...[
                          Text(
                            _selectedTab == AuditTab.activities
                                ? 'Recent Activity Logs'
                                : _selectedTab == AuditTab.users
                                    ? 'User Event Logs'
                                    : 'Login & Session Logs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const Spacer(),
                        ],

                        // Search Icon
                        Tooltip(
                          message: currentSearch.isNotEmpty ? 'Clear Search' : 'Search',
                          child: IconButton(
                            icon: Icon(
                              currentSearch.isNotEmpty ? Icons.close : Icons.search,
                              size: 20,
                              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              if (currentSearch.isNotEmpty) {
                                _searchController.clear();
                                _applySearch('');
                              } else {
                                _showSearchDialog(context);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Filter Icon
                        Tooltip(
                          message: 'Filter History',
                          child: IconButton(
                            onPressed: () => _showFilterDialog(context),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            icon: Badge(
                              isLabelVisible: activeFilterCount > 0,
                              label: Text(activeFilterCount.toString()),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: activeFilterCount > 0
                                    ? AppColors.primaryGreen
                                    : (isDark ? AppColors.darkTextPrimary : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Refresh Icon
                        Tooltip(
                          message: 'Refresh',
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _refreshCurrentTab,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Desktop Layout: Single row with tabs on left and controls on right
                    Row(
                      children: [
                        if (isAdmin)
                          _buildTabSwitcher(isDark, isMobile: false)
                        else
                          Text(
                            'Activities',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        const Spacer(),

                        // Search Icon (same as other screens)
                        Tooltip(
                          message: currentSearch.isNotEmpty
                              ? 'Clear Search'
                              : 'Search (Ctrl+F)',
                          child: IconButton(
                            icon: Icon(
                              currentSearch.isNotEmpty
                                  ? Icons.close
                                  : Icons.search,
                              size: 22,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : Colors.black87,
                            ),
                            onPressed: () {
                              if (currentSearch.isNotEmpty) {
                                _searchController.clear();
                                _applySearch('');
                              } else {
                                _showSearchDialog(context);
                              }
                            },
                          ),
                        ),

                        // Filter Icon (same as other screens)
                        Tooltip(
                          message: 'Filter History',
                          child: IconButton(
                            onPressed: () => _showFilterDialog(context),
                            icon: Badge(
                              isLabelVisible: activeFilterCount > 0,
                              label: Text(activeFilterCount.toString()),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 21,
                                color: activeFilterCount > 0
                                    ? AppColors.primaryGreen
                                    : (isDark
                                        ? AppColors.darkTextPrimary
                                        : Colors.black87),
                              ),
                            ),
                          ),
                        ),

                        // Refresh Icon
                        Tooltip(
                          message: 'Refresh',
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 21),
                            onPressed: _refreshCurrentTab,
                          ),
                        ),
                      ],
                    ),

                    // Active Filter Chips Strip (compact)
                    if (hasActiveFilters) ...[
                      const SizedBox(height: 6),
                      _buildActiveFiltersStrip(context, isDark),
                    ],
                  ],
                ],
              ),
            ),

            // ── Main Content Area ─────────────────────────────────────
            Expanded(
              child: _selectedTab == AuditTab.activities
                  ? _buildRecentActivitiesTab(isDark, isMobile)
                  : _selectedTab == AuditTab.users
                      ? _buildUserHistoryTab(isDark, isMobile)
                      : _buildSessionsTab(isDark, isMobile),
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
    bool isMobile = false,
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
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 4 : 6,
        ),
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
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isMobile ? 15 : 16,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            SizedBox(width: isMobile ? 5 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 12.5 : 13,
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
                          date: pht.formatDateTime12H(item.createdAt),
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
                                        pht.formatDateTime12H(item.createdAt),
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
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 8 : 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data.totalPages > 1)
                          AppPagination(
                            currentPage: data.page,
                            totalPages: data.totalPages,
                            onPageChanged: (newPage) {
                              ref
                                  .read(activityQueryProvider.notifier)
                                  .setPage(newPage);
                            },
                          ),
                        const SizedBox(height: 4),
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
                      ],
                    )
                  : Row(
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
                        if (data.totalPages > 1)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: AppPagination(
                                currentPage: data.page,
                                totalPages: data.totalPages,
                                onPageChanged: (newPage) {
                                  ref
                                      .read(activityQueryProvider.notifier)
                                      .setPage(newPage);
                                },
                              ),
                            ),
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
                          title: _getBasicActionTitle(item.action),
                          description:
                              'User @${item.username} (${item.fullName.isNotEmpty ? item.fullName : 'No Name'}) with role "${item.role}" was ${item.action}.',
                          date: pht.formatDateTime12H(item.createdAt),
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
                                        pht.formatDateTime12H(item.createdAt),
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
                                  // Action Title in basic words
                                  Text(
                                    _getBasicActionTitle(item.action),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  // Target user info (sub-description)
                                  Text(
                                    item.fullName.isNotEmpty
                                        ? '${item.fullName} (@${item.username})'
                                        : '@${item.username}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  // Action by (sub-sub-description)
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
                                        'Action by: ${item.performedByName ?? item.performedByUsername ?? 'System'}',
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
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 8 : 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data.totalPages > 1)
                          AppPagination(
                            currentPage: data.page,
                            totalPages: data.totalPages,
                            onPageChanged: (newPage) {
                              ref
                                  .read(userHistoryQueryProvider.notifier)
                                  .setPage(newPage);
                            },
                          ),
                        const SizedBox(height: 4),
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
                      ],
                    )
                  : Row(
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
                        if (data.totalPages > 1)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: AppPagination(
                                currentPage: data.page,
                                totalPages: data.totalPages,
                                onPageChanged: (newPage) {
                                  ref
                                      .read(userHistoryQueryProvider.notifier)
                                      .setPage(newPage);
                                },
                              ),
                            ),
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
  // TAB 3: SESSIONS (LOGIN / LOGOUT LOGS)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSessionsTab(bool isDark, bool isMobile) {
    final sessionsAsync = ref.watch(loginSessionsPageProvider);

    return sessionsAsync.when(
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
                'Failed to load sessions',
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
                onPressed: () => ref.invalidate(loginSessionsPageProvider),
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
        if (data.logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.devices_other_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching session logs found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try adjusting your search or date range filters.',
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
                itemCount: data.logs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final log = data.logs[index];
                  final isActive = log.isActive;
                  final rawPlatform = log.platform.trim();
                  final platformLower = (rawPlatform.isEmpty || rawPlatform.toLowerCase() == 'unknown')
                      ? 'windows'
                      : rawPlatform.toLowerCase();
                  final String platformDisplay = platformLower.toUpperCase();
                  final IconData platformIcon = platformLower.contains('android')
                      ? Icons.android_rounded
                      : platformLower.contains('ios') || platformLower.contains('iphone')
                          ? Icons.phone_iphone_rounded
                          : platformLower.contains('win')
                              ? Icons.laptop_windows_rounded
                              : platformLower.contains('mac')
                                  ? Icons.laptop_mac_rounded
                                  : platformLower.contains('web')
                                      ? Icons.web_rounded
                                      : Icons.laptop_windows_rounded;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ViewActivityModal.show(
                          context: context,
                          title: isActive ? 'Active Session' : 'Completed Session',
                          description:
                              'User @${log.username} (${log.fullName.isNotEmpty ? log.fullName : 'No Name'}) logged in via $platformDisplay (${log.ipAddress ?? 'Unknown IP'}).\n\n'
                              'Login: ${pht.formatDateTime12H(log.loginAt)}\n'
                              '${log.logoutAt != null ? 'Logout: ${pht.formatDateTime12H(log.logoutAt!)}' : 'Session is currently active.'}',
                          date: pht.formatDateTime12H(log.loginAt),
                          performedBy: log.fullName.isNotEmpty ? log.fullName : log.username,
                          action: isActive ? 'ACTIVE' : 'LOGGED OUT',
                          actionColor: isActive ? const Color(0xFF10B981) : Colors.grey,
                          icon: platformIcon,
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
                            // Platform Avatar
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isActive
                                        ? const Color(0xFF10B981)
                                        : Colors.grey)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                platformIcon,
                                color: isActive
                                    ? const Color(0xFF10B981)
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Status Badge (Active Now vs Logged Out)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isActive
                                                  ? const Color(0xFF10B981)
                                                  : Colors.grey)
                                              .withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isActive) ...[
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              isActive ? 'ACTIVE NOW' : 'LOGGED OUT',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isActive
                                                    ? const Color(0xFF10B981)
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Role Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.grey.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          log.role.toUpperCase(),
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
                                      // Login Timestamp
                                      Text(
                                        pht.formatDateTime12H(log.loginAt),
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
                                  // User name & username
                                  Text(
                                    log.fullName.isNotEmpty
                                        ? '${log.fullName} (@${log.username})'
                                        : '@${log.username}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Platform & IP & Logout info
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            platformIcon,
                                            size: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            platformDisplay,
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
                                      if (log.ipAddress != null && log.ipAddress!.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lan_outlined,
                                              size: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              log.ipAddress!,
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
                                      if (log.logoutAt != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 13,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Left: ${pht.formatDateTime12H(log.logoutAt!)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.55),
                                              ),
                                            ),
                                          ],
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
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 8 : 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data.totalPages > 1)
                          AppPagination(
                            currentPage: data.page,
                            totalPages: data.totalPages,
                            onPageChanged: (newPage) {
                              ref
                                  .read(loginSessionsQueryProvider.notifier)
                                  .setPage(newPage);
                            },
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${data.total} sessions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: ${data.total} sessions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        if (data.totalPages > 1)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: AppPagination(
                                currentPage: data.page,
                                totalPages: data.totalPages,
                                onPageChanged: (newPage) {
                                  ref
                                      .read(loginSessionsQueryProvider.notifier)
                                      .setPage(newPage);
                                },
                              ),
                            ),
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
