import 'dart:ui';
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
import '../../providers/users_provider.dart';
import '../../providers/auth_provider.dart';

// --- NEW IMPORTS FOR CUSTOM DIALOGS ---
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/modals/custom_modal.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'admin', 'teacher'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      result = result.where((u) =>
        isFuzzyMatch(u.username.toLowerCase(), _searchQuery) ||
        isFuzzyMatch(u.fullName.toLowerCase(), _searchQuery) ||
        isFuzzyMatch(u.role.toLowerCase(), _searchQuery)
      ).toList();
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
      await ref.read(usersProvider.notifier).resetPassword(user.id, adminPassword: password);
      if (!mounted) return;
      
      showSuccessDialog(
        context, 
        title: 'Password Reset',
        message: 'Password for "${user.username}" reset to "changeme123".'
      );
    } catch (e) {
      if (!mounted) return;
      
      showErrorDialog(context, 'Reset Failed',  e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _confirmDelete(SystemUser user) async {
    // Show our new custom delete dialog that collects Reason and Password
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _DeleteConfirmationDialog(user: user),
    );

    if (result == null || !mounted) return;

    try {
      // ✅ Note: You will need to update `usersProvider.deleteUser` to accept these new parameters!
      await ref.read(usersProvider.notifier).deleteUser(
        user.id,
        reason: result['reason']!,
        password: result['password']!,
      );
      
      if (!mounted) return;
      
      // ✅ Replaced SnackBar with Success Dialog
      showSuccessDialog(
        context, 
        title: 'User Deleted',
        message: 'User "${user.username}" was permanently deleted.'
      );
    } catch (e) {
      if (!mounted) return;
      
      // ✅ Replaced SnackBar with Error Dialog
      showErrorDialog(
        context, 
         'Deletion Failed', 
         e.toString().replaceAll('Exception: ', '')
      );
    }
  }

  void _openModal({SystemUser? user}) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditUserModal(user: user),
    );
  }

  void _showUserDetailModal(SystemUser user) {
    final currentUser = ref.watch(authProvider).value;
    
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
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
                        child: Text(user.initials, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _roleColor(user.role))),
                      ),
                      const SizedBox(width: AppSizes.p16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('@${user.username}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
                          Navigator.of(context).pop();
                          _openModal(user: user);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_reset, size: 16),
                        label: const Text('Reset Pass'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _confirmResetPassword(user);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (user.id != currentUser?.id)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _confirmDelete(user);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  _detailRow('Access Role', user.role.toUpperCase().replaceAll('_', ' ')),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow('Date Joined', user.createdAt?.split('T').first ?? '—'),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow('Email', user.email?.isNotEmpty == true ? user.email! : '—'),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow('Phone', user.phone?.isNotEmpty == true ? user.phone! : '—'),
                  const SizedBox(height: AppSizes.p16),
                  _detailRow('Added By', user.addedByName != null ? '${user.addedByName} (@${user.addedByUsername})' : 'System'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildAnimatedFilter(String label, String value, int count) {
    final isSelected = _roleFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _roleFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primaryGreen.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
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
              const SizedBox(height: AppSizes.p16),
              Expanded(
                child: usersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildAnimatedFilter('All', 'all', users.length),
                              _buildAnimatedFilter('Admin', 'admin', users.where((u) => u.role == 'admin').length),
                              _buildAnimatedFilter('Teacher', 'teacher', users.where((u) => u.role == 'teacher').length),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.p16),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _handleRefresh,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 800) {
                                  return _buildDesktopTable(filtered);
                                } else {
                                  return _buildMobileList(filtered);
                                }
                              },
                            ),
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



  Widget _buildHeader(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('User Management',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Manage system accounts and access roles.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: AppSizes.p16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: AppSearchBar(
                  hint: 'Search by username, name or role...',
                  controller: _searchController,
                  maxWidth: double.infinity,
                ),
              ),

            ],
          ),
        ),
      ],
    );
  }



  Widget _buildDesktopTable(List<SystemUser> users) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(AppColors.primaryGreen.withValues(alpha: 0.05)),
            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            columnSpacing: 24,
            dataRowMaxHeight: 65,
            dataRowMinHeight: 50,
            showBottomBorder: true,
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Username')),
              DataColumn(label: Text('Access Role')),
              DataColumn(label: Text('Contact')),
              DataColumn(label: SizedBox.shrink()), // Trailing icon
            ],
            rows: users.isEmpty
                ? [const DataRow(cells: [
                    DataCell(Text('No users found.')), DataCell(Text('')),
                    DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                  ])]
                : users.map((user) => DataRow(
                    onSelectChanged: (_) => _showUserDetailModal(user),
                    cells: [
                      DataCell(
                        Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
                            child: Text(user.initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _roleColor(user.role))),
                          ),
                          const SizedBox(width: 12),
                          Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ]),
                      ),
                      DataCell(Text('@${user.username}', style: const TextStyle(color: AppColors.textSecondary))),
                      DataCell(_buildRoleChip(user.role)),
                      DataCell(Text(user.email ?? user.phone ?? '—', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      const DataCell(Align(alignment: Alignment.centerRight, child: Icon(Icons.chevron_right, color: Colors.grey))),
                    ],
                  )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<SystemUser> users) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found.', style: TextStyle(color: AppColors.textSecondary)));
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
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
                  child: Text(user.initials, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _roleColor(user.role))),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildRoleChip(user.role),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('@${user.username}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      if (user.email != null || user.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [if (user.email != null) user.email!, if (user.phone != null) user.phone!].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(role.toUpperCase().replaceAll('_', ' '),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
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

  @override
  ConsumerState<AddEditUserModal> createState() => _AddEditUserModalState();
}

class _AddEditUserModalState extends ConsumerState<AddEditUserModal> {
  final _formKey = GlobalKey<FormState>();
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
    for (final c in [_usernameCtrl, _firstNameCtrl, _middleNameCtrl, _lastNameCtrl, _extCtrl, _emailCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
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
        Navigator.of(context).pop();
        
        // ✅ Replaced SnackBar with Success Dialog
        showSuccessDialog(context, title: 'User Updated', message: 'User updated successfully!');
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
        Navigator.of(context).pop();
        _showCredentialsDialog(context, username: username, tempPassword: tempPassword);
      }
    } catch (e) {
      if (!mounted) return;
      
      // ✅ Replaced SnackBar with Error Dialog
      showErrorDialog(
        context, 
         'Error', 
         e.toString().replaceAll('Exception: ', '')
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCredentialsDialog(BuildContext ctx, {required String username, required String tempPassword}) {
    bool copied = false;
    showDialog(
      context: ctx,
      barrierDismissible: false, 
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
          title: const Text('User Created!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚠️ Copy and share these credentials now. The temporary password will not be shown again.',
                style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600),
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
                    foregroundColor: copied ? AppColors.success : AppColors.primaryGreen,
                    side: BorderSide(color: copied ? AppColors.success : AppColors.primaryGreen),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'Username: $username\nTemporary Password: $tempPassword',
                    ));
                    setDialogState(() => copied = true);
                  },
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('DONE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialRow(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryGreen.withValues(alpha: 0.07) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? AppColors.primaryGreen.withValues(alpha: 0.3) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: highlight ? AppColors.primaryGreen : AppColors.textPrimary, letterSpacing: 0.5)),
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
    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(_isEdit ? Icons.edit : Icons.person_add, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          _isEdit ? 'Edit System User' : 'Create New User',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ]),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(height: 28),

                  // Name fields
                  _field('First Name', Icons.badge, _firstNameCtrl, required: true),
                  const SizedBox(height: AppSizes.p12),
                  _field('Middle Name', Icons.badge, _middleNameCtrl),
                  const SizedBox(height: AppSizes.p12),
                  _field('Last Name', Icons.badge, _lastNameCtrl, required: true),
                  const SizedBox(height: AppSizes.p12),
                  _field('Ext. (Jr, Sr, III)', Icons.text_fields, _extCtrl),
                  const SizedBox(height: AppSizes.p12),

                  // Username
                  _field('Username', Icons.person, _usernameCtrl, required: !_isEdit, readOnly: _isEdit),
                  const SizedBox(height: AppSizes.p12),

                  // Role dropdown
                  if (_isEdit && widget.user?.id == currentUser?.id)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.shield, color: _roleColor(widget.user!.role), size: 20),
                        const SizedBox(width: 12),
                        Text(widget.user!.role.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: _roleColor(widget.user!.role))),
                        const SizedBox(width: 8),
                        const Icon(Icons.lock, color: Colors.grey, size: 14),
                        const SizedBox(width: 4),
                        const Text('(Your own role cannot be changed)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.shield_outlined, color: AppColors.textSecondary)),
                      items: const [
                        DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                  const SizedBox(height: AppSizes.p12),

                  // Contact
                  _field('Email Address', Icons.email_outlined, _emailCtrl, validator: AppValidators.validateEmail),
                  const SizedBox(height: AppSizes.p12),
                  _field('Phone Number (Starts with 09)', Icons.phone_outlined, _phoneCtrl, validator: AppValidators.validatePhone),
                  const SizedBox(height: AppSizes.p12),

                  if (!_isEdit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.auto_awesome, color: AppColors.primaryGreen, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A secure temporary password will be auto-generated and shown once after creation.',
                            style: TextStyle(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),

                  const SizedBox(height: AppSizes.p12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                      const SizedBox(width: AppSizes.p16),
                      SizedBox(
                        width: 150,
                        child: PrimaryButton(
                          label: _isEdit ? 'UPDATE' : 'CREATE',
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
        ),
      ),
    );
  }

  Widget _field(String hint, IconData icon, TextEditingController ctrl, {bool required = false, bool readOnly = false, String? Function(String?)? validator}) {
    return CustomTextField(
      hintText: hint,
      prefixIcon: icon,
      controller: ctrl,
      readOnly: readOnly,
      validator: validator ?? (required ? (v) => AppValidators.validateRequired(v, hint) : null),
    );
  }
}

// ============================================================
// NEW: CUSTOM DELETE CONFIRMATION DIALOG 
// ============================================================
class _DeleteConfirmationDialog extends StatefulWidget {
  final SystemUser user;
  const _DeleteConfirmationDialog({required this.user});

  @override
  State<_DeleteConfirmationDialog> createState() => _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  final _reasonCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (reason.isEmpty || password.isEmpty) {
      showErrorDialog(
        context, 
        'Missing Fields', 
        'You must provide a reason and confirm your password to delete a user.'
      );
      return;
    }

    // Return the collected reason and password back to the _confirmDelete handler
    Navigator.pop(context, {
      'reason': reason,
      'password': password,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
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
                  const Icon(Icons.delete_forever, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delete @${widget.user.username}?',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This action is irreversible. For security auditing, please provide a reason and confirm using your admin password.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Divider(height: 28),
              
              // 1. Reason Field
              CustomTextField(
                hintText: 'Reason for deletion',
                prefixIcon: Icons.warning_amber_rounded,
                controller: _reasonCtrl,
              ),
              const SizedBox(height: 12),
              
              // 2. Admin Password Field
              CustomTextField(
                hintText: 'Your Admin Password',
                prefixIcon: Icons.lock_outline,
                controller: _passwordCtrl,
                isPassword: true,
                obscureText: _obscurePassword,
                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                    ),
                    onPressed: _submit,
                    child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
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
// CUSTOM RESET PASSWORD CONFIRMATION DIALOG
// ============================================================
class _ResetPasswordConfirmationDialog extends StatefulWidget {
  final SystemUser user;
  const _ResetPasswordConfirmationDialog({required this.user});

  @override
  State<_ResetPasswordConfirmationDialog> createState() => _ResetPasswordConfirmationDialogState();
}

class _ResetPasswordConfirmationDialogState extends State<_ResetPasswordConfirmationDialog> {
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
        'You must confirm using your admin password to reset a user\'s password.'
      );
      return;
    }

    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Reset the password for "${widget.user.username}"?\nTheir new password will be: changeme123\n\nPlease confirm using your admin password.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Divider(height: 28),
              
              CustomTextField(
                hintText: 'Your Admin Password',
                prefixIcon: Icons.lock_outline,
                controller: _passwordCtrl,
                isPassword: true,
                obscureText: _obscurePassword,
                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                    ),
                    onPressed: _submit,
                    child: const Text('RESET', style: TextStyle(fontWeight: FontWeight.bold)),
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