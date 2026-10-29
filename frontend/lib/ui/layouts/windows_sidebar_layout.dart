import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/students/students_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/archives/archives_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/audit_trail/audit_trail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../providers/dashboard_provider.dart';
import '../providers/student_provider.dart' hide academicYearsProvider;
import '../providers/document_provider.dart';
import '../providers/archives_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/users_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/setup_provider.dart';
import '../providers/system_settings_provider.dart';
import '../shared/dialogs/logout_dialog.dart';
import '../shared/widgets/abstract_background.dart';
import '../providers/navigation_provider.dart';
import '../providers/connected_users_provider.dart';
import '../shared/widgets/server_connection_pill.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import '../screens/capstone_members/capstone_members_screen.dart';
import '../screens/documentation/documentation_screen.dart';
import '../shared/dialogs/disconnected_dialog.dart';

// Dummy screen for placeholders
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(title, style: const TextStyle(fontSize: 24)));
}

class WindowsSidebarLayout extends ConsumerStatefulWidget {
  final String userRole;
  final bool initialMinimized;

  const WindowsSidebarLayout({
    super.key,
    required this.userRole,
    this.initialMinimized = false,
  });

  @override
  ConsumerState<WindowsSidebarLayout> createState() =>
      _WindowsSidebarLayoutState();
}

class _WindowsSidebarLayoutState extends ConsumerState<WindowsSidebarLayout> {
  final Set<int> _visitedIndices = {};
  Timer? _holdTimer;
  Timer? _tabLoadingTimer;
  late bool _isMinimized;
  bool _isTabLoading = false;

  @override
  void initState() {
    super.initState();
    _isMinimized = widget.initialMinimized;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(heartbeatServiceProvider).onConnectionLost = () {
        if (mounted) {
          DisconnectedDialog.show(
            context,
            onReconnected: () {
              final activeTab = ref.read(activeTabProvider);
              _reloadTabContent(activeTab);
            },
          );
        }
      };
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _tabLoadingTimer?.cancel();
    super.dispose();
  }

  void _reloadTabContent(String label) {
    switch (label) {
      case 'Dashboard':
        ref.invalidate(dashboardDataProvider);
        break;
      case 'Students':
        ref.read(studentViewTabProvider.notifier).state = StudentViewTab.enrolled;
        ref.read(studentEnrolledSearchProvider.notifier).state = '';
        ref.read(studentAllSearchProvider.notifier).state = '';
        ref.read(studentQueryProvider.notifier).reset();
        ref.invalidate(studentPageProvider);
        break;
      case 'Documents':
        ref.invalidate(foldersProvider);
        ref.invalidate(documentPageProvider);
        break;
      case 'Archives':
        ref.invalidate(archivePageProvider);
        break;
      case 'Reports':
        ref.invalidate(reportStatsProvider);
        ref.invalidate(academicYearsProvider);
        ref.invalidate(yearlyComparisonProvider);
        break;
      case 'Users':
        ref.read(userSearchQueryProvider.notifier).state = '';
        ref.invalidate(usersProvider);
        break;
      case 'History':
      case 'Activity History':
        ref.invalidate(activityQueryProvider);
        ref.invalidate(recentActivitiesPageProvider);
        ref.invalidate(userHistoryQueryProvider);
        ref.invalidate(userHistoryPageProvider);
        break;
      case 'Settings':
        ref.invalidate(academicYearsListProvider);
        ref.invalidate(sectionsListProvider);
        ref.invalidate(gradeLevelsListProvider);
        ref.invalidate(systemSettingsProvider);
        ref.invalidate(profileProvider);
        ref.invalidate(requirementsSettingsProvider);
        break;
    }
  }

  void _showCapstoneMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CapstoneMembersScreen()),
    );
  }

  Widget _buildNavItem(
    Map<String, Object> tab,
    bool isSelected,
    bool isCategoryHeader, {
    bool isFirstItem = false,
  }) {
    final String? category = tab['category'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCategoryHeader && category != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isMinimized
                ? const SizedBox(width: double.infinity, height: 0)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isFirstItem) const SizedBox(height: 6),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isMinimized ? 0.0 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            bottom: 6,
                            top: 4,
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Tooltip(
            message: _isMinimized ? tab['label'] as String : '',
            waitDuration: const Duration(milliseconds: 500),
            child: Material(
              color: isSelected
                  ? AppColors.primaryGreen.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                hoverColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.05),
                onTap: () {
                  setState(() {
                    _isTabLoading = true;
                  });

                  _tabLoadingTimer?.cancel();
                  _tabLoadingTimer = Timer(
                    const Duration(milliseconds: 100),
                    () {
                      if (mounted) {
                        setState(() {
                          _isTabLoading = false;
                        });
                      }
                    },
                  );

                  ref
                      .read(activeTabProvider.notifier)
                      .setTab(tab['label'] as String);
                  _reloadTabContent(tab['label'] as String);
                },
                child: SizedBox(
                  height: 42,
                  child: _isMinimized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isSelected)
                              Positioned(
                                left: 0,
                                child: Container(
                                  width: 3.5,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            Center(
                              child: Icon(
                                (isSelected
                                        ? tab['activeIcon'] ?? tab['icon']
                                        : tab['icon'])
                                    as IconData,
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                size: 22,
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 9.0,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (isSelected
                                        ? tab['activeIcon'] ?? tab['icon']
                                        : tab['icon'])
                                    as IconData,
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  tab['label'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTabs = [
      {
        'category': 'MAIN',
        'label': 'Dashboard',
        'icon': Icons.dashboard_outlined,
        'activeIcon': Icons.dashboard,
        'screen': const DashboardScreen(),
        'roles': ['admin', 'teacher'],
      },
      {
        'category': 'MAIN',
        'label': 'Students',
        'icon': Icons.people_outline,
        'activeIcon': Icons.people,
        'screen': StudentsScreen(userRole: widget.userRole),
        'roles': ['admin', 'teacher'],
      },
      {
        'category': 'MAIN',
        'label': 'Documents',
        'icon': Icons.folder_outlined,
        'activeIcon': Icons.folder,
        'screen': DocumentsScreen(userRole: widget.userRole),
        'roles': ['admin', 'teacher'],
      },
      {
        'category': 'MAIN',
        'label': 'Archives',
        'icon': Icons.archive_outlined,
        'activeIcon': Icons.archive,
        'screen': ArchivesScreen(userRole: widget.userRole),
        'roles': ['admin'],
      },
      {
        'category': 'ADMINISTRATION',
        'label': 'Reports',
        'icon': Icons.bar_chart,
        'activeIcon': Icons.bar_chart,
        'screen': ReportsScreen(userRole: widget.userRole),
        'roles': ['admin'],
      },
      {
        'category': 'ADMINISTRATION',
        'label': 'Users',
        'icon': Icons.manage_accounts_outlined,
        'activeIcon': Icons.manage_accounts,
        'screen': const UsersScreen(),
        'roles': ['admin'],
      },
      {
        'category': 'ADMINISTRATION',
        'label': 'Activity History',
        'icon': Icons.manage_history_outlined,
        'activeIcon': Icons.manage_history_rounded,
        'screen': AuditTrailScreen(userRole: widget.userRole),
        'roles': ['admin'],
      },
      {
        'category': 'ADMINISTRATION',
        'label': 'Settings',
        'icon': Icons.settings_outlined,
        'activeIcon': Icons.settings,
        'screen': SettingsScreen(userRole: widget.userRole),
        'roles': ['admin', 'teacher'],
      },
    ];
    final tabs = allTabs
        .where(
          (tab) => (tab['roles'] as List<String>).contains(widget.userRole),
        )
        .toList();

    final activeTab = ref.watch(activeTabProvider);
    int currentIndex = tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard

    _visitedIndices.add(currentIndex);



    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (activeTab != 'Dashboard') {
          ref.read(activeTabProvider.notifier).setTab('Dashboard');
          _reloadTabContent('Dashboard');
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Confirm Exit'),
              ],
            ),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'EXIT',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            if (!kIsWeb &&
                (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
              SizedBox(
                height: 32,
                child: WindowCaption(
                  brightness: Brightness.dark,
                  backgroundColor: AppColors.primaryGreen,
                  title: const Text(
                    'TIS Record Management System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  // ==========================================
                  // WINDOWS SIDEBAR (Fixed Width: 260px)
                  // ==========================================
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    width: _isMinimized ? 72 : 260,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // ==========================================
                        // SIDEBAR HEADER: EXPAND BUTTON (MINIMIZED) OR LOGO + TITLE + COLLAPSE
                        // ==========================================
                        _isMinimized
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                ),
                                child: Center(
                                  child: Tooltip(
                                    message: 'Expand Sidebar',
                                    waitDuration:
                                        const Duration(milliseconds: 300),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        hoverColor: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.08),
                                        onTap: () {
                                          setState(() => _isMinimized = false);
                                        },
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.view_sidebar_outlined,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.8),
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onLongPressStart: (_) {
                                        _holdTimer = Timer(
                                          const Duration(seconds: 3),
                                          () {
                                            _showCapstoneMembers(context);
                                          },
                                        );
                                      },
                                      onLongPressEnd: (_) =>
                                          _holdTimer?.cancel(),
                                      onLongPressCancel: () =>
                                          _holdTimer?.cancel(),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.asset(
                                            'assets/images/logo.webp',
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'TIS RMS',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          letterSpacing: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Collapse Sidebar',
                                      waitDuration:
                                          const Duration(milliseconds: 300),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          hoverColor: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.08),
                                          onTap: () {
                                            setState(() => _isMinimized = true);
                                          },
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.view_sidebar_rounded,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.65),
                                              size: 21,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 6),

                        // Navigation Items: Single Unified Scrollable List
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: _isMinimized ? 12 : 12,
                              vertical: 4,
                            ),
                            itemCount: tabs.length,
                            itemBuilder: (context, index) {
                              final tab = tabs[index];
                              final isSelected =
                                  tab['label'] ==
                                  tabs[currentIndex]['label'];
                              final isCategoryHeader =
                                  index == 0 ||
                                  tabs[index - 1]['category'] !=
                                      tab['category'];
                              return _buildNavItem(
                                tab,
                                isSelected,
                                isCategoryHeader,
                                isFirstItem: index == 0,
                              );
                            },
                          ),
                        ),

                        // Persistent Server Connection Status Pill
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: _isMinimized ? 8 : 20,
                            vertical: 8,
                          ),
                          child: Center(
                            child: ServerConnectionPill(compact: _isMinimized),
                          ),
                        ),

                        // Bottom Section: User Profile & Logout
                        Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        _isMinimized
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                child: Center(
                                  child: Tooltip(
                                    message: ref
                                            .watch(authProvider)
                                            .value
                                            ?.fullName ??
                                        'User Profile',
                                    waitDuration:
                                        const Duration(milliseconds: 300),
                                    child: Builder(
                                      builder: (context) {
                                        final user =
                                            ref.watch(authProvider).value;
                                        final initials = user != null &&
                                                user.firstName.isNotEmpty &&
                                                user.lastName.isNotEmpty
                                            ? '${user.firstName[0]}${user.lastName[0]}'
                                                .toUpperCase()
                                            : 'SA';
                                        return CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final user =
                                            ref.watch(authProvider).value;
                                        final initials = user != null &&
                                                user.firstName.isNotEmpty &&
                                                user.lastName.isNotEmpty
                                            ? '${user.firstName[0]}${user.lastName[0]}'
                                                .toUpperCase()
                                            : 'SA';
                                        return CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            ref
                                                    .watch(authProvider)
                                                    .value
                                                    ?.fullName ??
                                                'Unknown User',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            widget.userRole.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.menu_book_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        size: 19,
                                      ),
                                      tooltip: 'User Guide & Documentation',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        DocumentationScreen.open(context);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.logout,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        size: 19,
                                      ),
                                      tooltip: 'Logout',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        showLogoutConfirmationDialog(context);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ),

                  // ==========================================
                  // MAIN CONTENT AREA
                  // ==========================================
                  Expanded(
                    child: AbstractBackground(
                      child: Stack(
                        children: [
                          IndexedStack(
                            index: currentIndex,
                            children: tabs.asMap().entries.map((entry) {
                              return _visitedIndices.contains(entry.key)
                                  ? entry.value['screen'] as Widget
                                  : const SizedBox.shrink();
                            }).toList(),
                          ),
                          if (_isTabLoading)
                            Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: double.infinity,
                              height: double.infinity,
                              child: const _PageSkeletonLoader(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageSkeletonLoader extends StatefulWidget {
  const _PageSkeletonLoader();

  @override
  State<_PageSkeletonLoader> createState() => _PageSkeletonLoaderState();
}

class _PageSkeletonLoaderState extends State<_PageSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final secondaryColor = isDark ? Colors.grey.shade900 : Colors.grey.shade200;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 180,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: 5,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, _) => Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
