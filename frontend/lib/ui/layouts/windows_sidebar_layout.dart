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

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

// Dummy screen for placeholders
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Center(child: Text(title, style: const TextStyle(fontSize: 24)));
}

class WindowsSidebarLayout extends ConsumerStatefulWidget {
  final String userRole;

  const WindowsSidebarLayout({super.key, required this.userRole});

  @override
  ConsumerState<WindowsSidebarLayout> createState() => _WindowsSidebarLayoutState();
}

class _WindowsSidebarLayoutState extends ConsumerState<WindowsSidebarLayout> {
  final Set<int> _visitedIndices = {};
  Timer? _holdTimer;
  Timer? _tabLoadingTimer;
  bool _isMinimized = false;
  bool _isTabLoading = false;

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
        ref.invalidate(usersProvider);
        break;
    }
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

  Widget _buildNavItem(Map<String, Object> tab, bool isSelected, bool isCategoryHeader, {bool isFirstItem = false}) {
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
                      if (!isFirstItem) const SizedBox(height: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isMinimized ? 0.0 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
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
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Tooltip(
            message: _isMinimized ? tab['label'] as String : '',
            waitDuration: const Duration(milliseconds: 500),
            child: Material(
              color: isSelected ? AppColors.primaryGreen.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
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

                  ref.read(activeTabProvider.notifier).setTab(tab['label'] as String);
                  _reloadTabContent(tab['label'] as String);
                },
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: 236,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Icon(
                            (isSelected ? tab['activeIcon'] ?? tab['icon'] : tab['icon']) as IconData,
                            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade600,
                            size: 22,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isMinimized ? 0.0 : 1.0,
                              child: Text(
                                tab['label'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? AppColors.primaryGreen : Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTabs = [
      {'category': 'OVERVIEW', 'label': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard, 'screen': const DashboardScreen(), 'roles': ['admin', 'teacher']},
      {'category': 'OVERVIEW', 'label': 'Students', 'icon': Icons.people_outline, 'activeIcon': Icons.people, 'screen': StudentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'category': 'OVERVIEW', 'label': 'Documents', 'icon': Icons.folder_outlined, 'activeIcon': Icons.folder, 'screen': DocumentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'category': 'ACCOUNT', 'label': 'Archives', 'icon': Icons.archive_outlined, 'activeIcon': Icons.archive, 'screen': ArchivesScreen(userRole: widget.userRole), 'roles': ['admin']},
      {'category': 'ACCOUNT', 'label': 'Reports', 'icon': Icons.bar_chart, 'activeIcon': Icons.bar_chart, 'screen': ReportsScreen(userRole: widget.userRole), 'roles': ['admin']},
      {'category': 'ACCOUNT', 'label': 'Users', 'icon': Icons.manage_accounts_outlined, 'activeIcon': Icons.manage_accounts, 'screen': const UsersScreen(), 'roles': ['admin']},
      {'category': 'ACCOUNT', 'label': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings, 'screen': SettingsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
    ];
    final tabs = allTabs.where((tab) => (tab['roles'] as List<String>).contains(widget.userRole)).toList();

    final activeTab = ref.watch(activeTabProvider);
    int currentIndex = tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard
    
    _visitedIndices.add(currentIndex);

    final overviewTabs = tabs.where((t) => t['category'] == 'OVERVIEW').toList();
    final accountTabs = tabs.where((t) => t['category'] == 'ACCOUNT').toList();

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
      child: Scaffold(
        backgroundColor: AppColors.pageBackground, // Solid Off-white beige
        body: Column(
          children: [
            if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
              const SizedBox(
                height: 32,
                child: WindowCaption(
                  brightness: Brightness.dark,
                  backgroundColor: AppColors.primaryGreen,
                  title: Text('TIS RMS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  // ==========================================
                  // WINDOWS SIDEBAR (Fixed Width: 260px)
                  // ==========================================
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: _isMinimized ? 80 : 260,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(right: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: 260,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 16, 20),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_isMinimized) setState(() => _isMinimized = false);
                              },
                              onLongPressStart: (_) {
                                _holdTimer = Timer(const Duration(seconds: 3), () {
                                  _showCapstoneMembers(context);
                                });
                              },
                              onLongPressEnd: (_) => _holdTimer?.cancel(),
                              onLongPressCancel: () => _holdTimer?.cancel(),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset('assets/images/logo.png', width: 36, height: 36, fit: BoxFit.contain),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isMinimized ? 0.0 : 1.0,
                                child: const Text(
                                  'TIS RMS',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isMinimized ? 0.0 : 1.0,
                              child: IconButton(
                                icon: const Icon(Icons.menu, color: Colors.black54),
                                onPressed: () {
                                  if (!_isMinimized) setState(() => _isMinimized = true);
                                },
                                tooltip: 'Minimize Sidebar',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Navigation Items
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: overviewTabs.length,
                            itemBuilder: (context, index) {
                              final tab = overviewTabs[index];
                              final isSelected = tab['label'] == tabs[currentIndex]['label'];
                              final isCategoryHeader = index == 0 || overviewTabs[index - 1]['category'] != tab['category'];
                              return _buildNavItem(tab, isSelected, isCategoryHeader, isFirstItem: index == 0);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: accountTabs.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tab = entry.value;
                              final isSelected = tab['label'] == tabs[currentIndex]['label'];
                              final isCategoryHeader = index == 0 || accountTabs[index - 1]['category'] != tab['category'];
                              return _buildNavItem(tab, isSelected, isCategoryHeader, isFirstItem: false);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
  
                  // Bottom Section: User Profile & Logout
                  const Divider(height: 1, color: Colors.black12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: 260,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_isMinimized) setState(() => _isMinimized = false);
                              },
                              child: const CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryGreen,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isMinimized ? 0.0 : 1.0,
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
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isMinimized ? 0.0 : 1.0,
                              child: IconButton(
                                icon: const Icon(Icons.logout, color: Colors.black54),
                                tooltip: 'Logout',
                                onPressed: () {
                                  if (!_isMinimized) showLogoutConfirmationDialog(context);
                                },
                              ),
                            ),
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
                      color: AppColors.pageBackground,
                      width: double.infinity,
                      height: double.infinity,
                      child: const _PageSkeletonLoader(),
                    ),
                ],
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