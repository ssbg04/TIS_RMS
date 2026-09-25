import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
import 'package:data_table_2/data_table_2.dart';

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
  ProviderSubscription<String>? _searchListener;
  String _roleFilter = 'all'; // 'all', 'admin', 'teacher'
  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(() {
      final text = _searchController.text;
      if (ref.read(userSearchQueryProvider) != text) {
        ref.read(userSearchQueryProvider.notifier).state = text;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final initialSearch = ref.read(userSearchQueryProvider);
      if (initialSearch.isNotEmpty && _searchController.text != initialSearch) {
        _searchController.text = initialSearch;
      }

      if (ref.read(activeTabProvider) == 'Users') {
        _shortcutFocusNode.requestFocus();
      }

      _searchListener = ref.listenManual<String>(userSearchQueryProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (_searchController.text != next) {
          _searchController.value = _searchController.value.copyWith(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
        if (_currentPage != 1) {
          setState(() {
            _currentPage = 1;
          });
        }
      });

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
            ref.read(userSearchQueryProvider.notifier).state = '';
            setState(() {
              _roleFilter = 'all';
              _currentPage = 1;
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
    _searchListener?.close();
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

  List<SystemUser> _filter(List<SystemUser> users, String query) {
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

    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      bool isFuzzyMatch(String text, String pattern) {
        if (pattern.isEmpty) return true;
        int j = 0;
        for (int i = 0; i < text.length && j < pattern.length; i++) {
          if (text[i] == pattern[j]) {
            j++;
          }
        }
        return j == pattern.length;
      }

      result = result.where((u) {
        final username = u.username.toLowerCase();
        final fullName = u.fullName.toLowerCase();
        final email = (u.email ?? '').toLowerCase();
        final role = u.role.toLowerCase();

        return username.contains(q) ||
            fullName.contains(q) ||
            email.contains(q) ||
            role.contains(q) ||
            isFuzzyMatch(username, q) ||
            isFuzzyMatch(fullName, q);
      }).toList();
    }
    return result;
  }

  Future<void> _handleRefresh() async {
    await ref.read(usersProvider.notifier).refresh();
  }

  Future<void> _confirmResetPassword(SystemUser user) async {
    final email = user.email?.trim() ?? '';
    final emailFormatError = AppValidators.validateEmail(email);
    if (email.isEmpty || emailFormatError != null) {
      showErrorDialog(
        context,
        'Cannot Send Reset Link',
        'User @${user.username} does not have a valid registered email address (${email.isEmpty ? "no email registered" : email}).\n\nPlease edit this user and provide a valid, active email address before sending a reset link.',
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ResetPasswordConfirmationDialog(user: user),
    );
    if (result == null || !mounted) return;

    try {
      // 1. Verify recipient email deliverability before dispatching reset link
      final validation =
          await ref.read(usersProvider.notifier).validateEmail(email);
      if (validation['valid'] == false) {
        final reason = validation['reason']?.toString() ??
            'Invalid or undeliverable email address';
        if (!mounted) return;
        showErrorDialog(
          context,
          'Email Verification Failed',
          'Cannot send password reset link: the recipient email address "$email" failed verification ($reason).\n\nPlease update the user profile with a valid email address first.',
        );
        return;
      }

      // 2. Dispatch reset link
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
    await AddEditUserModal.show(
      context,
      user: user,
      initialEditMode: user != null,
      onResetPassword: _confirmResetPassword,
      onToggleStatus: _confirmToggleStatus,
    );
  }

  void _showUserDetailModal(SystemUser user) {
    AddEditUserModal.show(
      context,
      user: user,
      initialEditMode: false,
      onResetPassword: _confirmResetPassword,
      onToggleStatus: _confirmToggleStatus,
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
    final userSearch = ref.watch(userSearchQueryProvider);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

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
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: usersAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => AppErrorState.fromError(
                        error: err,
                        onRetry: _handleRefresh,
                      ),
                      data: (users) {
                        final filtered = _filter(users, userSearch);
                        final int totalPages = (filtered.length / _itemsPerPage).ceil().clamp(1, 9999);
                        final int safeCurrentPage = _currentPage.clamp(1, totalPages);
                        final int startIndex = (safeCurrentPage - 1) * _itemsPerPage;
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
                                if (!isAndroid && !_searchFocusNode.hasFocus) ...[
                                  Tooltip(
                                    richMessage: userSearch.isNotEmpty
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
                                        userSearch.isNotEmpty ? Icons.close : Icons.search,
                                        size: 28,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : Colors.black87,
                                      ),
                                      onPressed: () {
                                        if (userSearch.isNotEmpty) {
                                          _searchController.clear();
                                          ref.read(userSearchQueryProvider.notifier).state = '';
                                        } else {
                                          _showSearchDialog(context);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _openModal(),
                                  ),
                                ],
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
                hint: 'Search by username, name, email or role...',
                controller: _searchController,
                focusNode: _searchFocusNode,
                collapsible: false,
                maxWidth: 600,
                onChanged: (val) {
                  ref.read(userSearchQueryProvider.notifier).state = val;
                },
                onSubmitted: (val) {
                  Navigator.of(context).pop();
                  ref.read(userSearchQueryProvider.notifier).state = val;
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
        child: DataTable2(
          fixedTopRows: 1,
          minWidth: 900,
          columnSpacing: 24,
          horizontalMargin: 20,
          headingRowHeight: 52,
          dataRowHeight: 65,
          showCheckboxColumn: false,
          showBottomBorder: true,
          isVerticalScrollBarVisible: true,
          isHorizontalScrollBarVisible: true,
          empty: Center(
            child: Text(
              'No users found.',
              style: TextStyle(color: textSecondary),
            ),
          ),
          headingRowColor: WidgetStateProperty.all(
            isDark
                ? Colors.white.withValues(alpha: 0.03)
                : AppColors.primaryGreen.withValues(alpha: 0.05),
          ),
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: textPrimary,
          ),
          columns: const [
            DataColumn2(
              size: ColumnSize.L,
              label: Text('Full Name'),
            ),
            DataColumn2(
              size: ColumnSize.M,
              label: Text('Username'),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: Text('Role'),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: Text('Status'),
            ),
            DataColumn2(
              size: ColumnSize.M,
              label: Text('Contact'),
            ),
            DataColumn2(
              fixedWidth: 80,
              label: Align(
                alignment: Alignment.centerRight,
                child: Text('Action'),
              ),
            ),
          ],
          rows: users
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
                          Flexible(
                            child: Text(
                              user.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        '@${user.username}',
                        overflow: TextOverflow.ellipsis,
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
                        overflow: TextOverflow.ellipsis,
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
// ADD / EDIT MODAL & USER PROFILE DETAILS (CUSTOM MODAL)
// ============================================================
class AddEditUserModal {
  static Future<bool?> show(
    BuildContext context, {
    SystemUser? user,
    bool initialEditMode = false,
    void Function(SystemUser)? onResetPassword,
    void Function(SystemUser)? onToggleStatus,
  }) {
    if (user != null) {
      return CustomModal.show<bool>(
        context: context,
        title: initialEditMode ? 'Edit User Profile' : 'User Profile Details',
        icon: initialEditMode ? Icons.edit_outlined : Icons.person_outline,
        maxWidth: 540,
        content: _UserDetailAndEditModalContent(
          user: user,
          initialEditMode: initialEditMode,
          onResetPassword: onResetPassword,
          onToggleStatus: onToggleStatus,
        ),
      );
    } else {
      return CustomModal.show<bool>(
        context: context,
        title: 'Add New User',
        icon: Icons.person_add_outlined,
        maxWidth: 540,
        content: const _AddUserModalContent(),
      );
    }
  }
}

// ------------------------------------------------------------
// USER DETAIL AND IN-PLACE EDIT MODAL CONTENT
// ------------------------------------------------------------
class _UserDetailAndEditModalContent extends ConsumerStatefulWidget {
  final SystemUser user;
  final bool initialEditMode;
  final void Function(SystemUser)? onResetPassword;
  final void Function(SystemUser)? onToggleStatus;

  const _UserDetailAndEditModalContent({
    required this.user,
    this.initialEditMode = false,
    this.onResetPassword,
    this.onToggleStatus,
  });

  @override
  ConsumerState<_UserDetailAndEditModalContent> createState() =>
      _UserDetailAndEditModalContentState();
}

class _UserDetailAndEditModalContentState
    extends ConsumerState<_UserDetailAndEditModalContent> {
  late SystemUser _currentUser;
  late bool _isEditing;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _middleNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _extCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late String _selectedRole;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _isEditing = widget.initialEditMode;
    _firstNameCtrl = TextEditingController(text: _currentUser.firstName);
    _middleNameCtrl =
        TextEditingController(text: _currentUser.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: _currentUser.lastName);
    _extCtrl = TextEditingController(text: _currentUser.extension ?? '');
    _emailCtrl = TextEditingController(text: _currentUser.email ?? '');
    _phoneCtrl = TextEditingController(text: _currentUser.phone ?? '');
    _selectedRole = _currentUser.role;
  }

  void _resetFormValues() {
    _firstNameCtrl.text = _currentUser.firstName;
    _middleNameCtrl.text = _currentUser.middleName ?? '';
    _lastNameCtrl.text = _currentUser.lastName;
    _extCtrl.text = _currentUser.extension ?? '';
    _emailCtrl.text = _currentUser.email ?? '';
    _phoneCtrl.text = _currentUser.phone ?? '';
    _selectedRole = _currentUser.role;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _extCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startEditing() {
    HapticService.light();
    setState(() {
      _resetFormValues();
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    HapticService.light();
    if (widget.initialEditMode) {
      Navigator.of(context).pop(false);
    } else {
      setState(() {
        _resetFormValues();
        _isEditing = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty && email != _currentUser.email) {
        final validation =
            await ref.read(usersProvider.notifier).validateEmail(email);
        if (validation['valid'] == false) {
          final reason = validation['reason']?.toString() ??
              'Invalid or undeliverable email address';
          if (!mounted) return;
          showErrorDialog(
            context,
            'Invalid Email Address',
            'The email address "$email" failed verification: $reason.\nPlease enter a valid, active email address.',
          );
          return;
        }
      }

      final notifier = ref.read(usersProvider.notifier);
      await notifier.updateUser(
        id: _currentUser.id,
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        extension: _extCtrl.text.trim(),
        role: _selectedRole,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;

      final updatedUser = _currentUser.copyWith(
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        extension: _extCtrl.text.trim(),
        role: _selectedRole,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
      });

      HapticService.success();
      showSuccessDialog(
        context,
        title: 'User Updated',
        message: 'User updated successfully!',
      );

      if (widget.initialEditMode) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Update Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _roleColor(String role) {
    if (role == 'admin') return Colors.blue;
    return AppColors.primaryGreen;
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final headerBg = isDark ? AppColors.darkSurface2 : Colors.grey.shade50;
    final borderCol = isDark ? AppColors.darkBorder : Colors.grey.shade200;
    final roleCol = _roleColor(_isEditing ? _selectedRole : _currentUser.role);
    final canToggle = _currentUser.id != currentUser?.id;
    final isSelf = _currentUser.id == currentUser?.id;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android ||
        MediaQuery.of(context).size.width < 500;

    return SingleChildScrollView(
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
                            _currentUser.initials,
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
                              color: _currentUser.isActive
                                  ? AppColors.success
                                  : Colors.grey,
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
                          Text(
                            _currentUser.fullName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '@${_currentUser.username}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              _buildRoleChip(
                                _isEditing ? _selectedRole : _currentUser.role,
                              ),
                              _buildStatusChip(_currentUser.isActive),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_isEditing) ...[
                  const SizedBox(height: AppSizes.p12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Editing User Profile',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.primaryGreen,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _cancelEditing,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Discard',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSizes.p16),
                  // Responsive Action Buttons Toolbar for Android & Windows
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 420;

                      Widget buildActionButton({
                        required IconData icon,
                        required String label,
                        required VoidCallback onTap,
                        bool isDestructive = false,
                        bool isPrimary = false,
                      }) {
                        final fgColor = isPrimary
                            ? Colors.white
                            : (isDestructive
                                ? (isDark
                                    ? Colors.red.shade300
                                    : Colors.red.shade700)
                                : textPrimary);
                        final border = isPrimary
                            ? AppColors.primaryGreen
                            : (isDestructive
                                ? (isDark
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : Colors.red.shade200)
                                : (isDark
                                    ? AppColors.darkBorder
                                    : Colors.grey.shade300));
                        final bg = isPrimary
                            ? AppColors.primaryGreen
                            : (isDark
                                ? AppColors.darkSurfaceCard
                                : Colors.white);

                        return Material(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 6 : 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: border, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon,
                                      size: isCompact ? 15 : 16,
                                      color: fgColor),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: fgColor,
                                        fontSize: isCompact ? 11.5 : 12.5,
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
                        onTap: _startEditing,
                      );

                      final resetBtn = buildActionButton(
                        icon: Icons.lock_reset_rounded,
                        label: 'Reset',
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          widget.onResetPassword?.call(_currentUser);
                        },
                      );

                      final toggleBtn = canToggle
                          ? buildActionButton(
                              icon: _currentUser.isActive
                                  ? Icons.block_rounded
                                  : Icons.check_circle_outline_rounded,
                              label: _currentUser.isActive
                                  ? 'Deactivate'
                                  : 'Activate',
                              isDestructive: _currentUser.isActive,
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).pop();
                                widget.onToggleStatus?.call(_currentUser);
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
              ],
            ),
          ),

          // Modal Body: View Details or In-Place Form
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.all(AppSizes.p20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Access Role',
                    value: _currentUser.role.toUpperCase().replaceAll('_', ' '),
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Account Status',
                    value: _currentUser.isActive
                        ? 'Active (Can login)'
                        : 'Inactive (Access blocked)',
                    valueColor: _currentUser.isActive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date Joined',
                    value: _currentUser.createdAt?.split('T').first ?? '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _currentUser.email?.isNotEmpty == true
                        ? _currentUser.email!
                        : '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: _currentUser.phone?.isNotEmpty == true
                        ? _currentUser.phone!
                        : '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    icon: Icons.person_add_outlined,
                    label: 'Added By',
                    value: _currentUser.addedByName != null
                        ? '${_currentUser.addedByName} (@${_currentUser.addedByUsername})'
                        : 'System',
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(AppSizes.p20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (isAndroid) ...[
                      _field(
                        'First Name',
                        Icons.person_outline,
                        _firstNameCtrl,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [_TitleCaseTextInputFormatter()],
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _field(
                        'Middle Name',
                        null,
                        _middleNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [_TitleCaseTextInputFormatter()],
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _field(
                        'Last Name',
                        null,
                        _lastNameCtrl,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [_TitleCaseTextInputFormatter()],
                      ),
                      const SizedBox(height: AppSizes.p12),
                      _field(
                        'Ext. (Jr, Sr, III)',
                        null,
                        _extCtrl,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [_TitleCaseTextInputFormatter()],
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _field(
                              'First Name',
                              Icons.person_outline,
                              _firstNameCtrl,
                              required: true,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [_TitleCaseTextInputFormatter()],
                            ),
                          ),
                          const SizedBox(width: AppSizes.p12),
                          Expanded(
                            flex: 2,
                            child: _field(
                              'Middle Name',
                              null,
                              _middleNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [_TitleCaseTextInputFormatter()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _field(
                              'Last Name',
                              null,
                              _lastNameCtrl,
                              required: true,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [_TitleCaseTextInputFormatter()],
                            ),
                          ),
                          const SizedBox(width: AppSizes.p12),
                          Expanded(
                            flex: 2,
                            child: _field(
                              'Ext. (Jr, Sr, III)',
                              null,
                              _extCtrl,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [_TitleCaseTextInputFormatter()],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSizes.p20),
                    Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _field(
                      'Email Address',
                      Icons.email_outlined,
                      _emailCtrl,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final email = _emailCtrl.text.trim();
                        final phone = _phoneCtrl.text.trim();
                        if (email.isEmpty && phone.isEmpty) {
                          return 'Either email or phone number is required';
                        }
                        if (v != null && v.trim().isNotEmpty) {
                          return AppValidators.validateEmail(v.trim());
                        }
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _buildEmailDomainSuggestions(
                      _emailCtrl,
                      () => setState(() {}),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _field(
                      'Phone Number (Starts with 09)',
                      Icons.phone_outlined,
                      _phoneCtrl,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final email = _emailCtrl.text.trim();
                        final phone = _phoneCtrl.text.trim();
                        if (email.isEmpty && phone.isEmpty) {
                          return 'Either email or phone number is required';
                        }
                        if (v != null && v.trim().isNotEmpty) {
                          return AppValidators.validatePhone(v.trim());
                        }
                        return null;
                      },
                      maxLength: 11,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: AppSizes.p20),
                    Text(
                      'Access Role',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildRoleDropdown(
                      currentUser: currentUser,
                      selectedRole: _selectedRole,
                      isSelf: isSelf,
                      onChanged: (val) => setState(() => _selectedRole = val),
                    ),
                    const SizedBox(height: AppSizes.p24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancelEditing,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Save',
                            isLoading: _isLoading,
                            onPressed: _handleSave,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown({
    required dynamic currentUser,
    required String selectedRole,
    required bool isSelf,
    required ValueChanged<String> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isSelf) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.shield, color: _roleColor(selectedRole), size: 20),
            const SizedBox(width: 12),
            Text(
              selectedRole.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _roleColor(selectedRole),
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
      isExpanded: true,
      initialValue: selectedRole,
      decoration: const InputDecoration(
        labelText: 'Role',
        prefixIcon: Icon(Icons.shield_outlined, color: AppColors.textSecondary),
      ),
      items: const [
        DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
        DropdownMenuItem(value: 'admin', child: Text('Admin')),
      ],
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}

// ------------------------------------------------------------
// ADD USER MODAL CONTENT (SINGLE CUSTOM MODAL FORM)
// ------------------------------------------------------------
class _AddUserModalContent extends ConsumerStatefulWidget {
  const _AddUserModalContent();

  @override
  ConsumerState<_AddUserModalContent> createState() =>
      _AddUserModalContentState();
}

class _AddUserModalContentState extends ConsumerState<_AddUserModalContent> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _extCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRole = 'teacher';
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _extCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty) {
        final validation =
            await ref.read(usersProvider.notifier).validateEmail(email);
        if (validation['valid'] == false) {
          final reason = validation['reason']?.toString() ??
              'Invalid or undeliverable email address';
          if (!mounted) return;
          showErrorDialog(
            context,
            'Invalid Email Address',
            'The email address "$email" failed verification: $reason.\nPlease enter a valid, active email address.',
          );
          return;
        }
      }

      final username = _usernameCtrl.text.trim();
      await ref.read(usersProvider.notifier).createUser(
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
      _showUserCreatedSuccessDialog(
        context,
        username: username,
        email: _emailCtrl.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Create User Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android ||
        MediaQuery.of(context).size.width < 500;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSizes.p12),
            if (isAndroid) ...[
              _field(
                'First Name',
                Icons.person_outline,
                _firstNameCtrl,
                required: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [_TitleCaseTextInputFormatter()],
              ),
              const SizedBox(height: AppSizes.p12),
              _field(
                'Middle Name',
                null,
                _middleNameCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [_TitleCaseTextInputFormatter()],
              ),
              const SizedBox(height: AppSizes.p12),
              _field(
                'Last Name',
                null,
                _lastNameCtrl,
                required: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [_TitleCaseTextInputFormatter()],
              ),
              const SizedBox(height: AppSizes.p12),
              _field(
                'Ext. (Jr, Sr, III)',
                null,
                _extCtrl,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [_TitleCaseTextInputFormatter()],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(
                      'First Name',
                      Icons.person_outline,
                      _firstNameCtrl,
                      required: true,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_TitleCaseTextInputFormatter()],
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    flex: 2,
                    child: _field(
                      'Middle Name',
                      null,
                      _middleNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_TitleCaseTextInputFormatter()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(
                      'Last Name',
                      null,
                      _lastNameCtrl,
                      required: true,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_TitleCaseTextInputFormatter()],
                    ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    flex: 2,
                    child: _field(
                      'Ext. (Jr, Sr, III)',
                      null,
                      _extCtrl,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [_TitleCaseTextInputFormatter()],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSizes.p20),
            Text(
              'Account Details',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSizes.p12),
            _field(
              'Username',
              Icons.alternate_email_rounded,
              _usernameCtrl,
              required: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSizes.p12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(
                  Icons.shield_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: AppSizes.p20),
            Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSizes.p12),
            _field(
              'Email Address',
              Icons.email_outlined,
              _emailCtrl,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final email = _emailCtrl.text.trim();
                final phone = _phoneCtrl.text.trim();
                if (email.isEmpty && phone.isEmpty) {
                  return 'Either email or phone number is required';
                }
                if (v != null && v.trim().isNotEmpty) {
                  return AppValidators.validateEmail(v.trim());
                }
                return null;
              },
              keyboardType: TextInputType.emailAddress,
            ),
            _buildEmailDomainSuggestions(
              _emailCtrl,
              () => setState(() {}),
            ),
            const SizedBox(height: AppSizes.p12),
            _field(
              'Phone Number (Starts with 09)',
              Icons.phone_outlined,
              _phoneCtrl,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final email = _emailCtrl.text.trim();
                final phone = _phoneCtrl.text.trim();
                if (email.isEmpty && phone.isEmpty) {
                  return 'Either email or phone number is required';
                }
                if (v != null && v.trim().isNotEmpty) {
                  return AppValidators.validatePhone(v.trim());
                }
                return null;
              },
              maxLength: 11,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: AppSizes.p16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryGreen,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Temporary login credentials and account access instructions will be sent to the user\'s email.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'CREATE USER',
                    isLoading: _isLoading,
                    onPressed: _handleCreate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// SHARED FORM FIELD HELPERS
// ------------------------------------------------------------
Widget _field(
  String hint,
  IconData? icon,
  TextEditingController ctrl, {
  bool required = false,
  bool readOnly = false,
  String? Function(String?)? validator,
  TextCapitalization textCapitalization = TextCapitalization.none,
  int? maxLength,
  String? counterText,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  void Function(String)? onChanged,
}) {
  return CustomTextField(
    hintText: hint,
    prefixIcon: icon,
    controller: ctrl,
    readOnly: readOnly,
    onChanged: onChanged,
    validator: validator ??
        (required ? (v) => AppValidators.validateRequired(v, hint) : null),
    textCapitalization: textCapitalization,
    maxLength: maxLength,
    counterText: counterText ?? (maxLength != null ? '' : null),
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
  );
}

Widget _buildEmailDomainSuggestions(
  TextEditingController emailCtrl,
  VoidCallback onChanged,
) {
  return ValueListenableBuilder<TextEditingValue>(
    valueListenable: emailCtrl,
    builder: (context, value, child) {
      final text = value.text;
      if (!text.contains('@')) return const SizedBox.shrink();

      final parts = text.split('@');
      final domainPart = parts.length > 1 ? parts[1].toLowerCase() : '';

      const commonDomains = [
        'gmail.com',
        'yahoo.com',
        'outlook.com',
        'hotmail.com',
        'deped.gov.ph',
      ];
      final suggestions = commonDomains
          .where((d) => d.startsWith(domainPart) && d != domainPart)
          .toList();

      if (suggestions.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 6.0,
          children: suggestions.map((domain) {
            return ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(
                Icons.alternate_email,
                size: 13,
                color: AppColors.primaryGreen,
              ),
              label: Text('@$domain', style: const TextStyle(fontSize: 11.5)),
              onPressed: () {
                emailCtrl.text = '${parts[0]}@$domain';
                emailCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: emailCtrl.text.length),
                );
                onChanged();
              },
            );
          }).toList(),
        ),
      );
    },
  );
}

void _showUserCreatedSuccessDialog(
  BuildContext ctx, {
  required String username,
  String? email,
}) {
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      icon: const Icon(
        Icons.check_circle,
        color: AppColors.success,
        size: 48,
      ),
      title: const Text(
        'User Created Successfully!',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _credentialRow(dialogCtx, 'Username', username),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email != null && email.isNotEmpty
                        ? 'An email with login details and instructions has been sent to $email.'
                        : 'User account created successfully for @$username.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('DONE'),
          ),
        ),
      ],
    ),
  );
}

Widget _credentialRow(
  BuildContext context,
  String label,
  String value, {
  bool highlight = false,
}) {
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
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
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
    final email = widget.user.email?.trim() ?? '';
    final emailError = AppValidators.validateEmail(email);
    if (email.isEmpty || emailError != null) {
      showErrorDialog(
        context,
        'Invalid Email Address',
        'User @${widget.user.username} does not have a valid registered email address. Please update the user profile before sending a reset link.',
      );
      return;
    }

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
    final email = widget.user.email?.trim() ?? '';
    final hasValidEmail =
        email.isNotEmpty && AppValidators.validateEmail(email) == null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
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
                if (hasValidEmail)
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
                            email.isNotEmpty
                                ? 'The registered email "$email" has an invalid email format. Please edit this user and provide a valid email before sending a reset link.'
                                : 'No email registered. Please edit this user and provide a valid email before sending a reset link.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (hasValidEmail) ...[
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
                    Flexible(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasValidEmail ? AppColors.primaryGreen : Colors.grey,
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
                        onPressed: hasValidEmail ? _submit : null,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text(
                          'SEND LINK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
