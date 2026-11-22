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
import '../../core/services/biometric_auth_service.dart';

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

class _WindowsSidebarLayoutState extends ConsumerState<WindowsSidebarLayout>
    with SingleTickerProviderStateMixin {
  final Set<int> _visitedIndices = {};
  Timer? _holdTimer;
  late final AnimationController _pageTransitionController;
  late bool _isMinimized;
  bool _isExitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _isMinimized = widget.initialMinimized;
    _pageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
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

      final pendingBioUser = ref.read(pendingBiometricPromptUsernameProvider);
      if (pendingBioUser != null) {
        ref.read(pendingBiometricPromptUsernameProvider.notifier).state = null;
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            BiometricAuthService.promptEnableIfEligible(
              context,
              ref,
              pendingBioUser,
            );
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant WindowsSidebarLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMinimized != widget.initialMinimized) {
      setState(() => _isMinimized = widget.initialMinimized);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pageTransitionController.dispose();
    super.dispose();
  }

  void _selectTab(String label) {
    HapticFeedback.selectionClick();
    ref.read(activeTabProvider.notifier).setTab(label);
    _reloadTabContent(label);
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
    required bool showExpanded,
    bool isFirstItem = false,
  }) {
    final String label = tab['label'] as String;
    final String? category = tab['category'] as String?;
    final IconData icon = tab['icon'] as IconData;
    final IconData activeIcon = (tab['activeIcon'] as IconData?) ?? icon;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCategoryHeader && category != null && showExpanded)
          Padding(
            padding: EdgeInsets.only(
              left: 14,
              bottom: 4,
              top: isFirstItem ? 4 : 10,
            ),
            child: Text(
              category.toUpperCase(),
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.68),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Tooltip(
            message: showExpanded ? '' : label,
            waitDuration: const Duration(milliseconds: 450),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                hoverColor: onSurface.withValues(alpha: 0.05),
                onTap: () => _selectTab(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen
                            .withValues(alpha: isDark ? 0.16 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: showExpanded
                      ? Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: 3,
                              height: isSelected ? 18 : 0,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(width: isSelected ? 9 : 7),
                            Icon(
                              isSelected ? activeIcon : icon,
                              color: isSelected
                                  ? primaryColor
                                  : onSurface.withValues(alpha: 0.62),
                              size: 19,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? primaryColor
                                      : onSurface.withValues(alpha: 0.82),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                width: 3,
                                height: isSelected ? 18 : 0,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                isSelected ? activeIcon : icon,
                                color: isSelected
                                    ? primaryColor
                                    : onSurface.withValues(alpha: 0.62),
                                size: 21,
                              ),
                            ),
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
    final navTabs = tabs.where((t) => t['label'] != 'Settings').toList();

    ref.listen<String>(activeTabProvider, (prev, next) {
      if (prev != next) {
        _pageTransitionController.forward(from: 0.0);
      }
    });

    final activeTab = ref.watch(activeTabProvider);
    int currentIndex = tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard

    _visitedIndices.add(currentIndex);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If an editable text input has focus, unfocus it first before navigating
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus != null &&
            primaryFocus.hasFocus &&
            primaryFocus.context != null) {
          final isEditable = primaryFocus.context!.widget is EditableText ||
              primaryFocus.context!
                      .findAncestorWidgetOfExactType<EditableText>() !=
                  null;
          if (isEditable) {
            primaryFocus.unfocus();
            return;
          }
        }

        if (activeTab != 'Dashboard') {
          if (ref.read(tabBackRegistryProvider).tryHandle(activeTab)) {
            return;
          }
          _selectTab('Dashboard');
          return;
        }

        if (_isExitDialogOpen) return;
        _isExitDialogOpen = true;
        try {
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
        } finally {
          if (mounted) {
            _isExitDialogOpen = false;
          }
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
            setState(() => _isMinimized = !_isMinimized);
          },
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
                      'TIS RMS',
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
                    // Minimalist Collapsible Windows Sidebar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: _isMinimized ? 68 : 248,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showExpanded =
                              !_isMinimized && constraints.maxWidth >= 190;
                          return Column(
                            children: [
                              _buildSidebarHeader(context, showExpanded),
                              const SizedBox(height: 4),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  itemCount: navTabs.length,
                                  itemBuilder: (context, index) {
                                    final tab = navTabs[index];
                                    final isSelected =
                                        tab['label'] ==
                                        tabs[currentIndex]['label'];
                                    final isCategoryHeader =
                                        index == 0 ||
                                        navTabs[index - 1]['category'] !=
                                            tab['category'];
                                    return _buildNavItem(
                                      tab,
                                      isSelected,
                                      isCategoryHeader,
                                      showExpanded: showExpanded,
                                      isFirstItem: index == 0,
                                    );
                                  },
                                ),
                              ),
                              _buildSidebarFooter(
                                context,
                                showExpanded,
                                activeTab,
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // ==========================================
                    // MAIN CONTENT AREA
                    // ==========================================
                    Expanded(
                      child: AbstractBackground(
                        child: AnimatedBuilder(
                          animation: _pageTransitionController,
                          child: RepaintBoundary(
                            child: IndexedStack(
                              index: currentIndex,
                              children: tabs.asMap().entries.map((entry) {
                                return _visitedIndices.contains(entry.key)
                                    ? entry.value['screen'] as Widget
                                    : const SizedBox.shrink();
                              }).toList(),
                            ),
                          ),
                          builder: (context, stackChild) {
                            final t = _pageTransitionController.value;
                            final glide = Curves.easeOutCubic.transform(t);
                            final opacity = const Interval(
                              0.0,
                              0.85,
                              curve: Curves.easeOut,
                            ).transform(t);
                            return Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, 10.0 * (1.0 - glide)),
                                child: Transform.scale(
                                  scale: 0.99 + (0.01 * glide),
                                  child: stackChild,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, bool showExpanded) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (!showExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Tooltip(
            message: 'Expand Sidebar (Ctrl+B)',
            waitDuration: const Duration(milliseconds: 300),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                hoverColor: onSurface.withValues(alpha: 0.08),
                onTap: () => setState(() => _isMinimized = false),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    Icons.view_sidebar_outlined,
                    color: onSurface.withValues(alpha: 0.8),
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      child: Row(
        children: [
          GestureDetector(
            onLongPressStart: (_) {
              _holdTimer = Timer(const Duration(seconds: 3), () {
                _showCapstoneMembers(context);
              });
            },
            onLongPressEnd: (_) => _holdTimer?.cancel(),
            onLongPressCancel: () => _holdTimer?.cancel(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/images/logo.webp',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TIS RMS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: onSurface,
                letterSpacing: 0.9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: 'User Guide & Documentation',
            waitDuration: const Duration(milliseconds: 300),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                hoverColor: onSurface.withValues(alpha: 0.08),
                onTap: () => DocumentationScreen.open(context),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: onSurface.withValues(alpha: 0.62),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Tooltip(
            message: 'Collapse Sidebar (Ctrl+B)',
            waitDuration: const Duration(milliseconds: 300),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                hoverColor: onSurface.withValues(alpha: 0.08),
                onTap: () => setState(() => _isMinimized = true),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.view_sidebar_outlined,
                    color: onSurface.withValues(alpha: 0.65),
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(
    BuildContext context,
    bool showExpanded,
    String activeTab,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;
    final user = ref.watch(authProvider).valueOrNull;
    final fullName = user?.fullName ?? 'Unknown User';
    final initials =
        user != null && user.firstName.isNotEmpty && user.lastName.isNotEmpty
            ? '${user.firstName[0]}${user.lastName[0]}'.toUpperCase()
            : 'SA';
    final isSettingsActive = activeTab == 'Settings';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: Theme.of(context).dividerColor),
        if (showExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primaryGreen,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const ServerConnectionInline(),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Settings',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: isSettingsActive
                        ? AppColors.primaryGreen
                            .withValues(alpha: isDark ? 0.18 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: onSurface.withValues(alpha: 0.08),
                      onTap: () => _selectTab('Settings'),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          isSettingsActive
                              ? Icons.settings_rounded
                              : Icons.settings_outlined,
                          size: 18,
                          color: isSettingsActive
                              ? primaryColor
                              : onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Logout',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: onSurface.withValues(alpha: 0.08),
                      onTap: () => showLogoutConfirmationDialog(context),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Settings',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: isSettingsActive
                        ? AppColors.primaryGreen
                            .withValues(alpha: isDark ? 0.18 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: onSurface.withValues(alpha: 0.08),
                      onTap: () => _selectTab('Settings'),
                      child: SizedBox(
                        width: 44,
                        height: 38,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isSettingsActive)
                              Positioned(
                                left: 0,
                                child: Container(
                                  width: 3,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            Icon(
                              isSettingsActive
                                  ? Icons.settings_rounded
                                  : Icons.settings_outlined,
                              size: 20,
                              color: isSettingsActive
                                  ? primaryColor
                                  : onSurface.withValues(alpha: 0.62),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: 'User Guide & Documentation',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: onSurface.withValues(alpha: 0.08),
                      onTap: () => DocumentationScreen.open(context),
                      child: SizedBox(
                        width: 44,
                        height: 34,
                        child: Icon(
                          Icons.menu_book_outlined,
                          size: 18,
                          color: onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ServerStatusAvatar(
                  initials: initials,
                  tooltipName: fullName,
                  roleLabel: widget.userRole,
                  radius: 17,
                  showStatusDot: true,
                ),
                const SizedBox(height: 6),
                Tooltip(
                  message: 'Logout',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: onSurface.withValues(alpha: 0.08),
                      onTap: () => showLogoutConfirmationDialog(context),
                      child: SizedBox(
                        width: 44,
                        height: 34,
                        child: Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
