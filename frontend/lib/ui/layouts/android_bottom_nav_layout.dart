import 'package:flutter/material.dart';
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
import '../providers/auth_provider.dart';             // Import your Auth Provider
import '../screens/login/login_screen.dart';             // Import the Login Screen

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
  int _selectedBottomNavIndex = 0;
  int _activeStackIndex = 0;

  void _onNavTapped(int index, List<Map<String, dynamic>> allowedPrimary, List<Map<String, dynamic>> allowedSecondary) {
    if (index < allowedPrimary.length) {
      setState(() {
        _selectedBottomNavIndex = index;
        _activeStackIndex = index;
      });
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
      builder: (context) {
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
                      Navigator.pop(context); 
                      setState(() {
                        _selectedBottomNavIndex = allowedPrimary.length; 
                        _activeStackIndex = allowedPrimary.length + secondaryIndex;
                      });
                    },
                  );
                }),
                const Divider(),
                // Logout Option in the More Menu
                ListTile(
                  leading: const Padding(
                    padding: EdgeInsets.all(AppSizes.p8),
                    child: Icon(Icons.logout, color: AppColors.error),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                  onTap: () {
                    _handleLogout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleLogout() async {
    // Close the Bottom Sheet modal first
    Navigator.pop(context);

    // Clear state
    await ref.read(authProvider.notifier).logout();

    if (!mounted) return;

    // Route to Login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryTabsConfig = [
      {'label': 'Dashboard', 'icon': Icons.dashboard, 'screen': const DashboardScreen(), 'roles': ['super_admin', 'admin', 'teacher']},
      {'label': 'Students', 'icon': Icons.people_outline, 'screen': StudentsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin', 'teacher']},
      {'label': 'Documents', 'icon': Icons.folder_outlined, 'screen': DocumentsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin', 'teacher']},
      {'label': 'Archives', 'icon': Icons.archive_outlined, 'screen': ArchivesScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin']},
    ];
    final secondaryTabsConfig = [
      {'label': 'Reports', 'icon': Icons.bar_chart_outlined, 'screen': ReportsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin']},
      {'label': 'Users', 'icon': Icons.manage_accounts_outlined, 'screen': const UsersScreen(), 'roles': ['super_admin']},
      {'label': 'Settings', 'icon': Icons.settings_outlined, 'screen': SettingsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin', 'teacher']},
    ];
    final allowedPrimary = primaryTabsConfig.where((t) => (t['roles'] as List<String>).contains(widget.userRole)).toList();
    final allowedSecondary = secondaryTabsConfig.where((t) => (t['roles'] as List<String>).contains(widget.userRole)).toList();
    final allAllowedTabs = [...allowedPrimary, ...allowedSecondary];

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

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: IndexedStack(
        index: _activeStackIndex,
        children: allAllowedTabs.map((t) => t['screen'] as Widget).toList(),
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
          currentIndex: _selectedBottomNavIndex,
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
    );
  }
}