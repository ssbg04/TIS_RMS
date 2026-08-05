import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/students/students_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/archives/archives_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/users/users_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../providers/dashboard_provider.dart';
import '../providers/student_provider.dart' hide academicYearsProvider;
import '../providers/document_provider.dart';
import '../providers/archives_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../shared/dialogs/logout_dialog.dart';
import '../shared/widgets/abstract_background.dart';
import '../providers/navigation_provider.dart';
import '../screens/capstone_members/capstone_members_screen.dart';

// Dummy screen for placeholders
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(title, style: const TextStyle(fontSize: 24)));
}

class AndroidBottomNavLayout extends ConsumerStatefulWidget {
  final String userRole;

  const AndroidBottomNavLayout({super.key, required this.userRole});

  @override
  ConsumerState<AndroidBottomNavLayout> createState() =>
      _AndroidBottomNavLayoutState();
}

class _AndroidBottomNavLayoutState extends ConsumerState<AndroidBottomNavLayout>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _visitedIndices = {};
  Timer? _holdTimer;
  Timer? _tabLoadingTimer;
  bool _isTabLoading = false;

  TabController? _tabController;
  List<Map<String, dynamic>> _tabs = [];
  List<Map<String, dynamic>> _allowedPrimary = [];
  List<Map<String, dynamic>> _allowedSecondary = [];

  @override
  void initState() {
    super.initState();
    _initTabs();
  }

  void _initTabs() {
    final primaryTabsConfig = [
      {
        'label': 'Dashboard',
        'icon': Icons.dashboard_outlined,
        'activeIcon': Icons.dashboard,
        'screen': const DashboardScreen(),
        'roles': ['admin', 'teacher'],
      },
      {
        'label': 'Students',
        'icon': Icons.people_outline,
        'activeIcon': Icons.people,
        'screen': StudentsScreen(userRole: widget.userRole),
        'roles': ['admin', 'teacher'],
      },
      {
        'label': 'Documents',
        'icon': Icons.folder_outlined,
        'activeIcon': Icons.folder,
        'screen': DocumentsScreen(userRole: widget.userRole),
        'roles': ['admin', 'teacher'],
      },
      {
        'label': 'Archives',
        'icon': Icons.archive_outlined,
        'activeIcon': Icons.archive,
        'screen': ArchivesScreen(userRole: widget.userRole),
        'roles': ['admin'],
      },
    ];
    final secondaryTabsConfig = [
      {
        'label': 'Reports',
        'icon': Icons.bar_chart,
        'activeIcon': Icons.bar_chart,
        'screen': ReportsScreen(userRole: widget.userRole),
        'roles': ['admin'],
      },
      {
        'label': 'Users',
        'icon': Icons.manage_accounts_outlined,
        'activeIcon': Icons.manage_accounts,
        'screen': const UsersScreen(),
        'roles': ['admin'],
      },
      {
        'label': 'Settings',
        'icon': Icons.settings_outlined,
        'activeIcon': Icons.settings,
        'screen': SettingsScreen(userRole: widget.userRole),
        'roles': ['admin', 'teacher'],
      },
    ];
    _allowedPrimary = primaryTabsConfig
        .where((t) => (t['roles'] as List<String>).contains(widget.userRole))
        .toList();
    _allowedSecondary = secondaryTabsConfig
        .where((t) => (t['roles'] as List<String>).contains(widget.userRole))
        .toList();
    _tabs = [..._allowedPrimary, ..._allowedSecondary];

    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController!.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController!.indexIsChanging) return;
    final newLabel = _tabs[_tabController!.index]['label'] as String;
    if (ref.read(activeTabProvider) != newLabel) {
      ref.read(activeTabProvider.notifier).setTab(newLabel);
      _reloadTabContent(newLabel);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
        ref.invalidate(usersProvider);
        break;
    }
  }

  void _onNavTapped(String label) {
    setState(() {
      _isTabLoading = true;
    });

    _tabLoadingTimer?.cancel();
    _tabLoadingTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isTabLoading = false;
        });
      }
    });

    ref.read(activeTabProvider.notifier).setTab(label);
    _reloadTabContent(label);
  }

  void _showCapstoneMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CapstoneMembersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);

    int currentIndex = _tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard

    // if (_tabController != null && _tabController!.index != currentIndex) {
    //   _tabController!.animateTo(currentIndex);
    // }

    _visitedIndices.add(currentIndex);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (activeTab != 'Dashboard') {
          _onNavTapped('Dashboard');
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
      child: SafeArea(
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
            title: Text(
              activeTab,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          drawer: Drawer(
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            width: 280,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      top: 16,
                      bottom: 16,
                      left: 24,
                      right: 16,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onLongPressStart: (_) {
                            _holdTimer = Timer(const Duration(seconds: 2), () {
                              _showCapstoneMembers(context);
                            });
                          },
                          onLongPressEnd: (_) => _holdTimer?.cancel(),
                          onLongPressCancel: () => _holdTimer?.cancel(),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'TIS RMS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        const _DrawerCloseButton(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            children: [
                              if (_allowedPrimary.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'MENU',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Column(
                                    children: [
                                      ..._allowedPrimary.map(
                                        (tab) => _buildDrawerItem(
                                          tab,
                                          currentIndex,
                                          _tabs,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_allowedSecondary.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'SYSTEM',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Column(
                                  children: [
                                    ..._allowedSecondary.map(
                                      (tab) => _buildDrawerItem(
                                        tab,
                                        currentIndex,
                                        _tabs,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final user = ref.watch(authProvider).value;
                            final initials =
                                user != null &&
                                    user.firstName.isNotEmpty &&
                                    user.lastName.isNotEmpty
                                ? '${user.firstName[0]}${user.lastName[0]}'
                                      .toUpperCase()
                                : 'SA';
                            return CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primaryGreen,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.watch(authProvider).value?.fullName ??
                                    'Unknown User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.userRole.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.logout,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Close drawer first
                            showLogoutConfirmationDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: AbstractBackground(
            child: Stack(
              children: [
                IndexedStack(
                  index: currentIndex,
                  children: _tabs.asMap().entries.map((entry) {
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
      ),
    );
  }

  Widget _buildDrawerItem(
    Map<String, dynamic> tab,
    int currentIndex,
    List<Map<String, dynamic>> allTabs,
  ) {
    final label = tab['label'] as String;
    final icon = tab['icon'] as IconData;
    final activeIcon = tab['activeIcon'] as IconData? ?? icon;
    final index = allTabs.indexWhere((t) => t['label'] == label);
    final isSelected = index == currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Material(
        color: isSelected
            ? AppColors.primaryGreen.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.pop(context); // Close drawer
            _onNavTapped(label);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : (isDark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) : Colors.grey.shade600),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : (isDark ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7) : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
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
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, __) => Container(
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

class _DrawerCloseButton extends StatefulWidget {
  const _DrawerCloseButton();

  @override
  State<_DrawerCloseButton> createState() => _DrawerCloseButtonState();
}

class _DrawerCloseButtonState extends State<_DrawerCloseButton> {
  bool _useArrow = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _useArrow = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          );
        },
        child: Icon(
          _useArrow ? Icons.arrow_back : Icons.menu,
          key: ValueKey(_useArrow),
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
        ),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }
}
