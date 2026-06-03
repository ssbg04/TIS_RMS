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

class WindowsSidebarLayout extends ConsumerStatefulWidget {
  final String userRole;

  const WindowsSidebarLayout({super.key, required this.userRole});

  @override
  ConsumerState<WindowsSidebarLayout> createState() => _WindowsSidebarLayoutState();
}

class _WindowsSidebarLayoutState extends ConsumerState<WindowsSidebarLayout> {
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

  @override
  Widget build(BuildContext context) {
    final allTabs = [
      {'label': 'Dashboard', 'icon': Icons.dashboard, 'activeIcon': Icons.dashboard, 'screen': const DashboardScreen(), 'roles': ['admin', 'teacher']},
      {'label': 'Students', 'icon': Icons.people, 'activeIcon': Icons.people, 'screen': StudentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'label': 'Documents', 'icon': Icons.folder, 'activeIcon': Icons.folder, 'screen': DocumentsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
      {'label': 'Archives', 'icon': Icons.archive, 'activeIcon': Icons.archive, 'screen': ArchivesScreen(userRole: widget.userRole), 'roles': ['admin']},
      {'label': 'Reports', 'icon': Icons.bar_chart, 'activeIcon': Icons.bar_chart, 'screen': ReportsScreen(userRole: widget.userRole), 'roles': ['admin']},
      {'label': 'Users', 'icon': Icons.manage_accounts, 'activeIcon': Icons.manage_accounts, 'screen': const UsersScreen(), 'roles': ['admin']},
      {'label': 'Settings', 'icon': Icons.settings, 'activeIcon': Icons.settings, 'screen': SettingsScreen(userRole: widget.userRole), 'roles': ['admin', 'teacher']},
    ];
    final tabs = allTabs.where((tab) => (tab['roles'] as List<String>).contains(widget.userRole)).toList();

    final activeTab = ref.watch(activeTabProvider);
    int currentIndex = tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard
    
    _visitedIndices.add(currentIndex);

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
                        final isSelected = currentIndex == index;
  
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
                              onTap: () {
                                ref.read(activeTabProvider.notifier).setTab(tab['label'] as String);
  
                                _reloadTabContent(tab['label'] as String);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
  
                  // Bottom Section: Logout
                  Divider(height: 1, color: Colors.white24),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      leading: Icon(Icons.exit_to_app, color: Colors.redAccent.shade100), 
                      title: Text(
                        'Logout',
                        style: TextStyle(color: Colors.redAccent.shade100, fontWeight: FontWeight.bold),
                      ),
                      hoverColor: Colors.white.withOpacity(0.05),
                      onTap: () {
                        // Use the shared module! Pass the context.
                        showLogoutConfirmationDialog(context);
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
                index: currentIndex,
                children: tabs.asMap().entries.map((entry) {
                  return _visitedIndices.contains(entry.key)
                      ? entry.value['screen'] as Widget
                      : const SizedBox.shrink();
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}