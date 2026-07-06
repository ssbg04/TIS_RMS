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
import '../providers/navigation_provider.dart';

// Dummy screen for placeholders
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Center(child: Text(title, style: const TextStyle(fontSize: 24)));
}

class AndroidBottomNavLayout extends ConsumerStatefulWidget {
  final String userRole;

  const AndroidBottomNavLayout({super.key, required this.userRole});

  @override
  ConsumerState<AndroidBottomNavLayout> createState() => _AndroidBottomNavLayoutState();
}

class _AndroidBottomNavLayoutState extends ConsumerState<AndroidBottomNavLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _visitedIndices = {};
  Timer? _holdTimer;
  Timer? _tabLoadingTimer;
  bool _isTabLoading = false;

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
    _tabLoadingTimer = Timer(const Duration(milliseconds: 500), () {
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
    const members = [
      'Alibutod, Rhina Mhay C.',
      'Antonio, Clara Maris B.',
      'De Vera, Ermhar A.',
      'Ellio, James Young G.',
      'Garcia, Cris Charles V.',
      'Pasigan, Chinee R.',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.groups_rounded, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('Capstone Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: members
              .map((name) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.primaryGreen),
                        const SizedBox(width: 10),
                        Text(name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryTabsConfig = [
      {'label': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard, 'screen': const DashboardScreen(), 'roles': ['admin', 'teacher']},
      {'label': 'Students', 'icon': Icons.people_outline, 'activeIcon': Icons.people, 'screen': StudentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'label': 'Documents', 'icon': Icons.folder_outlined, 'activeIcon': Icons.folder, 'screen': DocumentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'label': 'Archives', 'icon': Icons.archive_outlined, 'activeIcon': Icons.archive, 'screen': ArchivesScreen(userRole: widget.userRole), 'roles': ['admin']},
    ];
    final secondaryTabsConfig = [
      {'label': 'Reports', 'icon': Icons.bar_chart, 'activeIcon': Icons.bar_chart, 'screen': ReportsScreen(userRole: widget.userRole), 'roles': ['admin']},
      {'label': 'Users', 'icon': Icons.manage_accounts_outlined, 'activeIcon': Icons.manage_accounts, 'screen': const UsersScreen(), 'roles': ['admin']},
      {'label': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings, 'screen': SettingsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
    ];
    final allowedPrimary = primaryTabsConfig.where((t) => (t['roles'] as List<String>).contains(widget.userRole)).toList();
    final allowedSecondary = secondaryTabsConfig.where((t) => (t['roles'] as List<String>).contains(widget.userRole)).toList();
    final tabs = [...allowedPrimary, ...allowedSecondary];

    final activeTab = ref.watch(activeTabProvider);

    int currentIndex = tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('EXIT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            tabs[currentIndex]['label'] as String, 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          elevation: 0,
        ),
        drawer: Drawer(
          width: 260, // Minimized width
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 16, bottom: 16, left: 24, right: 16),
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
                            )
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
                    const Text(
                      'TIS RMS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2, color: Colors.black87),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          if (allowedPrimary.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(28, 16, 16, 8),
                              child: Text('OVERVIEW', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                            ),
                            ...allowedPrimary.map((tab) => _buildDrawerItem(tab, currentIndex, tabs)),
                          ],
                        ],
                      ),
                    ),
                    if (allowedSecondary.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(28, 16, 16, 8),
                            child: Text('ACCOUNT', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                          ),
                          ...allowedSecondary.map((tab) => _buildDrawerItem(tab, currentIndex, tabs)),
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
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryGreen,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.watch(authProvider).value?.fullName ?? 'Unknown User',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.userRole.toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.black54),
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
      body: Stack(
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
                color: AppColors.pageBackground,
                width: double.infinity,
                height: double.infinity,
                child: const _PageSkeletonLoader(),
              ),
          ],
        ),
       ),
      ),
    );
  }

  Widget _buildDrawerItem(Map<String, dynamic> tab, int currentIndex, List<Map<String, dynamic>> allTabs) {
    final label = tab['label'] as String;
    final icon = tab['icon'] as IconData;
    final activeIcon = tab['activeIcon'] as IconData? ?? icon;
    final index = allTabs.indexWhere((t) => t['label'] == label);
    final isSelected = index == currentIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Material(
        color: isSelected ? AppColors.primaryGreen.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.pop(context); // Close drawer
            _onNavTapped(label);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppColors.primaryGreen : Colors.grey.shade600,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryGreen : Colors.grey.shade700,
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

class _PageSkeletonLoaderState extends State<_PageSkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)))),
                const SizedBox(width: 16),
                Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)))),
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
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}