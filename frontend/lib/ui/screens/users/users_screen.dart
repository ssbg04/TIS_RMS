import 'package:flutter/material.dart';
import 'dart:ui';
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
import '../../providers/users_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';

// --- NEW IMPORTS FOR CUSTOM DIALOGS ---
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/modals/custom_modal.dart';
import '../../shared/modals/reset_requests_modal.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'admin', 'teacher'
  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 1;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(resetRequestsProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<SystemUser> _filter(List<SystemUser> users) {
    var result = users;
    // Apply role filter first
    if (_roleFilter != 'all') {
      result = result.where((u) => u.role == _roleFilter).toList();
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
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => _ResetPasswordConfirmationDialog(user: user),
    );
    if (password == null || !mounted) return;

    try {
      await ref
          .read(usersProvider.notifier)
          .resetPassword(user.id, adminPassword: password);
      if (!mounted) return;

      showSuccessDialog(
        context,
        title: 'Password Reset',
        message: 'Password for "${user.username}" reset to "changeme123".',
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

  Future<void> _openModal({SystemUser? user, bool fromDetails = false}) async {
    final success = await AddEditUserModal.show(context, user: user);
    if (fromDetails && user != null && mounted) {
      final users = ref.read(usersProvider).value ?? [];
      final updatedUser = users.firstWhere(
        (u) => u.id == user.id,
        orElse: () => user,
      );
      _showUserDetailModal(updatedUser);
      if (success == true) {
        showSuccessDialog(
          context,
          title: 'User Updated',
          message: 'User updated successfully!',
        );
      }
    } else if (success == true && mounted && user != null) {
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

    CustomModal.show(
      context: context,
      title: 'User Profile Details',
      icon: Icons.person_outline,
      maxWidth: 500,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with aligned actions
            Container(
              padding: const EdgeInsets.all(AppSizes.p24),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: _roleColor(
                          user.role,
                        ).withValues(alpha: 0.15),
                        child: Text(
                          user.initials,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _roleColor(user.role),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.p16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.p20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          _openModal(user: user, fromDetails: true);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_reset, size: 16),
                        label: const Text('Reset Pass'),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          _confirmResetPassword(user);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      if (user.id != currentUser?.id)
                        OutlinedButton.icon(
                          icon: Icon(
                            user.isActive ? Icons.block : Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: Text(user.isActive ? 'Deactivate' : 'Activate'),
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            _toggleStatus(user);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: user.isActive ? Colors.red : AppColors.primaryGreen,
                            side: BorderSide(color: user.isActive ? Colors.red : AppColors.primaryGreen),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Content layout line by line
            Padding(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    'Access Role',
                    user.role.toUpperCase().replaceAll('_', ' '),
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    'Date Joined',
                    user.createdAt?.split('T').first ?? '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    'Email',
                    user.email?.isNotEmpty == true ? user.email! : '—',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    'Phone',
                    user.phone?.isNotEmpty == true ? user.phone! : '—',
                  ),
                  // Status row
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    'Account Status',
                    user.isActive ? 'Active' : 'Inactive',
                  ),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow(
                    'Added By',
                    user.addedByName != null
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

  Widget _detailRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, color: textPrimary),
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
    ref.listen<String>(activeTabProvider, (previous, next) {
      if (next == 'Users' && previous != 'Users') {
        _searchController.clear();
        setState(() {
          _roleFilter = 'all';
          _searchQuery = '';
        });
      }
    });

    final usersAsync = ref.watch(usersProvider);
    final resetRequestsAsync = ref.watch(resetRequestsProvider);
    final resetCount = resetRequestsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: MediaQuery.of(context).size.width > 800 || _searchFocusNode.hasFocus
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Badge(
                    isLabelVisible: resetCount > 0,
                    label: Text(resetCount.toString()),
                    child: FloatingActionButton(
                      heroTag: 'reset_requests_fab',
                      onPressed: () => ResetRequestsModal.show(context),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.lock_clock),
                    ),
                  ),
                  FloatingActionButton(
                    heroTag: 'add_user_fab',
                    onPressed: () => _openModal(),
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, resetCount),
              const SizedBox(height: AppSizes.p24),
              Expanded(
                child: usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text('$err', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _handleRefresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (users) {
                    final filtered = _filter(users);
                    final int totalPages = (filtered.length / _itemsPerPage).ceil();
                    final int startIndex = (_currentPage - 1) * _itemsPerPage;
                    final int endIndex = (startIndex + _itemsPerPage).clamp(0, filtered.length);
                    final paginated = filtered.isEmpty ? <SystemUser>[] : filtered.sublist(startIndex, endIndex);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildAnimatedFilter('All', 'all', users.length),
                                    _buildAnimatedFilter(
                                      'Admin',
                                      'admin',
                                      users.where((u) => u.role == 'admin').length,
                                    ),
                                    _buildAnimatedFilter(
                                      'Teacher',
                                      'teacher',
                                      users.where((u) => u.role == 'teacher').length,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!_searchFocusNode.hasFocus)
                              IconButton(
                                icon: Icon(
                                  _searchQuery.isNotEmpty ? Icons.close : Icons.search,
                                  size: 28,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkTextPrimary
                                      : Colors.black87,
                                ),
                                tooltip: _searchQuery.isNotEmpty ? 'Clear Search' : 'Search Users',
                                onPressed: () {
                                  if (_searchQuery.isNotEmpty) {
                                    _searchController.clear();
                                  } else {
                                    _showSearchDialog(context);
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                         Expanded(
                           child: Stack(
                             children: [
                               Positioned.fill(
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
                               // Top Blur Overlay
                               Positioned(
                                 top: 0,
                                 left: 0,
                                 right: 0,
                                 height: 60,
                                 child: IgnorePointer(
                                   child: ShaderMask(
                                     shaderCallback: (rect) {
                                       return const LinearGradient(
                                         begin: Alignment.topCenter,
                                         end: Alignment.bottomCenter,
                                         colors: [Colors.black, Colors.transparent],
                                         stops: [0.6, 1.0],
                                       ).createShader(rect);
                                     },
                                     blendMode: BlendMode.dstIn,
                                     child: ClipRect(
                                       child: BackdropFilter(
                                         filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                         child: Container(
                                           decoration: BoxDecoration(
                                             gradient: LinearGradient(
                                               begin: Alignment.topCenter,
                                               end: Alignment.bottomCenter,
                                               colors: Theme.of(context).brightness == Brightness.dark
                                                   ? [
                                                       AppColors.darkPageBackground.withValues(alpha: 0.85),
                                                       AppColors.darkPageBackground.withValues(alpha: 0.15),
                                                     ]
                                                   : [
                                                       Colors.white.withValues(alpha: 0.85),
                                                       Colors.white.withValues(alpha: 0.15),
                                                     ],
                                             ),
                                           ),
                                         ),
                                       ),
                                     ),
                                   ),
                                 ),
                               ),
                               // Bottom Blur Overlay
                               Positioned(
                                 bottom: 0,
                                 left: 0,
                                 right: 0,
                                 height: 60,
                                 child: IgnorePointer(
                                   child: ShaderMask(
                                     shaderCallback: (rect) {
                                       return const LinearGradient(
                                         begin: Alignment.topCenter,
                                         end: Alignment.bottomCenter,
                                         colors: [Colors.transparent, Colors.black],
                                         stops: [0.0, 0.4],
                                       ).createShader(rect);
                                     },
                                     blendMode: BlendMode.dstIn,
                                     child: ClipRect(
                                       child: BackdropFilter(
                                         filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                         child: Container(
                                           decoration: BoxDecoration(
                                             gradient: LinearGradient(
                                               begin: Alignment.topCenter,
                                               end: Alignment.bottomCenter,
                                               colors: Theme.of(context).brightness == Brightness.dark
                                                   ? [
                                                       AppColors.darkPageBackground.withValues(alpha: 0.0),
                                                       AppColors.darkPageBackground.withValues(alpha: 0.85),
                                                     ]
                                                   : [
                                                       Colors.white.withValues(alpha: 0.0),
                                                       Colors.white.withValues(alpha: 0.85),
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
    );
  }

  Widget _buildHeader(BuildContext context, int resetCount) {
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: resetCount > 0,
                    label: Text(resetCount.toString()),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_clock, size: 18),
                      label: const Text(
                        'Password Requests',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => ResetRequestsModal.show(context),
                    ),
                  ),
                  const SizedBox(width: 12),
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

  void _showSearchDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight + 24),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
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
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p12),
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
              onStepTapped: (step) => setState(() => _currentStep = step),
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
        if (!text.contains('@') || text.endsWith('@')) {
          return const Iterable<String>.empty();
        }
        final parts = text.split('@');
        final prefix = parts[0];
        final query = parts.length > 1 ? parts[1] : '';
        const domains = [
          'gmail.com',
          'yahoo.com',
          'outlook.com',
          'deped.gov.ph',
        ];
        return domains
            .where((domain) => domain.startsWith(query))
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

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordCtrl.text;

    if (password.isEmpty) {
      showErrorDialog(
        context,
        'Missing Password',
        'You must confirm using your admin password to reset a user\'s password.',
      );
      return;
    }

    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_reset, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reset Password?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Reset the password for "${widget.user.username}"?\nTheir new password will be: changeme123\n\nPlease confirm using your admin password.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const Divider(height: 28),

              CustomTextField(
                hintText: 'Your Admin Password',
                prefixIcon: Icons.lock_outline,
                controller: _passwordCtrl,
                isPassword: true,
                obscureText: _obscurePassword,
                onToggleVisibility: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusMedium,
                        ),
                      ),
                    ),
                    onPressed: _submit,
                    child: const Text(
                      'RESET',
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
