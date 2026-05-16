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

class WindowsSidebarLayout extends ConsumerStatefulWidget {
  final String userRole;

  const WindowsSidebarLayout({super.key, required this.userRole});

  @override
  ConsumerState<WindowsSidebarLayout> createState() => _WindowsSidebarLayoutState();
}

class _WindowsSidebarLayoutState extends ConsumerState<WindowsSidebarLayout> {
  int _currentIndex = 0;

  void _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTabs = [
      {'label': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard, 'screen': const DashboardScreen(), 'roles': ['super_admin', 'admin', 'teacher']},
      {'label': 'Students', 'icon': Icons.people_outline, 'activeIcon': Icons.people, 'screen': StudentsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin', 'teacher']},
      {'label': 'Documents', 'icon': Icons.folder_outlined, 'activeIcon': Icons.folder, 'screen': DocumentsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin', 'teacher']},
      {'label': 'Archives', 'icon': Icons.archive_outlined, 'activeIcon': Icons.archive, 'screen': ArchivesScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin']},
      {'label': 'Reports', 'icon': Icons.bar_chart_outlined, 'activeIcon': Icons.bar_chart, 'screen': ReportsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin']},
      {'label': 'Users', 'icon': Icons.manage_accounts_outlined, 'activeIcon': Icons.manage_accounts, 'screen': const UsersScreen(), 'roles': ['super_admin']},
      {'label': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings, 'screen': SettingsScreen(userRole: widget.userRole), 'roles': ['super_admin', 'admin', 'teacher']},
    ];
    final tabs = allTabs.where((tab) => (tab['roles'] as List<String>).contains(widget.userRole)).toList();

    return Scaffold(
      backgroundColor: AppColors.pageBackground, // Solid Off-white beige
      body: Row(
        children: [
          // ==========================================
          // WINDOWS SIDEBAR (Fixed Width: 260px)
          // ==========================================
          Container(
            width: 260,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.darkGreen, AppColors.primaryGreen],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(3, 0),
                )
              ],
            ),
            child: Column(
              children: [
                // Branding Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.p32, 
                    horizontal: AppSizes.p24
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/images/logo.png', width: 42, height: 42),
                      const SizedBox(width: AppSizes.p12),
                      const Expanded(
                        child: Text(
                          'TIS RMS',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Navigation Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isSelected = _currentIndex == index;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.p8),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                            ),
                            selected: isSelected,
                            selectedTileColor: Colors.white.withOpacity(0.15), // Soft highlight
                            leading: Icon(
                              (isSelected ? tab['activeIcon'] ?? tab['icon'] : tab['icon']) as IconData,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                            title: Text(
                              tab['label'] as String,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                            onTap: () => setState(() => _currentIndex = index),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Section: Logout
                Divider(height: 1, color: Colors.white24),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    ),
                    leading: Icon(Icons.logout, color: Colors.redAccent.shade100),
                    title: Text(
                      'Logout',
                      style: TextStyle(color: Colors.redAccent.shade100, fontWeight: FontWeight.bold),
                    ),
                    hoverColor: Colors.white.withOpacity(0.05),
                    onTap: () {
                      _handleLogout();
                    },
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // MAIN CONTENT AREA
          // ==========================================
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs.map((t) => t['screen'] as Widget).toList(),
            ),
          ),
        ],
      ),
    );
  }
}