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
  final Set<int> _visitedIndices = {};

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

  void _onNavTapped(int index, List<Map<String, dynamic>> allowedPrimary, List<Map<String, dynamic>> allowedSecondary) {
    if (index < allowedPrimary.length) {
      final label = allowedPrimary[index]['label'] as String;
      
      // ✅ NEW: Update global state instead of local setState
      ref.read(activeTabProvider.notifier).setTab(label);
      _reloadTabContent(label);
    } else {
      _showMoreBottomSheet(allowedPrimary, allowedSecondary);
    }
  }

  void _showMoreBottomSheet(List<Map<String, dynamic>> allowedPrimary, List<Map<String, dynamic>> allowedSecondary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLarge)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.p12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSizes.p16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  ),
                ),
                // Build Secondary Tabs
                ...allowedSecondary.asMap().entries.map((entry) {
                  int secondaryIndex = entry.key;
                  var tab = entry.value;
                  
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(AppSizes.p8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      ),
                      child: Icon(tab['icon'] as IconData, color: AppColors.primaryGreen),
                    ),
                    title: Text(
                      tab['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () {
                      Navigator.pop(sheetContext); 
                      final label = tab['label'] as String;
                      // ✅ NEW: Update global state when a "More" option is clicked
                      ref.read(activeTabProvider.notifier).setTab(label);
                      _reloadTabContent(label);
                    },
                  );
                }),
                const Divider(),
                // Logout Option in the More Menu
                ListTile(
                  leading: const Padding(
                    padding: EdgeInsets.all(AppSizes.p8),
                    child: Icon(Icons.exit_to_app, color: AppColors.error),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                  onTap: () {
                    // DO NOT pop the bottom sheet here. 
                    // Just show the dialog directly!
                    showLogoutConfirmationDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryTabsConfig = [
      {'label': 'Dashboard', 'icon': Icons.dashboard, 'screen': const DashboardScreen(), 'roles': ['admin', 'teacher']},
      {'label': 'Students', 'icon': Icons.people, 'screen': StudentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'label': 'Documents', 'icon': Icons.folder, 'screen': DocumentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'label': 'Archives', 'icon': Icons.archive, 'screen': ArchivesScreen(userRole: widget.userRole), 'roles': ['admin']},
    ];
    final secondaryTabsConfig = [
      {'label': 'Reports', 'icon': Icons.bar_chart, 'screen': ReportsScreen(userRole: widget.userRole), 'roles': ['admin']},
      {'label': 'Users', 'icon': Icons.manage_accounts, 'screen': const UsersScreen(), 'roles': ['admin']},
      {'label': 'Settings', 'icon': Icons.settings, 'screen': SettingsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
    ];
    final allowedPrimary = primaryTabsConfig.where((t) => (t['roles'] as List<String>).contains(widget.userRole)).toList();
    final allowedSecondary = secondaryTabsConfig.where((t) => (t['roles'] as List<String>).contains(widget.userRole)).toList();
    final tabs = [...allowedPrimary, ...allowedSecondary];

    final activeTab = ref.watch(activeTabProvider);

    int currentIndex = tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard

    _visitedIndices.add(currentIndex);

    int selectedBottomNavIndex = allowedPrimary.indexWhere((t) => t['label'] == activeTab);
    if (selectedBottomNavIndex == -1) {
      // If the active tab is NOT in the primary list (e.g., Settings), highlight the "More" tab
      selectedBottomNavIndex = allowedPrimary.length;
    }

    List<BottomNavigationBarItem> bottomNavItems = allowedPrimary.map((tab) {
      return BottomNavigationBarItem(
        icon: Icon(tab['icon'] as IconData),
        label: tab['label'] as String,
      );
    }).toList();

    if (allowedSecondary.isNotEmpty) {
      bottomNavItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
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
        backgroundColor: AppColors.pageBackground,
        body: IndexedStack(
          index: currentIndex,
          children: tabs.asMap().entries.map((entry) {
            return _visitedIndices.contains(entry.key)
                ? entry.value['screen'] as Widget
                : const SizedBox.shrink();
          }).toList(),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: selectedBottomNavIndex,
            onTap: (i) => _onNavTapped(i, allowedPrimary, allowedSecondary),
            backgroundColor: AppColors.primaryGreen,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            items: bottomNavItems,
          ),
        ),
      ),
    );
  }
}