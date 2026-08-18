import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../shared/cards/stat_card.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/users_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider.dart';

import '../../../domain/entities/dashboard_models.dart';
import '../../../domain/entities/user_model.dart';
import 'recent_activities_screen.dart';
import 'user_history_screen.dart';
import '../../shared/menus/profile_dropdown_menu.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../settings/requirements_settings_screen.dart';
import '../settings/teacher_management_screen.dart';
import 'widgets/notification_dropdown.dart';
import '../../shared/modals/view_activity_modal.dart';
import 'widgets/dashboard_kpis.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _setupBannerDismissed = false;
  bool _setupBannerMinimized = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();
  ProviderSubscription<String>? _tabListener;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabListener?.close();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(dashboardDataProvider);
      ref.read(notificationsProvider.notifier).refreshNotifications();

      if (ref.read(activeTabProvider) == 'Dashboard') {
        _startPolling();
        _shortcutFocusNode.requestFocus();
      }

      // Listen to tab changes outside of build() so it is properly cleaned up.
      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (next == 'Dashboard' && previous != 'Dashboard') {
          setState(() {
            _setupBannerDismissed = false;
            _setupBannerMinimized = true;
          });
          if (_searchFocusNode.hasFocus) _searchFocusNode.unfocus();
          _searchController.clear();
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) {
              _shortcutFocusNode.requestFocus();
            }
          });

          _handleRefresh();
          ref.read(authProvider.notifier).refreshUser();
          _startPolling();
        } else if (next != 'Dashboard') {
          _stopPolling();
          if (_searchController.text.isNotEmpty) {
            _searchController.clear();
          }
        }
      });
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          ref.read(authProvider).value != null &&
          ref.read(activeTabProvider) == 'Dashboard') {
        ref.invalidate(dashboardDataProvider);
        ref.invalidate(dashboardKpisProvider);
        ref.read(notificationsProvider.notifier).refreshNotifications();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    ref.invalidate(dashboardDataProvider);
    ref.invalidate(dashboardKpisProvider);
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
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
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
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (list.isNotEmpty) ...[
                      InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(notificationsProvider.notifier)
                              .markAllAsRead();
                        },
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1C8248),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(notificationsProvider.notifier)
                              .clearNotifications();
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
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
          PopupMenuItem(
            enabled: false,
            child: SizedBox(
              width: 300,
              height: 120,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_off_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No new notifications',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        // ── Notification items ────────────────────────────────────────
        else
          PopupMenuItem(
            enabled: false,
            padding: EdgeInsets.zero,
            child: NotificationDropdownWidget(
              notifications: list,
              onViewActivity: (context, title, desc, date, icon, color) {
                ViewActivityModal.show(
                  context: context,
                  title: title,
                  description: desc,
                  date: date,
                  icon: icon,
                  actionColor: color,
                );
              },
              getIcon: _getNotificationIcon,
              getColor: _getNotificationColor,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final user = ref.watch(authProvider).value;
    final isAdmin = user?.role == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Clean up if not used
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _showSearchDialog(context);
        },
      },
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
        child: dashboardAsync.when(
          skipLoadingOnReload: true,
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
          data: (data) => Stack(
            children: [
              // Scrollable Content
              Positioned.fill(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 90, 24, 76),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard Overview',
                          style: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.width > 600
                                ? 28
                                : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isAdmin && !_setupBannerDismissed) ...[
                          _buildSetupGuidanceBanner(context),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          'Welcome back, ${user?.firstName ?? 'Admin'}. Here is what is happening today.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildStatGrid(data.stats, user),
                        const SizedBox(height: 32),
                        const DashboardKpisSection(),
                        const SizedBox(height: 32),
                        _buildHistorySections(data, user),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
              // Sticky Blur Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(context, user),
              ),
              // Sticky Blur Bottom Bar Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.0, 0.4],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                                    AppColors.darkPageBackground.withValues(alpha: 0.0),
                                    AppColors.darkPageBackground.withValues(alpha: 0.85),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.85),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              width: 1.0,
            ),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.settings_suggest_rounded,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Setup Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (!_setupBannerMinimized) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Before using the system, please configure the following sections to get started:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () =>
                                _setupBannerMinimized = !_setupBannerMinimized,
                          ),
                          icon: Icon(
                            _setupBannerMinimized
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _setupBannerDismissed = true),
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (!_setupBannerMinimized) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _setupNavButton(
                            context,
                            icon: Icons.people_outline,
                            label: 'Teachers & Academic Setup',
                            isMobile: true,
                            onTap: () => TeacherManagementModal.open(context),
                          ),
                          const SizedBox(height: 10),
                          _setupNavButton(
                            context,
                            icon: Icons.folder_open_outlined,
                            label: 'Document Requirements',
                            isMobile: true,
                            onTap: () => RequirementsModal.open(context),
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.settings_suggest_rounded,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Setup Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (!_setupBannerMinimized) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Before using the system, please configure the following sections to get started:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
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
                                  onTap: () =>
                                      TeacherManagementModal.open(context),
                                ),
                                _setupNavButton(
                                  context,
                                  icon: Icons.folder_open_outlined,
                                  label: 'Document Requirements',
                                  onTap: () => RequirementsModal.open(context),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Minimize and Dismiss buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => setState(
                            () =>
                                _setupBannerMinimized = !_setupBannerMinimized,
                          ),
                          icon: Icon(
                            _setupBannerMinimized
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              setState(() => _setupBannerDismissed = true),
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _setupNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isMobile = false,
  }) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface2 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 24),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                collapsible: false,
                hint: 'Search students by LRN or Name...',
                maxWidth: 600,
                onSubmitted: (value) {
                  Navigator.of(context).pop(); // Close dialog
                  ref.read(studentQueryProvider.notifier).setSearch(value);
                  ref.invalidate(studentPageProvider);
                  ref.read(activeTabProvider.notifier).setTab('Students');
                  _searchController.clear();
                },
              ),
            ),
          ),
        );
      },
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, UserModel? user) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount =
        notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
          stops: [0.6, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        AppColors.darkPageBackground.withValues(alpha: 0.85),
                        AppColors.darkPageBackground.withValues(alpha: 0.15),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.85),
                        Colors.white.withValues(alpha: 0.15),
                      ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                Row(
                  children: [
                    Tooltip(
                      richMessage: const TextSpan(
                        text: 'Search Students ',
                        children: [
                          TextSpan(
                            text: '(Ctrl+F)',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, size: 32),
                        onPressed: () => _showSearchDialog(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (ctx) => Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, size: 32),
                            onPressed: () => _showNotifications(ctx),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ProfileDropdownMenu(user: user, onRefresh: _handleRefresh),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── STAT GRID ─────────────────────────────────────────────────────────────
  Widget _buildStatGrid(DashboardStats stats, UserModel? user) {
    final isAdmin = user?.role == 'admin';
    final isTeacher = user?.role == 'teacher';

    if (isTeacher && !stats.hasAssignedSections) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.class_outlined,
                size: 56,
                color: Colors.orange.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No sections assigned',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have no sections assigned to your account yet.\nContact your administrator to assign sections so you can see your students here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWindowsApp =
            Theme.of(context).platform == TargetPlatform.windows ||
            constraints.maxWidth >= 800;
        final int crossAxisCount = isWindowsApp ? (isAdmin ? 4 : 3) : 1;
        final bool isSquare = isWindowsApp;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: isSquare ? 135 : 94,
          ),
          children: [
            StatCard(
              title: 'Total Students',
              value: stats.totalStudents.toString(),
              icon: Icons.school_rounded,
              isSquare: isSquare,
              onTap: () {
                ref.read(studentQueryProvider.notifier).reset();
                ref.invalidate(studentPageProvider);
                ref.read(activeTabProvider.notifier).setTab('Students');
              },
            ),
            if (isAdmin)
              StatCard(
                title: 'Active Users',
                value: stats.activeUsers.toString(),
                icon: Icons.group,
                iconColor: Colors.blue,
                isSquare: isSquare,
                onTap: () {
                  ref.invalidate(usersProvider);
                  ref.read(activeTabProvider.notifier).setTab('Users');
                },
              ),
            StatCard(
              title: 'Complete Docs',
              value: stats.completedDocuments.toString(),
              icon: Icons.fact_check_rounded,
              iconColor: AppColors.primaryGreen,
              isSquare: isSquare,
              onTap: () {
                ref.invalidate(foldersProvider);
                ref.invalidate(documentPageProvider);
                ref.read(activeTabProvider.notifier).setTab('Documents');
              },
            ),
            StatCard(
              title: 'Missing Docs',
              value: stats.missingDocuments.toString(),
              icon: Icons.assignment_late_rounded,
              iconColor: Colors.orange,
              isSquare: isSquare,
              onTap: () {
                ref.invalidate(foldersProvider);
                ref.invalidate(documentPageProvider);
                ref.read(activeTabProvider.notifier).setTab('Documents');
              },
            ),
          ],
        );
      },
    );
  }

  // ── HISTORY SECTIONS ─────────────────────────────────────────────
  Widget _buildHistorySections(DashboardData data, UserModel? user) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;
    final isAdmin = user?.role == 'admin';

    Widget buildSection({
      required String title,
      required VoidCallback onViewAll,
      required Widget listWidget,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          listWidget,
        ],
      );
    }

    final recentActivitiesSection = buildSection(
      title: 'Recent Activities',
      onViewAll: () => Navigator.of(context)
          .push(
            MaterialPageRoute(builder: (_) => const RecentActivitiesScreen()),
          )
          .then((_) => _handleRefresh()),
      listWidget: _buildActivitiesList(data.recentActivities.activities),
    );

    if (!isAdmin) {
      return recentActivitiesSection;
    }

    final userHistorySection = buildSection(
      title: 'User History',
      onViewAll: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const UserHistoryScreen()))
          .then((_) => _handleRefresh()),
      listWidget: _buildUserHistoryList(data.userHistory?.history ?? []),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          userHistorySection,
          const SizedBox(height: 32),
          recentActivitiesSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: userHistorySection),
        const SizedBox(width: 24),
        Expanded(child: recentActivitiesSection),
      ],
    );
  }

  Widget _buildActivitiesList(List<RecentActivity> activities) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No recent activities yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Theme.of(context).dividerColor),
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
                    const SizedBox(height: 4),
                    Text(
                      '${a.performedBy ?? a.username ?? 'System'} · ${_formatDate(a.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHistoryList(List<UserHistoryEntry> history) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No user history yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Theme.of(context).dividerColor),
        itemBuilder: (context, index) {
          final h = history[index];
          final desc = '${h.action.toUpperCase()} User: ${h.fullName}';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: () {
                ViewActivityModal.show(
                  context: context,
                  title: 'USER ACTIVITY',
                  description: desc,
                  date: pht.formatModalDate(h.createdAt),
                  performedBy:
                      h.performedByName ?? h.performedByUsername ?? 'System',
                  action: h.action,
                  actionColor: _actionColor(h.action),
                  icon: _actionIcon(h.action, 'user'),
                );
              },
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: CircleAvatar(
                  backgroundColor: _actionColor(
                    h.action,
                  ).withValues(alpha: 0.1),
                  child: Text(
                    _getInitials(h.fullName),
                    style: TextStyle(
                      color: _actionColor(h.action),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildActionChip(h.action),
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
                    const SizedBox(height: 4),
                    Text(
                      '${h.performedByName ?? h.performedByUsername ?? 'System'} · ${_formatDate(h.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Color _actionColor(String action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (action.toUpperCase()) {
      case 'CREATE':
        return isDark ? Colors.green.shade300 : AppColors.primaryGreen;
      case 'DELETE':
        return isDark ? Colors.red.shade300 : Colors.red;
      default:
        return isDark ? Colors.blue.shade300 : Colors.blue;
    }
  }

  IconData _actionIcon(String action, String entityType) {
    if (entityType == 'user') {
      switch (action.toUpperCase()) {
        case 'CREATE':
          return Icons.person_add_alt_1_rounded;
        case 'DELETE':
          return Icons.person_off_rounded;
        default:
          return Icons.manage_accounts_rounded;
      }
    }
    if (entityType == 'student') {
      switch (action.toUpperCase()) {
        case 'CREATE':
          return Icons.school_rounded;
        case 'DELETE':
          return Icons.delete_forever_rounded;
        default:
          return Icons.edit_rounded;
      }
    }
    switch (action.toUpperCase()) {
      case 'CREATE':
        return Icons.upload_file_rounded;
      case 'DELETE':
        return Icons.delete_sweep_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Widget _buildActionChip(String action) {
    final color = _actionColor(action);
    return Text(
      action.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  String _formatDate(String raw) => pht.formatRelative(raw);

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].length > 1
        ? parts[0].substring(0, 2).toUpperCase()
        : parts[0].toUpperCase();
  }
}
