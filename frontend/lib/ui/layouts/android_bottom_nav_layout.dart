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
import '../screens/settings/teacher_management_screen.dart';
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
import '../screens/capstone_members/capstone_members_screen.dart';
import '../shared/dialogs/disconnected_dialog.dart';
import '../shared/inputs/app_search_bar.dart';
import '../shared/menus/profile_dropdown_menu.dart';
import '../shared/widgets/notification_icon_button.dart';
import '../screens/students/widgets/student_bulk_actions.dart';
import '../screens/documents/widgets/print_queue_modal.dart';
import '../screens/documents/widgets/upload_ocr_modal.dart';
import '../shared/widgets/server_connection_pill.dart';
import '../../core/services/biometric_auth_service.dart';

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
  final Set<int> _visitedIndices = {};
  Timer? _holdTimer;
  Timer? _drawerCloseTimer;
  bool _isDragging = false;
  bool _isExitDialogOpen = false;
  late final AnimationController _drawerController;
  late final AnimationController _pageTransitionController;

  List<Map<String, dynamic>> _tabs = [];
  List<Map<String, dynamic>> _allowedPrimary = [];
  List<Map<String, dynamic>> _allowedSecondary = [];

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _pageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1.0,
    );
    _initTabs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(heartbeatServiceProvider).onConnectionLost = () {
        if (mounted) {
          DisconnectedDialog.show(
            context,
            onReconnected: () {
              final label = ref.read(activeTabProvider);
              _reloadTabContent(label);
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

  void _showStudentSearchDialog(
    BuildContext context,
    WidgetRef ref, {
    bool navigateToStudents = false,
  }) {
    final currentSearch = ref.read(studentQueryProvider).search;
    final searchController = TextEditingController(text: currentSearch);
    final searchFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                controller: searchController,
                focusNode: searchFocusNode,
                collapsible: false,
                hint: 'Search by LRN or name...',
                maxWidth: 600,
                onSubmitted: (value) {
                  Navigator.of(ctx).pop();
                  final queryText = value.trim();
                  if (navigateToStudents) {
                    ref.read(studentViewTabProvider.notifier).state = StudentViewTab.all;
                    ref.read(studentAllSearchProvider.notifier).state = queryText;
                    ref.read(studentQueryProvider.notifier).setFilters(
                      status: '',
                      schoolYear: '',
                      gradeLevel: '',
                      section: '',
                    );
                    ref.read(studentQueryProvider.notifier).setSearch(queryText);
                    ref.invalidate(studentPageProvider);
                    ref.read(activeTabProvider.notifier).setTab('Students');
                  } else {
                    final currentTab = ref.read(studentViewTabProvider);
                    if (currentTab == StudentViewTab.enrolled) {
                      ref.read(studentEnrolledSearchProvider.notifier).state = queryText;
                    } else {
                      ref.read(studentAllSearchProvider.notifier).state = queryText;
                    }
                    ref.read(studentQueryProvider.notifier).setSearch(queryText);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDocumentSearchDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    final currentSearch = ref.read(documentQueryProvider).search;
    final searchController = TextEditingController(text: currentSearch);
    final searchFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                controller: searchController,
                focusNode: searchFocusNode,
                collapsible: false,
                hint: 'Search by name, LRN, file…',
                maxWidth: 600,
                onSubmitted: (value) {
                  Navigator.of(ctx).pop();
                  ref.read(documentQueryProvider.notifier).setSearch(value);
                  ref.invalidate(foldersProvider);
                  ref.invalidate(studentFoldersProvider);
                  ref.invalidate(documentPageProvider);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showArchiveSearchDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    final currentSearch = ref.read(archiveDocumentQueryProvider).search;
    final searchController = TextEditingController(text: currentSearch);
    final searchFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                controller: searchController,
                focusNode: searchFocusNode,
                collapsible: false,
                hint: 'Search archives by name, LRN, file…',
                maxWidth: 600,
                onSubmitted: (value) {
                  Navigator.of(ctx).pop();
                  ref
                      .read(archiveDocumentQueryProvider.notifier)
                      .setSearch(value);
                  ref.invalidate(archiveStudentFoldersProvider);
                  ref.invalidate(archiveDocumentPageProvider);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUserSearchDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    final currentSearch = ref.read(userSearchQueryProvider);
    final searchController = TextEditingController(text: currentSearch);
    final searchFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                controller: searchController,
                focusNode: searchFocusNode,
                collapsible: false,
                hint: 'Search by username, name, email or role...',
                maxWidth: 600,
                onChanged: (value) {
                  ref.read(userSearchQueryProvider.notifier).state = value;
                },
                onSubmitted: (value) {
                  Navigator.of(ctx).pop();
                  ref.read(userSearchQueryProvider.notifier).state = value;
                },
              ),
            ),
          ),
        );
      },
    );
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
        'label': 'Activity History',
        'icon': Icons.manage_history_outlined,
        'activeIcon': Icons.manage_history_rounded,
        'screen': AuditTrailScreen(userRole: widget.userRole),
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
  }

  @override
  void dispose() {
    _drawerController.dispose();
    _pageTransitionController.dispose();
    _holdTimer?.cancel();
    _drawerCloseTimer?.cancel();
    super.dispose();
  }

  bool get _isDrawerOpen => _drawerController.value > 0.01;

  void _openDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    _drawerController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
    );
  }

  void _closeDrawer() {
    _drawerCloseTimer?.cancel();
    _drawerController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
    );
  }

  void _toggleDrawer() {
    if (_isDrawerOpen) {
      _closeDrawer();
    } else {
      _openDrawer();
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _drawerCloseTimer?.cancel();
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double slideWidth) {
    final delta = details.primaryDelta ?? 0.0;
    _drawerController.value =
        (_drawerController.value + delta / slideWidth).clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity > 300) {
      final ms =
          ((1.0 - _drawerController.value) * 280).round().clamp(120, 280);
      _drawerController.animateTo(
        1.0,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
    } else if (velocity < -300) {
      final ms = (_drawerController.value * 250).round().clamp(120, 250);
      _drawerController.animateTo(
        0.0,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
    } else if (_drawerController.value >= 0.35) {
      final ms =
          ((1.0 - _drawerController.value) * 280).round().clamp(120, 280);
      _drawerController.animateTo(
        1.0,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
    } else {
      final ms = (_drawerController.value * 250).round().clamp(120, 250);
      _drawerController.animateTo(
        0.0,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onHorizontalDragCancel() {
    _isDragging = false;
    if (_drawerController.value < 0.35) {
      _closeDrawer();
    } else {
      _openDrawer();
    }
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

  void _onNavTapped(String label) {
    if (ref.read(studentMultiSelectProvider)) {
      ref.read(studentMultiSelectProvider.notifier).state = false;
      ref.read(studentSelectedIdsProvider.notifier).state = [];
    }
    ref.read(activeTabProvider.notifier).setTab(label);
    _reloadTabContent(label);
  }

  void _selectDrawerTab(String label, {required bool isSelected}) {
    HapticFeedback.selectionClick();
    if (!isSelected) {
      _onNavTapped(label);
      _drawerCloseTimer?.cancel();
      _drawerCloseTimer = Timer(const Duration(milliseconds: 40), () {
        if (mounted) _closeDrawer();
      });
    } else {
      _closeDrawer();
    }
  }

  void _showCapstoneMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CapstoneMembersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTabProvider, (prev, next) {
      if (prev != next) {
        _pageTransitionController.forward(from: 0.0);
      }
    });

    final activeTab = ref.watch(activeTabProvider);

    int currentIndex = _tabs.indexWhere((t) => t['label'] == activeTab);
    if (currentIndex == -1) currentIndex = 0; // Fallback to Dashboard

    _visitedIndices.add(currentIndex);

    final navPrimary = _allowedPrimary;
    final navSecondary =
        _allowedSecondary.where((t) => t['label'] != 'Settings').toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isDrawerOpen) {
          _closeDrawer();
          return;
        }

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
          if (activeTab == 'Students') {
            if (ref.read(studentMultiSelectProvider)) {
              ref.read(studentMultiSelectProvider.notifier).state = false;
              ref.read(studentSelectedIdsProvider.notifier).state = [];
              return;
            }
          } else if (activeTab == 'Documents') {
            if (ref.read(openedFolderProvider) != null) {
              ref.read(openedFolderProvider.notifier).setFolder(null);
              return;
            }
          } else if (activeTab == 'Archives') {
            if (ref.read(openedArchiveFolderProvider) != null) {
              ref.read(openedArchiveFolderProvider.notifier).setFolder(null);
              return;
            }
          }
          _onNavTapped('Dashboard');
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
      child: Builder(
        builder: (context) {
          final mediaQuery = MediaQuery.of(context);
          final lockedMediaQuery = mediaQuery.copyWith(
            viewInsets: EdgeInsets.zero,
            padding: mediaQuery.viewPadding,
          );
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final double screenWidth = mediaQuery.size.width;
          final double drawerWidth = (screenWidth * 0.68).clamp(220.0, 260.0);
          final Color drawerBackdropColor =
              isDark ? const Color(0xFF101613) : const Color(0xFFF0F4F1);

          final overlayStyle = SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          );
          final isStudentMultiSelect = (activeTab == 'Students') &&
              ref.watch(studentMultiSelectProvider);

          if (isStudentMultiSelect && _isDrawerOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _isDrawerOpen) _closeDrawer();
            });
          }

          final mainScaffold = Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: isStudentMultiSelect
                    ? AppBar(
                        systemOverlayStyle: SystemUiOverlayStyle.light,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceCard
                            : AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        leading: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'Exit Selection',
                          onPressed: () {
                            ref.read(studentMultiSelectProvider.notifier).state = false;
                            ref.read(studentSelectedIdsProvider.notifier).state = [];
                          },
                        ),
                        title: Consumer(
                          builder: (context, ref, _) {
                            final selectedIds = ref.watch(studentSelectedIdsProvider);
                            return Text(
                              '${selectedIds.length} selected',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        actions: [
                          Consumer(
                            builder: (context, ref, _) {
                              final selectedIds = ref.watch(studentSelectedIdsProvider);
                              final pageAsync = ref.watch(studentPageProvider);
                              final currentStudents = pageAsync.value?.students ?? [];
                              final allSelected = currentStudents.isNotEmpty &&
                                  currentStudents.every((s) => selectedIds.contains(s.id));

                              return IconButton(
                                icon: Icon(
                                  allSelected ? Icons.deselect : Icons.select_all,
                                  color: Colors.white,
                                ),
                                tooltip: allSelected ? 'Unselect All' : 'Select All',
                                onPressed: () {
                                  if (allSelected) {
                                    ref.read(studentSelectedIdsProvider.notifier).state = [];
                                  } else {
                                    ref.read(studentSelectedIdsProvider.notifier).state =
                                        currentStudents.map((s) => s.id).toList();
                                  }
                                },
                              );
                            },
                          ),
                          if (widget.userRole != 'teacher')
                            Consumer(
                              builder: (context, ref, _) {
                                final selectedIds = ref.watch(studentSelectedIdsProvider);
                                if (selectedIds.isEmpty) return const SizedBox(width: 4);

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.group_add_rounded, color: Colors.white),
                                      tooltip: 'Enroll',
                                      onPressed: () => StudentBulkActions.bulkEnroll(context, ref),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.school_rounded, color: Colors.white),
                                      tooltip: 'Graduate',
                                      onPressed: () => StudentBulkActions.bulkGraduate(context, ref),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                                      tooltip: 'More Actions',
                                      onSelected: (action) {
                                        if (action == 'Transferred' || action == 'Dropped' || action == 'Inactive') {
                                          StudentBulkActions.bulkChangeStatus(context, ref, action);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'Transferred',
                                          child: Row(
                                            children: [
                                              Icon(Icons.transfer_within_a_station_rounded, size: 20, color: AppColors.primaryGreen),
                                              SizedBox(width: 10),
                                              Text('Transfer'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Dropped',
                                          child: Row(
                                            children: [
                                              Icon(Icons.person_off_rounded, size: 20, color: Colors.redAccent),
                                              SizedBox(width: 10),
                                              Text('Drop'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Inactive',
                                          child: Row(
                                            children: [
                                              Icon(Icons.do_not_disturb_on_total_silence_rounded, size: 20, color: Colors.orangeAccent),
                                              SizedBox(width: 10),
                                              Text('Set Inactive'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                );
                              },
                            ),
                        ],
                      )
                    : AppBar(
                        toolbarHeight: 62,
                        titleSpacing: 6,
                        systemOverlayStyle: overlayStyle,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceCard.withValues(alpha: 0.94)
                            : Colors.white.withValues(alpha: 0.96),
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        surfaceTintColor: Colors.transparent,
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(1),
                          child: Container(
                            height: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        leadingWidth: 56,
                        leading: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _onHorizontalDragStart,
                          onHorizontalDragUpdate: (details) =>
                              _onHorizontalDragUpdate(details, drawerWidth),
                          onHorizontalDragEnd: _onHorizontalDragEnd,
                          onHorizontalDragCancel: _onHorizontalDragCancel,
                          child: Center(
                            child: Tooltip(
                              message: 'Toggle navigation menu',
                              child: Material(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.045),
                                borderRadius: BorderRadius.circular(11),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(11),
                                  onTap: _toggleDrawer,
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: AnimatedIcon(
                                      icon: AnimatedIcons.menu_close,
                                      progress: _drawerController,
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                activeTab,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const ServerConnectionPill(compact: true),
                          ],
                        ),
                        actions: [
                          if (activeTab == 'Dashboard') ...[
                            _headerIconBtn(
                              isDark: isDark,
                              tooltip: 'Search Students',
                              icon: Icons.search_rounded,
                              onTap: () => _showStudentSearchDialog(
                                context,
                                ref,
                                navigateToStudents: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.045),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: const NotificationIconButton(iconSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Consumer(
                              builder: (context, ref, _) {
                                final user = ref.watch(authProvider).valueOrNull;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ProfileDropdownMenu(
                                    user: user,
                                    onRefresh: () =>
                                        ref.read(authProvider.notifier).refreshUser(),
                                  ),
                                );
                              },
                            ),
                          ],

                          if (activeTab == 'Documents') ...[
                            _headerIconBtn(
                              isDark: isDark,
                              tooltip: 'Search Documents',
                              icon: Icons.search_rounded,
                              onTap: () => _showDocumentSearchDialog(context, ref),
                            ),
                            if (widget.userRole != 'teacher') ...[
                              const SizedBox(width: 6),
                              Consumer(
                                builder: (context, ref, _) {
                                  final queueAsync = ref.watch(printQueueProvider);
                                  final count = queueAsync.maybeWhen(
                                    data: (items) => items.length,
                                    orElse: () => 0,
                                  );
                                  return _headerIconBtn(
                                    isDark: isDark,
                                    tooltip: 'Print List',
                                    icon: Icons.print_rounded,
                                    badgeCount: count,
                                    onTap: () => PrintQueueModal.show(context),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(width: 8),
                            _headerPrimaryCta(
                              tooltip: 'Upload Document',
                              icon: Icons.cloud_upload_rounded,
                              onTap: () {
                                final openedFolder = ref.read(openedFolderProvider);
                                final studentId = openedFolder?.id ??
                                    ref.read(documentQueryProvider).studentId;
                                UploadOcrModal.show(
                                  context,
                                  prefilledStudentId: studentId,
                                  prefilledLrn: openedFolder?.lrn,
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (activeTab == 'Archives') ...[
                            _headerIconBtn(
                              isDark: isDark,
                              tooltip: 'Search Archives',
                              icon: Icons.search_rounded,
                              onTap: () => _showArchiveSearchDialog(context, ref),
                            ),
                            if (widget.userRole != 'teacher') ...[
                              const SizedBox(width: 6),
                              Consumer(
                                builder: (context, ref, _) {
                                  final queueAsync = ref.watch(printQueueProvider);
                                  final count = queueAsync.maybeWhen(
                                    data: (items) => items.length,
                                    orElse: () => 0,
                                  );
                                  return _headerIconBtn(
                                    isDark: isDark,
                                    tooltip: 'Print List',
                                    icon: Icons.print_rounded,
                                    badgeCount: count,
                                    onTap: () => PrintQueueModal.show(context),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(width: 12),
                          ],
                          if (activeTab == 'Users') ...[
                            Consumer(
                              builder: (context, ref, _) {
                                final query = ref.watch(userSearchQueryProvider);
                                return _headerIconBtn(
                                  isDark: isDark,
                                  tooltip: query.isNotEmpty
                                      ? 'Clear Search'
                                      : 'Search Users',
                                  icon: query.isNotEmpty
                                      ? Icons.close_rounded
                                      : Icons.search_rounded,
                                  onTap: () {
                                    if (query.isNotEmpty) {
                                      ref.read(userSearchQueryProvider.notifier).state = '';
                                    } else {
                                      _showUserSearchDialog(context, ref);
                                    }
                                  },
                                );
                              },
                            ),
                            if (widget.userRole == 'admin') ...[
                              const SizedBox(width: 6),
                              _headerIconBtn(
                                isDark: isDark,
                                tooltip: 'Academic & Class Management',
                                icon: Icons.school_outlined,
                                onTap: () => TeacherManagementModal.open(context),
                              ),
                            ],
                            const SizedBox(width: 8),
                            _headerPrimaryCta(
                              tooltip: 'Add User',
                              icon: Icons.person_add_rounded,
                              onTap: () => AddEditUserModal.show(context),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ],
                      ),
            body: AbstractBackground(
              child: AnimatedBuilder(
                animation: _pageTransitionController,
                child: RepaintBoundary(
                  child: IndexedStack(
                    index: currentIndex,
                    children: _tabs.asMap().entries.map((entry) {
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
                    0.80,
                    curve: Curves.easeOut,
                  ).transform(t);
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 10.0 * (1.0 - glide)),
                      child: Transform.scale(
                        scale: 0.97 + (0.03 * glide),
                        child: stackChild,
                      ),
                    ),
                  );
                },
              ),
            ),
          );

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                isStudentMultiSelect ? SystemUiOverlayStyle.light : overlayStyle,
            child: MediaQuery(
              data: lockedMediaQuery,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Color.lerp(
                              const Color(0xFF0E1411),
                              AppColors.primaryGreen,
                              0.12,
                            )!,
                            const Color(0xFF0E1411),
                          ]
                        : [
                            Color.lerp(
                              const Color(0xFFF3F6F4),
                              AppColors.primaryGreen,
                              0.07,
                            )!,
                            drawerBackdropColor,
                          ],
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _drawerController,
                  child: RepaintBoundary(child: mainScaffold),
                  builder: (context, child) {
                    final double t = _drawerController.value;
                    final bool drawerVisible = t > 0.001;
                    final double cardRadius = 26.0 * t;
                    final double cardScale = 1.0 - 0.14 * t;
                    final Matrix4 perspectiveTransform = Matrix4.identity()
                      ..translateByDouble(drawerWidth * t, 0.0, 0.0, 1.0)
                      ..scaleByDouble(cardScale, cardScale, 1.0, 1.0)
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(-0.04 * t);

                    return Stack(
                      children: [
                        if (drawerVisible)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: drawerWidth,
                            child: Transform.translate(
                              offset: Offset(-24.0 * (1.0 - t), 0),
                              child: Transform.scale(
                                scale: 0.96 + (0.04 * t),
                                alignment: Alignment.centerLeft,
                                child: Opacity(
                                  opacity: t.clamp(0.0, 1.0),
                                  child: RepaintBoundary(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragStart:
                                          _onHorizontalDragStart,
                                      onHorizontalDragUpdate: (d) {
                                        if ((d.primaryDelta ?? 0) < 0) {
                                          _onHorizontalDragUpdate(
                                            d,
                                            drawerWidth,
                                          );
                                        }
                                      },
                                      onHorizontalDragEnd: _onHorizontalDragEnd,
                                      onHorizontalDragCancel:
                                          _onHorizontalDragCancel,
                                      child: _buildMinimalistDrawer(
                                        context,
                                        activeTab,
                                        navPrimary,
                                        navSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (drawerVisible)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Transform.translate(
                                offset: Offset((drawerWidth - 18.0) * t, 0),
                                child: Transform.scale(
                                  scale: 1.0 - 0.19 * t,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurfaceCard
                                              .withValues(alpha: 0.42 * t)
                                          : Colors.white
                                              .withValues(alpha: 0.52 * t),
                                      borderRadius: BorderRadius.circular(
                                        cardRadius,
                                      ),
                                      border: Border.all(
                                        color: (isDark
                                                ? AppColors.darkBorder
                                                : AppColors.borderLight)
                                            .withValues(alpha: 0.55 * t),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Transform(
                          transform: perspectiveTransform,
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: drawerVisible
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      cardRadius,
                                    ),
                                    border: Border.all(
                                      color: (isDark
                                              ? AppColors.darkBorder
                                              : AppColors.borderLight)
                                          .withValues(alpha: t),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: (isDark ? 0.50 : 0.15) * t,
                                        ),
                                        blurRadius: 30,
                                        offset: const Offset(-10, 14),
                                      ),
                                    ],
                                  )
                                : const BoxDecoration(),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(cardRadius),
                              clipBehavior: drawerVisible
                                  ? Clip.antiAlias
                                  : Clip.none,
                              child: Stack(
                                children: [
                                  child!,
                                  if (t > 0.01)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _closeDrawer,
                                        onHorizontalDragStart:
                                            _onHorizontalDragStart,
                                        onHorizontalDragUpdate: (d) =>
                                            _onHorizontalDragUpdate(
                                              d,
                                              drawerWidth,
                                            ),
                                        onHorizontalDragEnd:
                                            _onHorizontalDragEnd,
                                        onHorizontalDragCancel:
                                            _onHorizontalDragCancel,
                                        child: ColoredBox(
                                          color: Colors.black.withValues(
                                            alpha: (isDark ? 0.24 : 0.08) * t,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if ((t <= 0.05 || _isDragging) && !isStudentMultiSelect)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 56.0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragStart: _onHorizontalDragStart,
                              onHorizontalDragUpdate: (d) =>
                                  _onHorizontalDragUpdate(d, drawerWidth),
                              onHorizontalDragEnd: _onHorizontalDragEnd,
                              onHorizontalDragCancel: _onHorizontalDragCancel,
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _headerIconBtn({
    required bool isDark,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: badgeCount > 0
                ? Badge(
                    label: Text(badgeCount.toString()),
                    child: Icon(icon, size: 20),
                  )
                : Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _headerPrimaryCta({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00B074),
              AppColors.primaryGreen,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: Center(
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalistDrawer(
    BuildContext context,
    String activeTab,
    List<Map<String, dynamic>> navPrimary,
    List<Map<String, dynamic>> navSecondary,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;
    final user = ref.watch(authProvider).valueOrNull;
    final initials =
        user != null && user.firstName.isNotEmpty && user.lastName.isNotEmpty
            ? '${user.firstName[0]}${user.lastName[0]}'.toUpperCase()
            : 'SA';
    final isSettingsActive = activeTab == 'Settings';

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo.webp',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TIS RMS',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.9,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  if (navPrimary.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
                      child: Text(
                        'MAIN',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                    ...navPrimary.map((tab) => _buildDrawerItem(tab, activeTab)),
                  ],
                  if (navSecondary.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 12, 4),
                      child: Text(
                        'ADMINISTRATION',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                    ...navSecondary.map(
                      (tab) => _buildDrawerItem(tab, activeTab),
                    ),
                  ],
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.6)
                  : AppColors.borderLight,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(pendingSettingsCategoryProvider.notifier).state =
                            'profile';
                        _selectDrawerTab(
                          'Settings',
                          isSelected: isSettingsActive,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
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
                                    user?.fullName ?? 'Unknown User',
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Settings',
                    child: Material(
                      color: isSettingsActive
                          ? AppColors.primaryGreen
                              .withValues(alpha: isDark ? 0.18 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _selectDrawerTab(
                          'Settings',
                          isSelected: isSettingsActive,
                        ),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(
                            isSettingsActive
                                ? Icons.settings_rounded
                                : Icons.settings_outlined,
                            size: 19,
                            color: isSettingsActive
                                ? primaryColor
                                : onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Tooltip(
                    message: 'Logout',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _closeDrawer();
                          showLogoutConfirmationDialog(context);
                        },
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(
                            Icons.logout_rounded,
                            size: 19,
                            color: onSurface.withValues(alpha: 0.6),
                          ),
                        ),
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

  Widget _buildDrawerItem(Map<String, dynamic> tab, String activeTab) {
    final label = tab['label'] as String;
    final icon = tab['icon'] as IconData;
    final activeIcon = tab['activeIcon'] as IconData? ?? icon;
    final isSelected = label == activeTab;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _selectDrawerTab(label, isSelected: isSelected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        AppColors.primaryGreen.withValues(
                          alpha: isDark ? 0.22 : 0.14,
                        ),
                        AppColors.primaryGreen.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                AnimatedContainer(
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
                SizedBox(width: isSelected ? 9 : 6),
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? primaryColor
                      : onSurface.withValues(alpha: 0.58),
                  size: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? primaryColor
                          : onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
