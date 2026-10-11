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
    required bool isDark,
    bool isFirstItem = false,
  }) {
    final String? category = tab['category'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCategoryHeader && category != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isMinimized
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isFirstItem) const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 14,
                          bottom: 6,
                          top: 4,
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
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
                  ? (isDark
                      ? AppColors.primaryGreen.withValues(alpha: 0.16)
                      : AppColors.primaryGreen.withValues(alpha: 0.10))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                hoverColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
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
                  height: 38,
                  child: Row(
                    children: [
                      // WinUI 3 Fluent Active Indicator Pill
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 3,
                          height: isSelected ? 16 : 0,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGreen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(width: _isMinimized ? 20 : 10),
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
                                .withValues(alpha: 0.7),
                        size: 19,
                      ),
                      if (!_isMinimized) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tab['label'] as String,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF1B1B1B))
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF202020)
                      : const Color(0xFFF3F3F3),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFE5E5E5),
                      width: 1,
                    ),
                  ),
                ),
                child: WindowCaption(
                  brightness:
                      isDark ? Brightness.dark : Brightness.light,
                  backgroundColor: isDark
                      ? const Color(0xFF202020)
                      : const Color(0xFFF3F3F3),
                  title: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.asset(
                          'assets/images/logo.webp',
                          width: 16,
                          height: 16,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TIS Record Management System',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF1F1F1F),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: _isMinimized ? 80 : 260,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF202020)
                          : const Color(0xFFF3F3F3),
                      border: Border(
                        right: BorderSide(
                          color: isDark
                              ? const Color(0xFF2D2D2D)
                              : const Color(0xFFE5E5E5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: 260,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                12,
                                10,
                              ),
                              child: Row(
                                children: [
                                  Tooltip(
                                    message: _isMinimized
                                        ? 'Expand Sidebar'
                                        : 'TIS RMS',
                                    child: GestureDetector(
                                      onTap: () {
                                        if (_isMinimized) {
                                          setState(() => _isMinimized = false);
                                        }
                                      },
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
                                              BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.asset(
                                            'assets/images/logo.webp',
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      opacity: _isMinimized ? 0.0 : 1.0,
                                      child: Text(
                                        'TIS RMS',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          letterSpacing: 0.9,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  AnimatedOpacity(
                                    duration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    opacity: _isMinimized ? 0.0 : 1.0,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.menu,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.65),
                                        size: 20,
                                      ),
                                      hoverColor: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.05),
                                      style: IconButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () {
                                        if (!_isMinimized) {
                                          setState(() => _isMinimized = true);
                                        }
                                      },
                                      tooltip: 'Collapse Sidebar',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Navigation Items: Single Unified Scrollable List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
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
                                isDark: isDark,
                                isFirstItem: index == 0,
                              );
                            },
                          ),
                        ),

                        // Persistent Server Connection Status Pill
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: _isMinimized ? 12 : 20,
                            vertical: 8,
                          ),
                          child: Center(
                            child: ServerConnectionPill(compact: _isMinimized),
                          ),
                        ),

                        // Bottom Section: User Profile & Logout
                        Divider(
                          height: 1,
                          color: isDark
                              ? const Color(0xFF2D2D2D)
                              : const Color(0xFFE5E5E5),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 8.0,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: _isMinimized ? 4.0 : 8.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              width: _isMinimized ? 56 : 228,
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_isMinimized) {
                                        setState(() => _isMinimized = false);
                                      }
                                    },
                                    child: Builder(
                                      builder: (context) {
                                        final user = ref
                                            .watch(authProvider)
                                            .value;
                                        final initials =
                                            user != null &&
                                                user.firstName.isNotEmpty &&
                                                user.lastName.isNotEmpty
                                            ? '${user.firstName[0]}${user.lastName[0]}'
                                                  .toUpperCase()
                                            : 'SA';
                                        return CircleAvatar(
                                          radius: 17,
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
                                  if (!_isMinimized) ...[
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
                                              fontWeight: FontWeight.w600,
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
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.55),
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
                                            .withValues(alpha: 0.65),
                                        size: 18,
                                      ),
                                      tooltip: 'User Guide & Documentation',
                                      hoverColor: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.05),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                        minHeight: 30,
                                      ),
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
                                            .withValues(alpha: 0.65),
                                        size: 18,
                                      ),
                                      tooltip: 'Logout',
                                      hoverColor: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : Colors.black.withValues(alpha: 0.05),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                        minHeight: 30,
                                      ),
                                      onPressed: () {
                                        showLogoutConfirmationDialog(context);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
