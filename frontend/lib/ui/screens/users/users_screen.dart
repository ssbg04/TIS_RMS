import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/system_user.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/inputs/app_search_bar.dart';
import '../../shared/buttons/primary_button.dart';
import '../../shared/widgets/app_pagination.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../providers/users_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';

// --- NEW IMPORTS FOR CUSTOM DIALOGS ---
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/confirm_dialog.dart';
import '../../shared/modals/custom_modal.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/haptic_service.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _shortcutFocusNode = FocusNode();
  final ScrollController _filterScrollController = ScrollController();
  ProviderSubscription<String>? _tabListener;
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'admin', 'teacher'
  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 1;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (ref.read(activeTabProvider) == 'Users') {
        _shortcutFocusNode.requestFocus();
      }

      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (next == 'Users') {
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) {
              _shortcutFocusNode.requestFocus();
            }
          });
          if (previous != 'Users') {
            _searchController.clear();
            setState(() {
              _roleFilter = 'all';
              _searchQuery = '';
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _shortcutFocusNode.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  List<SystemUser> _filter(List<SystemUser> users) {
    var result = users;
    // Apply status and role filter
    if (_roleFilter == 'inactive') {
      result = result.where((u) => !u.isActive).toList();
    } else if (_roleFilter == 'admin') {
      result = result.where((u) => u.isActive && u.role == 'admin').toList();
    } else if (_roleFilter == 'teacher') {
      result = result.where((u) => u.isActive && u.role == 'teacher').toList();
    } else {
      // 'all' shows all active users
      result = result.where((u) => u.isActive).toList();
    }
    bool isFuzzyMatch(String text, String query) {
      if (query.isEmpty) return true;
      int j = 0;
      for (int i = 0; i < text.length && j < query.length; i++) {
        if (text[i] == query[j]) {
          j++;
        }
      }
      return j == query.length;
    }

    // Then apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (u) =>
                isFuzzyMatch(u.username.toLowerCase(), _searchQuery) ||
                isFuzzyMatch(u.fullName.toLowerCase(), _searchQuery) ||
                isFuzzyMatch(u.role.toLowerCase(), _searchQuery),
          )
          .toList();
    }
    return result;
  }

  Future<void> _handleRefresh() async {
    await ref.read(usersProvider.notifier).refresh();
  }

  Future<void> _confirmResetPassword(SystemUser user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ResetPasswordConfirmationDialog(user: user),
    );
    if (result == null || !mounted) return;

    try {
      final message = await ref
          .read(usersProvider.notifier)
          .resetPassword(
            user.id,
            adminPassword: result['password'] as String,
            expirationMinutes: result['expirationMinutes'] as int? ?? 15,
          );
      if (!mounted) return;

      showSuccessDialog(
        context,
        title: 'Reset Link Sent',
        message: message,
      );
    } catch (e) {
      if (!mounted) return;

      showErrorDialog(
        context,
        'Reset Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _confirmToggleStatus(SystemUser user) async {
    final willDeactivate = user.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: willDeactivate ? 'Deactivate User?' : 'Activate User?',
      message: willDeactivate
          ? 'Are you sure you want to deactivate "${user.fullName}" (@${user.username})?\n\nThis user will be immediately blocked from logging in.'
          : 'Are you sure you want to activate "${user.fullName}" (@${user.username})?\n\nThis user will regain access to log into the system.',
      confirmLabel: willDeactivate ? 'Deactivate' : 'Activate',
      cancelLabel: 'Cancel',
      isDanger: willDeactivate,
      confirmColor: willDeactivate ? AppColors.error : AppColors.primaryGreen,
      icon: willDeactivate ? Icons.block_rounded : Icons.check_circle_outline_rounded,
      iconColor: willDeactivate ? AppColors.error : AppColors.primaryGreen,
    );

    if (confirmed != true || !mounted) return;
    await _toggleStatus(user);
  }

  Future<void> _toggleStatus(SystemUser user) async {
    try {
      final newActive = await ref
          .read(usersProvider.notifier)
          .toggleStatus(user.id);
      if (!mounted) return;
      showSuccessDialog(
        context,
        title: newActive ? 'User Activated' : 'User Deactivated',
        message: newActive
            ? '"${user.username}" can now log in to the system.'
            : '"${user.username}" has been deactivated and cannot log in.',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Status Change Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _openModal({SystemUser? user}) async {
    final success = await AddEditUserModal.show(context, user: user);
    if (success == true && mounted && user != null) {
      showSuccessDialog(
        context,
        title: 'User Updated',
        message: 'User updated successfully!',
      );
    }
  }

  void _showUserDetailModal(SystemUser user) {
    final currentUser = ref.watch(authProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final headerBg = isDark ? AppColors.darkSurface2 : Colors.grey.shade50;
    final borderCol = isDark ? AppColors.darkBorder : Colors.grey.shade200;
    final roleCol = _roleColor(user.role);

    CustomModal.show(
      context: context,
      title: 'User Profile Details',
      icon: Icons.person_outline,
      maxWidth: 540,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Profile Identity & Badges
            Container(
              padding: const EdgeInsets.all(AppSizes.p20),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: roleCol.withValues(alpha: 0.15),
                            child: Text(
                              user.initials,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: roleCol,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: user.isActive ? AppColors.success : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: headerBg,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSizes.p16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.fullName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  '@${user.username}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildRoleChip(user.role),
                                const SizedBox(width: 6),
                                _buildStatusChip(user.isActive),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.p16),

                  // Responsive Action Buttons Toolbar for Android & Windows
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 420;
                      final canToggle = user.id != currentUser?.id;

                      Widget buildActionButton({
                        required IconData icon,
                        required String label,
                        required Color color,
                        required VoidCallback onTap,
                      }) {
                        return Material(
                          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              HapticService.light();
                              onTap();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 8 : 14,
                                vertical: isCompact ? 10 : 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: color.withValues(alpha: isDark ? 0.35 : 0.28),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: isCompact ? 16 : 17, color: color),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: isCompact ? 12 : 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final editBtn = buildActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: AppColors.primaryGreen,
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          _openModal(user: user);
                        },
                      );

                      final resetBtn = buildActionButton(
                        icon: Icons.lock_reset_rounded,
                        label: 'Reset Pass',
                        color: Colors.orange.shade700,
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          _confirmResetPassword(user);
                        },
                      );

                      final toggleBtn = canToggle
                          ? buildActionButton(
                              icon: user.isActive
                                  ? Icons.block_rounded
                                  : Icons.check_circle_outline_rounded,
                              label: user.isActive ? 'Deactivate' : 'Activate',
                              color: user.isActive
                                  ? Colors.red.shade600
                                  : AppColors.primaryGreen,
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).pop();
                                _confirmToggleStatus(user);
                              },
                            )
                          : null;

                      return Row(
                        children: [
                          Expanded(child: editBtn),
                          const SizedBox(width: 8),
                          Expanded(child: resetBtn),
                          if (toggleBtn != null) ...[
                            const SizedBox(width: 8),
                            Expanded(child: toggleBtn),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Profile Information Body
            Padding(
              padding: const EdgeInsets.all(AppSizes.p20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Access Role',
                    value: user.role.toUpperCase().replaceAll('_', ' '),
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Account Status',
                    value: user.isActive ? 'Active (Can login)' : 'Inactive (Access blocked)',
                    valueColor: user.isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date Joined',
                    value: user.createdAt?.split('T').first ?? '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email?.isNotEmpty == true ? user.email! : '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user.phone?.isNotEmpty == true ? user.phone! : '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.person_add_outlined,
                    label: 'Added By',
                    value: user.addedByName != null
                        ? '${user.addedByName} (@${user.addedByUsername})'
                        : 'System',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: textSecondary.withValues(alpha: 0.8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedFilter(String label, String value, int count) {
    final isSelected = _roleFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = Colors.transparent;
    final unselectedBorder = isDark ? AppColors.darkBorder : Colors.grey.shade300;
    final unselectedText = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _roleFilter = value;
          _currentPage = 1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : unselectedBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : unselectedText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _showSearchDialog(context);
        },
      },
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: (MediaQuery.of(context).size.width > 800 ||
              _searchFocusNode.hasFocus ||
              _searchQuery.isNotEmpty)
          ? null
          : FloatingActionButton(
              heroTag: 'add_user_fab',
              onPressed: () => _openModal(),
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSizes.p24),
              Expanded(
                child: usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => AppErrorState.fromError(
                    error: err,
                    onRetry: _handleRefresh,
                  ),
                  data: (users) {
                    final filtered = _filter(users);
                    final int totalPages = (filtered.length / _itemsPerPage).ceil();
                    final int startIndex = (_currentPage - 1) * _itemsPerPage;
                    final int endIndex = (startIndex + _itemsPerPage).clamp(0, filtered.length);
                    final paginated = filtered.isEmpty ? <SystemUser>[] : filtered.sublist(startIndex, endIndex);

                    final activeUsers = users.where((u) => u.isActive).toList();
                    final activeAdmins = activeUsers.where((u) => u.role == 'admin').toList();
                    final activeTeachers = activeUsers.where((u) => u.role == 'teacher').toList();
                    final inactiveUsers = users.where((u) => !u.isActive).toList();

                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SingleChildScrollView(
                                    controller: _filterScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildAnimatedFilter('All', 'all', activeUsers.length),
                                        _buildAnimatedFilter(
                                          'Admin',
                                          'admin',
                                          activeAdmins.length,
                                        ),
                                        _buildAnimatedFilter(
                                          'Teacher',
                                          'teacher',
                                          activeTeachers.length,
                                        ),
                                        _buildAnimatedFilter(
                                          'Inactive',
                                          'inactive',
                                          inactiveUsers.length,
                                        ),
                                      ],
                                    ),
                                  ),
                                  _CustomHorizontalScrollBar(
                                    controller: _filterScrollController,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                            if (!_searchFocusNode.hasFocus)
                              Tooltip(
                                richMessage: _searchQuery.isNotEmpty
                                    ? const TextSpan(text: 'Clear Search')
                                    : const TextSpan(
                                        text: 'Search Users ',
                                        children: [
                                          TextSpan(
                                            text: '(Ctrl+F)',
                                            style: TextStyle(fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ),
                                child: IconButton(
                                  icon: Icon(
                                    _searchQuery.isNotEmpty ? Icons.close : Icons.search,
                                    size: 28,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : Colors.black87,
                                  ),
                                  onPressed: () {
                                    if (_searchQuery.isNotEmpty) {
                                      _searchController.clear();
                                    } else {
                                      _showSearchDialog(context);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                         Expanded(
                           child: Padding(
                             padding: const EdgeInsets.symmetric(vertical: 4.0),
                             child: RefreshIndicator(
                               onRefresh: _handleRefresh,
                               child: LayoutBuilder(
                                 builder: (context, constraints) {
                                   if (constraints.maxWidth > 800) {
                                     return _buildDesktopTable(paginated);
                                   } else {
                                     return _buildMobileList(paginated);
                                   }
                                 },
                               ),
                             ),
                           ),
                         ),
                        if (!_searchFocusNode.hasFocus && totalPages > 1)
                          SafeArea(
                            top: false,
                            child: AppPagination(
                              currentPage: _currentPage,
                              totalPages: totalPages,
                              onPageChanged: (p) => setState(() => _currentPage = p),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'User Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            if (isDesktop)
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add User',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _openModal(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Manage system accounts and access roles.',
          style: TextStyle(fontSize: 14, color: textSecondary),
        ),
      ],
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 24, 16, 0),
            child: Material(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: AppSearchBar(
                hint: 'Search by username, name or role...',
                controller: _searchController,
                focusNode: _searchFocusNode,
                collapsible: false,
                maxWidth: 600,
                onSubmitted: (val) {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        );
      },
    );

    if (mounted) {
      _searchFocusNode.unfocus();
      _shortcutFocusNode.requestFocus();
      setState(() {});
    }
  }

  Widget _buildDesktopTable(List<SystemUser> users) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final cardBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(
              isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : AppColors.primaryGreen.withValues(alpha: 0.05),
            ),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            columnSpacing: 24,
            dataRowMaxHeight: 65,
            dataRowMinHeight: 50,
            showBottomBorder: true,
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('Access Role')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: SizedBox.shrink()), // Trailing icon
            ],
            rows: users.isEmpty
                ? [
                    DataRow(
                      cells: [
                        DataCell(Text('No users found.', style: TextStyle(color: textSecondary))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                      ],
                    ),
                  ]
                : users
                      .map(
                        (user) => DataRow(
                          onSelectChanged: (_) => _showUserDetailModal(user),
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _roleColor(
                                      user.role,
                                    ).withValues(alpha: 0.15),
                                    child: Text(
                                      user.initials,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _roleColor(user.role),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    user.fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                '@${user.username}',
                                style: TextStyle(
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            DataCell(_buildRoleChip(user.role)),
                            DataCell(_buildStatusChip(user.isActive)),
                            DataCell(
                              Text(
                                user.email ?? user.phone ?? '—',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<SystemUser> users) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final cardBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;
    final borderCol = isDark ? AppColors.darkBorder : Colors.grey.shade100;

    if (users.isEmpty) {
      return Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final user = users[index];
        return InkWell(
          onTap: () => _showUserDetailModal(user),
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.p16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _roleColor(
                    user.role,
                  ).withValues(alpha: 0.15),
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _roleColor(user.role),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildRoleChip(user.role),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (user.email != null || user.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (user.email != null) user.email!,
                            if (user.phone != null) user.phone!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleChip(String role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    if (role == 'admin') return Colors.blue;
    return AppColors.primaryGreen;
  }
}

// ============================================================
// ADD / EDIT MODAL
// ============================================================
class AddEditUserModal extends ConsumerStatefulWidget {
  final SystemUser? user;
  const AddEditUserModal({super.key, this.user});

  static Future<bool?> show(BuildContext context, {SystemUser? user}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WoltModalSheet.show<bool>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          WoltModalSheetPage(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
            hasSabGradient: false,
            hasTopBarLayer: false,
            child: AddEditUserModal(user: user),
          ),
        ];
      },
    );
  }

  @override
  ConsumerState<AddEditUserModal> createState() => _AddEditUserModalState();
}

class _AddEditUserModalState extends ConsumerState<AddEditUserModal> {
  final List<GlobalKey<FormState>> _stepKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  int _currentStep = 0;
  late TextEditingController _usernameCtrl;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _middleNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _extCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  String _selectedRole = 'teacher';
  bool _isLoading = false;

  bool get _isEdit => widget.user != null;

  Color _roleColor(String role) {
    if (role == 'admin') return Colors.blue;
    return AppColors.primaryGreen;
  }

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _usernameCtrl = TextEditingController(text: u?.username ?? '');
    _firstNameCtrl = TextEditingController(text: u?.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: u?.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: u?.lastName ?? '');
    _extCtrl = TextEditingController(text: u?.extension ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    if (u != null) _selectedRole = u.role;
  }

  @override
  void dispose() {
    for (final c in [
      _usernameCtrl,
      _firstNameCtrl,
      _middleNameCtrl,
      _lastNameCtrl,
      _extCtrl,
      _emailCtrl,
      _phoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    for (final key in _stepKeys) {
      if (!(key.currentState?.validate() ?? true)) return;
    }
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(usersProvider.notifier);
      if (_isEdit) {
        await notifier.updateUser(
          id: widget.user!.id,
          firstName: _firstNameCtrl.text.trim(),
          middleName: _middleNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          extension: _extCtrl.text.trim(),
          role: _selectedRole,
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        // Create — backend auto-generates a temporary password
        final username = _usernameCtrl.text.trim();
        final tempPassword = await notifier.createUser(
          username: username,
          firstName: _firstNameCtrl.text.trim(),
          middleName: _middleNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          extension: _extCtrl.text.trim(),
          role: _selectedRole,
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        _showCredentialsDialog(
          context,
          username: username,
          tempPassword: tempPassword,
        );
      }
    } catch (e) {
      if (!mounted) return;

      // ✅ Replaced SnackBar with Error Dialog
      showErrorDialog(
        context,
        'Error',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCredentialsDialog(
    BuildContext ctx, {
    required String username,
    required String tempPassword,
  }) {
    bool copied = false;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          ),
          icon: const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 48,
          ),
          title: const Text(
            'User Created!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ Save these credentials now. The temporary password will not be shown again.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '🔒 For best protection, remind the user to change their password after first login.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _credentialRow('Username', username),
              const SizedBox(height: 10),
              _credentialRow('Temp. Password', tempPassword, highlight: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(copied ? Icons.check : Icons.copy, size: 18),
                  label: Text(copied ? 'Copied!' : 'Copy Credentials'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: copied
                        ? AppColors.success
                        : AppColors.primaryGreen,
                    side: BorderSide(
                      color: copied
                          ? AppColors.success
                          : AppColors.primaryGreen,
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Username: $username\nTemporary Password: $tempPassword',
                      ),
                    );
                    setDialogState(() => copied = true);
                  },
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('DONE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialRow(String label, String value, {bool highlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primaryGreen.withValues(alpha: 0.07)
            : (isDark ? AppColors.darkSurface2 : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppColors.primaryGreen.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: highlight
                        ? AppColors.primaryGreen
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isEdit ? Icons.edit : Icons.person_add,
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Edit System User' : 'Add New User',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: AppSizes.p32),

            Stepper(
              currentStep: _currentStep,
              type: StepperType.vertical,
              onStepTapped: null,
              onStepContinue: () {
                if (_stepKeys[_currentStep].currentState?.validate() ?? false) {
                  if (_currentStep < 2) {
                    setState(() => _currentStep += 1);
                  } else {
                    _handleSave();
                  }
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                } else {
                  Navigator.pop(context);
                }
              },
              controlsBuilder: (context, details) {
                final isLastStep = _currentStep == 2;
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: PrimaryButton(
                          label: isLastStep
                              ? (_isEdit ? 'UPDATE' : 'CREATE')
                              : 'CONTINUE',
                          isLoading: _isLoading && isLastStep,
                          onPressed: details.onStepContinue ?? () {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: Text(_currentStep == 0 ? 'CANCEL' : 'BACK'),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: Text(
                    'Personal Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: Form(
                    key: _stepKeys[0],
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 400;
                          if (isMobile) {
                            return Column(
                              children: [
                                _field(
                                  'First Name',
                                  null,
                                  _firstNameCtrl,
                                  required: true,
                                  textCapitalization: TextCapitalization.words,
                                  inputFormatters: [
                                    _TitleCaseTextInputFormatter(),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.p12),
                                _field(
                                  'Middle Name',
                                  null,
                                  _middleNameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  inputFormatters: [
                                    _TitleCaseTextInputFormatter(),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.p12),
                                _field(
                                  'Last Name',
                                  null,
                                  _lastNameCtrl,
                                  required: true,
                                  textCapitalization: TextCapitalization.words,
                                  inputFormatters: [
                                    _TitleCaseTextInputFormatter(),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.p12),
                                _buildExtensionField(),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _field(
                                      'First Name',
                                      null,
                                      _firstNameCtrl,
                                      required: true,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      inputFormatters: [
                                        _TitleCaseTextInputFormatter(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.p12),
                                  Expanded(
                                    child: _field(
                                      'Middle Name',
                                      null,
                                      _middleNameCtrl,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      inputFormatters: [
                                        _TitleCaseTextInputFormatter(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.p12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _field(
                                      'Last Name',
                                      null,
                                      _lastNameCtrl,
                                      required: true,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      inputFormatters: [
                                        _TitleCaseTextInputFormatter(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.p12),
                                  Expanded(
                                    flex: 1,
                                    child: _buildExtensionField(),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Step(
                  title: Text(
                    'Account Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1
                      ? StepState.complete
                      : StepState.indexed,
                  content: Form(
                    key: _stepKeys[1],
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field(
                            'Username',
                            Icons.person,
                            _usernameCtrl,
                            required: !_isEdit,
                            readOnly: _isEdit,
                          ),
                          const SizedBox(height: AppSizes.p12),
                          _buildRoleDropdown(currentUser),
                        ],
                      ),
                    ),
                  ),
                ),
                Step(
                  title: Text(
                    'Contact Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  isActive: _currentStep >= 2,
                  content: Form(
                    key: _stepKeys[2],
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEmailField(),
                          const SizedBox(height: AppSizes.p12),
                          _field(
                            'Phone Number (Starts with 09)',
                            Icons.phone_outlined,
                            _phoneCtrl,
                            validator: AppValidators.validatePhone,
                            maxLength: 11,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          if (!_isEdit) ...[
                            const SizedBox(height: AppSizes.p12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.07,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: AppColors.primaryGreen,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Temporary password will be ',
                                          ),
                                          TextSpan(
                                            text: '${_usernameCtrl.text.trim().isEmpty ? '<username>' : _usernameCtrl.text.trim()}123',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const TextSpan(
                                            text: '. Remind the user to change it after first login.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtensionField() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        const commonExts = ['Jr.', 'Sr.', 'II', 'III', 'IV'];
        if (textEditingValue.text.isEmpty) {
          return commonExts;
        }
        return commonExts.where(
          (ext) =>
              ext.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (String selection) {
        _extCtrl.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        controller.addListener(() {
          if (_extCtrl.text != controller.text) {
            _extCtrl.text = controller.text;
          }
        });
        if (controller.text.isEmpty && _extCtrl.text.isNotEmpty) {
          controller.text = _extCtrl.text;
        }
        return CustomTextField(
          hintText: 'Ext. (Jr, Sr, III)',
          prefixIcon: null,
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [_TitleCaseTextInputFormatter()],
        );
      },
    );
  }

  Widget _buildRoleDropdown(dynamic currentUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isEdit && widget.user?.id == currentUser?.id) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.shield, color: _roleColor(widget.user!.role), size: 20),
            const SizedBox(width: 12),
            Text(
              widget.user!.role.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _roleColor(widget.user!.role),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.lock,
              color: isDark ? AppColors.darkTextMuted : Colors.grey,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '(Your own role cannot be changed)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.shield_outlined, color: AppColors.textSecondary),
      ),
      items: const [
        DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
        DropdownMenuItem(value: 'admin', child: Text('Admin')),
      ],
      onChanged: (val) => setState(() => _selectedRole = val!),
    );
  }

  Widget _buildEmailField() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final text = textEditingValue.text;
        if (!text.contains('@')) {
          return const Iterable<String>.empty();
        }
        final parts = text.split('@');
        final prefix = parts[0];
        final query = parts.length > 1 ? parts[1].toLowerCase() : '';
        const domains = [
          'gmail.com',
          'yahoo.com',
          'outlook.com',
          'hotmail.com',
          'deped.gov.ph',
        ];
        return domains
            .where((domain) => domain.toLowerCase().startsWith(query))
            .map((domain) => '$prefix@$domain');
      },
      onSelected: (String selection) {
        _emailCtrl.text = selection;
      },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 300,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      final display = '@${option.split('@').last}';
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Text(
                            display,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        controller.addListener(() {
          if (_emailCtrl.text != controller.text) {
            _emailCtrl.text = controller.text;
          }
        });
        if (controller.text.isEmpty && _emailCtrl.text.isNotEmpty) {
          controller.text = _emailCtrl.text;
        }
        return CustomTextField(
          hintText: 'Email Address',
          prefixIcon: Icons.email_outlined,
          controller: controller,
          focusNode: focusNode,
          validator: AppValidators.validateEmail,
        );
      },
    );
  }

  Widget _field(
    String hint,
    IconData? icon,
    TextEditingController ctrl, {
    bool required = false,
    bool readOnly = false,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return CustomTextField(
      hintText: hint,
      prefixIcon: icon,
      controller: ctrl,
      readOnly: readOnly,
      validator:
          validator ??
          (required ? (v) => AppValidators.validateRequired(v, hint) : null),
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }
}

// ============================================================
// CUSTOM RESET PASSWORD CONFIRMATION DIALOG
// ============================================================
// ============================================================
// CUSTOM RESET PASSWORD CONFIRMATION DIALOG (EMAIL LINK)
// ============================================================
class _ResetPasswordConfirmationDialog extends StatefulWidget {
  final SystemUser user;
  const _ResetPasswordConfirmationDialog({required this.user});

  @override
  State<_ResetPasswordConfirmationDialog> createState() =>
      _ResetPasswordConfirmationDialogState();
}

class _ResetPasswordConfirmationDialogState
    extends State<_ResetPasswordConfirmationDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  int _selectedExpiration = 15;

  static const _expirationOptions = [
    {'label': '15 Minutes (Recommended)', 'value': 15},
    {'label': '30 Minutes', 'value': 30},
    {'label': '1 Hour', 'value': 60},
    {'label': '24 Hours', 'value': 1440},
  ];

  @override
  void initState() {
    super.initState();
    SoundService.playWarning();
    HapticService.warning();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordCtrl.text.trim();

    if (password.isEmpty) {
      showErrorDialog(
        context,
        'Missing Password',
        'You must confirm using your admin password to send a password reset link.',
      );
      return;
    }

    Navigator.pop(context, {
      'password': password,
      'expirationMinutes': _selectedExpiration,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEmail = widget.user.email != null && widget.user.email!.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Reset Link',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Email time-limited password reset link',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // User Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      child: Text(
                        widget.user.username.isNotEmpty
                            ? widget.user.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.fullName.isNotEmpty
                                ? widget.user.fullName
                                : widget.user.username,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '@${widget.user.username} · ${widget.user.role.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Recipient Email Card / Warning
              if (hasEmail)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.user.email!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: isDark ? 0.4 : 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No email registered. Please edit this user and provide a valid email before sending a reset link.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (hasEmail) ...[
                const SizedBox(height: 16),
                // Expiration selector
                DropdownButtonFormField<int>(
                  key: ValueKey('reset_link_expiration_$_selectedExpiration'),
                  initialValue: _selectedExpiration,
                  decoration: const InputDecoration(
                    labelText: 'Link Expiration Time',
                    prefixIcon: Icon(Icons.timer_outlined),
                    isDense: true,
                  ),
                  items: _expirationOptions.map((opt) {
                    return DropdownMenuItem<int>(
                      value: opt['value'] as int,
                      child: Text(opt['label'] as String, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedExpiration = val);
                  },
                ),
                const SizedBox(height: 16),

                // Admin Password
                CustomTextField(
                  hintText: 'Your Admin Password',
                  prefixIcon: Icons.lock_outline,
                  controller: _passwordCtrl,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasEmail ? AppColors.primaryGreen : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                    ),
                    onPressed: hasEmail ? _submit : null,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text(
                      'SEND LINK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FORMATTER FOR DESKTOP TITLE CASE
// ============================================================
class _TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final text = newValue.text;
    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ' || char == '-' || char == '.') {
        buffer.write(char);
        capitalizeNext = true;
      } else {
        if (capitalizeNext) {
          buffer.write(char.toUpperCase());
          capitalizeNext = false;
        } else {
          buffer.write(char);
        }
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: newValue.selection,
    );
  }
}

// ── Custom Dedicated Thin Horizontal Scrollbar Under Filters ─────────────────
class _CustomHorizontalScrollBar extends StatefulWidget {
  final ScrollController controller;
  final bool isDark;

  const _CustomHorizontalScrollBar({
    required this.controller,
    required this.isDark,
  });

  @override
  State<_CustomHorizontalScrollBar> createState() => _CustomHorizontalScrollBarState();
}

class _CustomHorizontalScrollBarState extends State<_CustomHorizontalScrollBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _CustomHorizontalScrollBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.hasClients ||
            !widget.controller.position.hasContentDimensions ||
            widget.controller.position.maxScrollExtent <= 0) {
          return const SizedBox.shrink();
        }

        final pos = widget.controller.position;
        final maxScroll = pos.maxScrollExtent;
        final currentScroll = pos.pixels.clamp(0.0, maxScroll);
        final progress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
        final viewportFraction = (pos.viewportDimension /
                (pos.maxScrollExtent + pos.viewportDimension))
            .clamp(0.15, 0.85);

        final trackColor = widget.isDark
            ? AppColors.darkBorder.withValues(alpha: 0.5)
            : const Color(0xFFE2E8F0);
        final thumbColor = widget.isDark
            ? const Color(0xFFE2E8F0)
            : const Color(0xFF334155);

        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final thumbWidth =
                  (trackWidth * viewportFraction).clamp(36.0, trackWidth);
              final maxThumbOffset = trackWidth - thumbWidth;
              final thumbOffset = maxThumbOffset * progress;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  if (maxThumbOffset <= 0) return;
                  final deltaFraction = details.primaryDelta! / maxThumbOffset;
                  final newScroll = (widget.controller.offset +
                          deltaFraction * maxScroll)
                      .clamp(0.0, maxScroll);
                  widget.controller.jumpTo(newScroll);
                },
                child: Container(
                  height: 10,
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Thin Track Line
                      Container(
                        height: 3,
                        width: trackWidth,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                      // Thin Thumb Line
                      Positioned(
                        left: thumbOffset,
                        child: Container(
                          height: 3,
                          width: thumbWidth,
                          decoration: BoxDecoration(
                            color: thumbColor,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
