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
  final Set<int> _visitedIndices = {};
  Timer? _holdTimer;

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
      child: Scaffold(
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
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 48, bottom: 24, left: 16, right: 16),
                decoration: const BoxDecoration(color: AppColors.primaryGreen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onLongPressStart: (_) {
                            _holdTimer = Timer(const Duration(seconds: 3), () {
                              _showCapstoneMembers(context);
                            });
                          },
                          onLongPressEnd: (_) => _holdTimer?.cancel(),
                          onLongPressCancel: () => _holdTimer?.cancel(),
                          child: const CircleAvatar(
                            backgroundColor: Colors.transparent,
                            radius: 24,
                            backgroundImage: AssetImage('assets/images/logo.png'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('TIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
                              Text('Record Management System', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      ref.watch(authProvider).value?.fullName ?? 'Unknown User', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    Text('Role: ${widget.userRole.toUpperCase()}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (allowedPrimary.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('MAIN', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      ...allowedPrimary.map((tab) => _buildDrawerItem(tab, currentIndex, tabs)),
                    ],
                    if (allowedSecondary.isNotEmpty) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('OTHER', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      ...allowedSecondary.map((tab) => _buildDrawerItem(tab, currentIndex, tabs)),
                    ],
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: AppColors.error),
                title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  showLogoutConfirmationDialog(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        body: IndexedStack(
          index: currentIndex,
          children: tabs.asMap().entries.map((entry) {
            return _visitedIndices.contains(entry.key)
                ? entry.value['screen'] as Widget
                : const SizedBox.shrink();
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(Map<String, dynamic> tab, int currentIndex, List<Map<String, dynamic>> allTabs) {
    final label = tab['label'] as String;
    final icon = tab['icon'] as IconData;
    final index = allTabs.indexWhere((t) => t['label'] == label);
    final isSelected = index == currentIndex;

    return Container(
      decoration: BoxDecoration(
        border: isSelected
            ? const Border(
                right: BorderSide(
                  color: AppColors.primaryGreen,
                  width: 4.0,
                ),
              )
            : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primaryGreen : Colors.grey.shade800),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade800,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.primaryGreen.withOpacity(0.1),
        onTap: () {
          Navigator.pop(context); // Close drawer
          _onNavTapped(label);
        },
      ),
    );
  }
}