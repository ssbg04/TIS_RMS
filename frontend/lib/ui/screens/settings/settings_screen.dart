import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/modals/custom_modal.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../../core/utils/validators.dart';
import 'requirements_settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../providers/backup_provider.dart';
import '../../shared/dialogs/info_dialog.dart';
import 'teacher_management_screen.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../providers/reports_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final String? userRole;
  const SettingsScreen({super.key, this.userRole});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Profile controllers
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _extCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // Password controllers
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Single toggle for all password fields
  bool _obscurePasswords = true;

  bool _isPassVisible = false;
  bool _isNewPassVisible = false;
  bool _isConfirmPassVisible = false;

  bool _isBackupLoading = false;
  bool _isRestoreLoading = false;

  int? _lastUserId;
  bool _isProfileLoading = false;
  bool _isPasswordLoading = false;
  ProviderSubscription<String>? _tabListener;

  double _passwordStrength = 0.0;
  Color _passwordStrengthColor = Colors.grey;
  String _passwordStrengthText = '';

  void _evaluatePasswordStrength() {
    final password = _newPassCtrl.text;
    double strength = 0.0;

    if (password.isNotEmpty) {
      if (password.length >= 8) strength += 0.25;
      if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
      if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
      if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) strength += 0.25;
    }

    Color color = Colors.grey;
    String text = '';
    if (password.isEmpty) {
      color = Colors.grey;
      text = '';
    } else if (strength <= 0.25) {
      color = Colors.red;
      text = 'Weak';
    } else if (strength == 0.5) {
      color = Colors.orange;
      text = 'Fair';
    } else if (strength == 0.75) {
      color = Colors.yellow.shade700;
      text = 'Good';
    } else {
      color = Colors.green;
      text = 'Strong';
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthColor = color;
      _passwordStrengthText = text;
    });
  }

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(_evaluatePasswordStrength);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabListener = ref.listenManual<String>(activeTabProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (next == 'Settings' && previous != 'Settings') {
          _newPassCtrl.clear();
          _confirmPassCtrl.clear();
          _firstNameCtrl.clear();
          _middleNameCtrl.clear();
          _lastNameCtrl.clear();
          _extCtrl.clear();
          _phoneCtrl.clear();
          _emailCtrl.clear();
          setState(() {
            _isPassVisible = false;
          });
          ref.invalidate(profileProvider);
          _lastUserId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabListener?.close();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _extCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        final dialogFormKey = GlobalKey<FormState>();
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Confirm Changes'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please enter your current password to save profile changes.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      hintText: 'Current Password',
                      prefixIcon: Icons.lock_outline,
                      controller: ctrl,
                      isPassword: true,
                      obscureText: obscure,
                      onToggleVisibility: () =>
                          setState(() => obscure = !obscure),
                      validator: (v) =>
                          AppValidators.validateRequired(v, 'Password'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (dialogFormKey.currentState!.validate()) {
                      Navigator.pop(ctx, ctrl.text);
                    }
                  },
                  child: const Text(
                    'CONFIRM',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (password == null || password.isEmpty) return;

    setState(() => _isProfileLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        extension: _extCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        currentPassword: password,
      );
      ref.invalidate(profileProvider);
      if (!mounted) return;
      showSuccessDialog(context, message: 'Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Update Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    final current = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        final dialogFormKey = GlobalKey<FormState>();
        bool obscure = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Confirm Changes'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please enter your current password to save password changes.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      hintText: 'Current Password',
                      prefixIcon: Icons.lock_outline,
                      controller: ctrl,
                      isPassword: true,
                      obscureText: obscure,
                      onToggleVisibility: () =>
                          setState(() => obscure = !obscure),
                      validator: (v) =>
                          AppValidators.validateRequired(v, 'Password'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (dialogFormKey.currentState!.validate()) {
                      Navigator.pop(ctx, ctrl.text);
                    }
                  },
                  child: const Text(
                    'CONFIRM',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (current == null || current.isEmpty) return;

    setState(() => _isPasswordLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.changePassword(
        currentPassword: current,
        newPassword: newPass,
        confirmPassword: confirm,
      );
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (!mounted) return;
      showSuccessDialog(context, message: 'Password changed successfully!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Change Password',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
  }

  Future<void> _handleBackup() async {
    setState(() => _isBackupLoading = true);

    // Estimate size
    String estimatedSizeStr = 'Unknown';
    try {
      final bytes = await ref.read(reportRepositoryProvider).getStorageUsed();
      if (bytes < 1024)
        estimatedSizeStr = '$bytes B';
      else if (bytes < 1048576)
        estimatedSizeStr = '${(bytes / 1024).toStringAsFixed(1)} KB';
      else if (bytes < 1073741824)
        estimatedSizeStr = '${(bytes / 1048576).toStringAsFixed(1)} MB';
      else
        estimatedSizeStr = '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } catch (_) {}

    setState(() => _isBackupLoading = false);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Backup'),
        content: Text(
          'Are you sure you want to backup the system data and uploaded files?\n\nEstimated ZIP size: $estimatedSizeStr',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('BACKUP'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final saveResult = await FilePicker.saveFile(
      dialogTitle: 'Save Backup',
      fileName:
          'tis_rms_backup_${DateTime.now().toIso8601String().split('T').first}.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (saveResult == null) return;

    setState(() => _isBackupLoading = true);
    try {
      await ref.read(backupProvider.notifier).downloadBackup(saveResult);
      if (!mounted) return;
      ref.invalidate(backupInfoProvider);
      showInfoDialog(
        context,
        title: 'Backup Successful',
        message: 'System data backed up to $saveResult',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.primaryGreen,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Backup Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isBackupLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Restore System Data',
          style: TextStyle(color: AppColors.error),
        ),
        content: const Text(
          'Restoring a backup will overwrite all current data and uploaded documents.\n\n'
          'The server will shut down after completion. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final fileResult = await FilePicker.pickFiles(
      dialogTitle: 'Select Backup File',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (fileResult == null || fileResult.files.single.path == null) return;

    setState(() => _isRestoreLoading = true);
    try {
      final file = File(fileResult.files.single.path!);
      await ref.read(backupProvider.notifier).restoreBackup(file);
      if (!mounted) return;
      ref.invalidate(backupInfoProvider);
      showInfoDialog(
        context,
        title: 'Restore Successful',
        message:
            'Database and files restored successfully.\n\nThe server has been shut down to apply the changes. Please restart the TIS RMS server manually.',
        icon: Icons.power_settings_new,
        iconColor: AppColors.warning,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Restore Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isRestoreLoading = false);
    }
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showEditProfileModal(BuildContext context) {
    CustomModal.show(
      context: context,
      title: 'Edit Profile Details',
      icon: Icons.person_outline,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: Form(
                    key: _profileFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomTextField(
                          hintText: 'First Name',
                          prefixIcon: Icons.badge_outlined,
                          controller: _firstNameCtrl,
                          validator: (v) =>
                              AppValidators.validateRequired(v, 'First Name'),
                        ),
                        const SizedBox(height: AppSizes.p16),
                        CustomTextField(
                          hintText: 'Middle Name',
                          prefixIcon: Icons.badge_outlined,
                          controller: _middleNameCtrl,
                        ),
                        const SizedBox(height: AppSizes.p16),
                        CustomTextField(
                          hintText: 'Last Name',
                          prefixIcon: Icons.badge_outlined,
                          controller: _lastNameCtrl,
                          validator: (v) =>
                              AppValidators.validateRequired(v, 'Last Name'),
                        ),
                        const SizedBox(height: AppSizes.p16),
                        CustomTextField(
                          hintText: 'Ext. (Jr)',
                          prefixIcon: Icons.text_format,
                          controller: _extCtrl,
                        ),
                        const SizedBox(height: AppSizes.p16),
                        CustomTextField(
                          hintText: 'Phone Number (Starts with 09)',
                          prefixIcon: Icons.phone_outlined,
                          controller: _phoneCtrl,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          keyboardType: TextInputType.phone,
                          validator: AppValidators.validatePhone,
                        ),
                        const SizedBox(height: AppSizes.p16),
                        CustomTextField(
                          hintText: 'Email Address',
                          prefixIcon: Icons.email_outlined,
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          validator: AppValidators.validateEmail,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p24,
                  vertical: AppSizes.p16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.p16),
                    SizedBox(
                      width: 120,
                      child: PrimaryButton(
                        label: 'SAVE',
                        isLoading: _isProfileLoading,
                        onPressed: () async {
                          if (!_profileFormKey.currentState!.validate()) return;
                          Navigator.pop(context);
                          await _handleUpdateProfile();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (user) {
            if (_lastUserId != user.id) {
              Future.microtask(() {
                if (mounted) {
                  _firstNameCtrl.text = user.firstName;
                  _middleNameCtrl.text = user.middleName ?? '';
                  _lastNameCtrl.text = user.lastName;
                  _extCtrl.text = user.extension ?? '';
                  _phoneCtrl.text = user.phone ?? '';
                  _emailCtrl.text = user.email ?? '';
                  setState(() => _lastUserId = user.id);
                }
              });
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text(
                        'Account Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.p8),
                      const Text(
                        'Manage your profile information and security settings.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.p32),

                      // ── Profile Card ──────────────────────────────────────
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: AppColors.primaryGreen,
                                  child: Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Profile Details',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Role: ${user.role.toUpperCase().replaceAll('_', ' ')}',
                                        style: const TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showEditProfileModal(context),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Edit'),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSizes.p24,
                              ),
                              child: Divider(),
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'First Name',
                                    user.firstName,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Middle Name',
                                    user.middleName?.isNotEmpty == true
                                        ? user.middleName!
                                        : '-',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Last Name',
                                    user.lastName,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Ext. (Jr)',
                                    user.extension?.isNotEmpty == true
                                        ? user.extension!
                                        : '-',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Phone Number',
                                    user.phone?.isNotEmpty == true
                                        ? user.phone!
                                        : '-',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Email Address',
                                    user.email?.isNotEmpty == true
                                        ? user.email!
                                        : '-',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSizes.p24),

                      // ── Document Requirements Settings (Super Admin Only) ──
                      if (widget.userRole == 'admin') ...[
                        _buildCard(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLarge,
                            ),
                            onTap: () => RequirementsModal.open(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.folder_copy,
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(width: AppSizes.p8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Document Requirements',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Configure required documents for JHS and SHS',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primaryGreen.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: AppColors.primaryGreen,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Define which documents are required for enrollment per grade level '
                                          '(e.g., Form 137, Birth Certificate, Good Moral). Students with missing '
                                          'required documents will appear in the Missing Docs dashboard tile.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primaryGreen,
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
                        const SizedBox(height: AppSizes.p24),
                        _buildCard(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLarge,
                            ),
                            onTap: () => TeacherManagementModal.open(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.people_alt,
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(width: AppSizes.p8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Teachers & Academic Setup',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Manage teachers, academic years, grade levels, and sections',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Set up academic years, grade levels, and sections. Assign teachers to '
                                          'their sections so they can view and manage their students\' records. '
                                          'Changes here affect enrollment options across the system.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue,
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
                        const SizedBox(height: AppSizes.p24),

                        // ── Database Management (Super Admin Only) ──
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.storage,
                                    color: AppColors.primaryGreen,
                                  ),
                                  SizedBox(width: AppSizes.p8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Database Management',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Backup or restore system data and uploaded files',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ref
                                  .watch(backupInfoProvider)
                                  .when(
                                    data: (info) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Last Backup: ${(info['lastBackup'] as String?)?.isNotEmpty == true ? pht.formatModalDate(info['lastBackup'] as String) : 'Never'}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Last Restore: ${(info['lastRestore'] as String?)?.isNotEmpty == true ? pht.formatModalDate(info['lastRestore'] as String) : 'Never'}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isBackupLoading
                                          ? null
                                          : _handleBackup,
                                      icon: _isBackupLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.download_rounded),
                                      label: const Text('Backup System Data'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        side: const BorderSide(
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _isRestoreLoading
                                          ? null
                                          : _handleRestore,
                                      icon: _isRestoreLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.upload_rounded),
                                      label: const Text('Restore System Data'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.warning,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.p24),
                      ],

                      // ── Change Password Card ──────────────────────────────
                      _buildCard(
                        child: Form(
                          key: _passwordFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.textPrimary,
                                  ),
                                  const SizedBox(width: AppSizes.p8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Change Password',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text(
                                          'Set a new password for your account.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 28),

                              CustomTextField(
                                hintText: 'New Password',
                                prefixIcon: Icons.lock_outline,
                                controller: _newPassCtrl,
                                isPassword: true,
                                obscureText: !_isPassVisible,
                                onToggleVisibility: () => setState(
                                  () => _isPassVisible = !_isPassVisible,
                                ),
                                onChanged: (v) {
                                  // Re-validate confirm field if it's not empty
                                  if (_confirmPassCtrl.text.isNotEmpty) {
                                    _passwordFormKey.currentState?.validate();
                                  }
                                },
                                validator:
                                    AppValidators.validatePasswordComplexity,
                              ),
                              if (_newPassCtrl.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: _passwordStrength,
                                          backgroundColor: Colors.grey.shade200,
                                          color: _passwordStrengthColor,
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        _passwordStrengthText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _passwordStrengthColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppSizes.p12),
                              CustomTextField(
                                hintText: 'Confirm New Password',
                                prefixIcon: Icons.lock_outline,
                                controller: _confirmPassCtrl,
                                isPassword: true,
                                obscureText: !_isPassVisible,
                                onToggleVisibility: () => setState(
                                  () => _isPassVisible = !_isPassVisible,
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (v) {
                                  final req = AppValidators.validateRequired(
                                    v,
                                    'Confirm Password',
                                  );
                                  if (req != null) return req;
                                  if (v != _newPassCtrl.text)
                                    return 'Passwords do not match';
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSizes.p24),
                              Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 200,
                                  child: PrimaryButton(
                                    label: 'UPDATE',
                                    isLoading: _isPasswordLoading,
                                    onPressed: _handleChangePassword,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSizes.p48),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}
