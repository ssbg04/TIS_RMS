import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../shared/cards/stat_card.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../../domain/entities/dashboard_models.dart';
import '../../../domain/entities/user_model.dart';
import 'recent_activities_screen.dart';
import 'user_history_screen.dart';
import '../../shared/menus/profile_dropdown_menu.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../settings/teacher_management_screen.dart';
import '../settings/requirements_settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _setupBannerDismissed = false;
  final TextEditingController _searchController = TextEditingController();
  ProviderSubscription<String>? _tabListener;

  @override
  void dispose() {
    _tabListener?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationsProvider.notifier).refreshNotifications();

      // Listen to tab changes outside of build() so it is properly cleaned up.
      _tabListener = ref.listenManual<String>(activeTabProvider, (previous, next) {
        if (!mounted) return;
        if (next == 'Dashboard' && previous != 'Dashboard') {
          _handleRefresh();
          ref.read(authProvider.notifier).refreshUser();
        }
        if (next != 'Dashboard' && _searchController.text.isNotEmpty) {
          _searchController.clear();
        }
      });
    });
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    ref.invalidate(dashboardDataProvider);
    if (!mounted) return;
    ref.read(notificationsProvider.notifier).refreshNotifications();
    if (!mounted) return;
    await ref.read(dashboardDataProvider.future);
  }

  Color _getNotificationColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('student')) return Colors.blue;
    if (t.contains('document')) return const Color(0xFF1C8248);
    if (t.contains('password')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getNotificationIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('student')) return Icons.person_add;
    if (t.contains('document')) return Icons.upload_file;
    if (t.contains('password')) return Icons.lock_reset;
    return Icons.notifications;
  }

  void _showNotifications(BuildContext context) {
    final notificationsAsync = ref.read(notificationsProvider);
    final list = notificationsAsync.value ?? [];

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        // ── Header row ────────────────────────────────────────────────
        PopupMenuItem(
          enabled: false,
          child: Container(
            width: 300,
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (list.isNotEmpty) ...[
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(notificationsProvider.notifier).markAllAsRead();
                        },
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1C8248), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(notificationsProvider.notifier).clearNotifications();
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        // ── Empty state ───────────────────────────────────────────────
        if (list.isEmpty)
          const PopupMenuItem(
            enabled: false,
            child: SizedBox(
              width: 300,
              height: 60,
              child: Center(
                child: Text('No new notifications', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          )
        // ── Notification items ────────────────────────────────────────
        else
          ...list.take(5).map((note) => PopupMenuItem(
            onTap: () {
              ref.read(notificationsProvider.notifier).markAsRead(note.id);
            },
            child: SizedBox(
              width: 300,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getNotificationColor(note.title).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getNotificationIcon(note.title), color: _getNotificationColor(note.title), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: TextStyle(
                                fontWeight: note.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (!note.isRead)
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: note.isRead ? Colors.black54 : Colors.black87,
                          fontWeight: note.isRead ? FontWeight.normal : FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(_formatDate(note.createdAt), style: const TextStyle(fontSize: 10, color: Colors.black38)),
                    ],
                  )),
                ],
              ),
            ),
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final user           = ref.watch(authProvider).value;
    final isAdmin        = user?.role == 'admin';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('$error', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _handleRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context, user),
                  const SizedBox(height: 32),
                  const Text('Dashboard Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back, ${user?.firstName ?? 'Admin'}. Here is what is happening today.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  // ── Admin setup guidance banner ──────────────────────
                  if (isAdmin && !_setupBannerDismissed) ...[
                    const SizedBox(height: 20),
                    _buildSetupGuidanceBanner(context),
                  ],
                  const SizedBox(height: 24),
                  _buildStatGrid(data.stats, user),
                  const SizedBox(height: 32),
                  _buildRecentActivitiesSection(data.recentActivities, user),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── ADMIN SETUP GUIDANCE BANNER ───────────────────────────────────────────
  Widget _buildSetupGuidanceBanner(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.08),
            Colors.blue.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings_suggest_rounded, color: AppColors.primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Setup Required',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Before using the system, please configure the following sections to get started:',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _setupBannerDismissed = true),
                      icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _setupNavButton(
                      context,
                      icon: Icons.people_outline,
                      label: 'Teachers & Academic Setup',
                      isMobile: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TeacherManagementScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _setupNavButton(
                      context,
                      icon: Icons.folder_open_outlined,
                      label: 'Document Requirements',
                      isMobile: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RequirementsSettingsScreen()),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_suggest_rounded, color: AppColors.primaryGreen, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Setup Required',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Before using the system, please configure the following sections to get started:',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _setupNavButton(
                            context,
                            icon: Icons.people_outline,
                            label: 'Teachers & Academic Setup',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TeacherManagementScreen()),
                            ),
                          ),
                          _setupNavButton(
                            context,
                            icon: Icons.folder_open_outlined,
                            label: 'Document Requirements',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RequirementsSettingsScreen()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                IconButton(
                  onPressed: () => setState(() => _setupBannerDismissed = true),
                  icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
    );
  }

  Widget _setupNavButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isMobile = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            if (isMobile)
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                ),
              )
            else
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primaryGreen),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, UserModel? user) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: AppSearchBar(
            controller: _searchController,
            hint: 'Search students by LRN or Name...',
            maxWidth: 420,
            onSubmitted: (value) {
              ref.read(studentQueryProvider.notifier).setSearch(value);
              ref.read(activeTabProvider.notifier).setTab('Students');
              _searchController.clear();
            },
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            Builder(builder: (ctx) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, size: 28),
                  onPressed: () => _showNotifications(ctx),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            )),
            const SizedBox(width: 16),
            ProfileDropdownMenu(
              user: user,
              onRefresh: _handleRefresh, 
            ),
          ],
        ),
      ],
    );
  }

  // ── STAT GRID ─────────────────────────────────────────────────────────────
  Widget _buildStatGrid(DashboardStats stats, UserModel? user) {
    final isAdmin = user?.role == 'admin';
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount;
      if (constraints.maxWidth >= 800) {
        crossAxisCount = isAdmin ? 4 : 3;
      } else {
        crossAxisCount = 2;
      }
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 110,
        ),
        children: [
          StatCard(title: 'Total Students',    value: stats.totalStudents.toString(),      icon: Icons.school),
          if (isAdmin)
            StatCard(title: 'Active Users',      value: stats.activeUsers.toString(),        icon: Icons.badge,        iconColor: Colors.blue),
          StatCard(title: 'Complete Docs',     value: stats.completedDocuments.toString(), icon: Icons.task_alt,     iconColor: AppColors.primaryGreen),
          StatCard(title: 'Missing Docs',      value: stats.missingDocuments.toString(),   icon: Icons.folder_off,   iconColor: Colors.orange),
        ],
      );
    });
  }

  // ── RECENT ACTIVITIES SECTION ─────────────────────────────────────────────
  Widget _buildRecentActivitiesSection(PaginatedActivities paginatedActivities, UserModel? user) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final headerWidget = isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (user?.role == 'admin')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UserHistoryScreen()),
                        ),
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('User History'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen, padding: EdgeInsets.zero),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecentActivitiesScreen()),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen, padding: EdgeInsets.zero),
                  ),
                ],
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Row(
                children: [
                  if (user?.role == 'admin')
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UserHistoryScreen()),
                      ),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('User History'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecentActivitiesScreen()),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                  ),
                ],
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerWidget,
        const SizedBox(height: 12),
        _buildActivitiesList(paginatedActivities.activities),
      ],
    );
  }

  Widget _buildActivitiesList(List<RecentActivity> activities) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Center(child: Text('No recent activities yet.', style: TextStyle(color: Colors.grey))),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, _s) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final a = activities[index];

          if (isMobile) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _actionColor(a.action).withValues(alpha: 0.1),
                        child: Icon(_actionIcon(a.action, a.entityType), color: _actionColor(a.action), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${a.performedBy ?? a.username ?? 'System'} · ${_formatDate(a.createdAt)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildActionChip(a.action),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.description,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            );
          }

          return Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: _actionColor(a.action).withValues(alpha: 0.1),
                child: Icon(_actionIcon(a.action, a.entityType), color: _actionColor(a.action), size: 20),
              ),
              title: Text(a.description, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text(
                '${a.performedBy ?? a.username ?? 'System'} · ${_formatDate(a.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: _buildActionChip(a.action),
            ),
          );
        },
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Color _actionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE': return AppColors.primaryGreen;
      case 'DELETE': return Colors.red;
      default:       return Colors.blue;
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

  Widget _buildActionChip(String action) {
    final color = _actionColor(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        action.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _formatDate(String raw) => pht.formatRelative(raw);
}