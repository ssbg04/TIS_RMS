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
import 'package:dio/dio.dart';
import '../../providers/backup_provider.dart';
import '../../shared/dialogs/info_dialog.dart';
import 'teacher_management_screen.dart';
import '../../../core/utils/date_utils.dart' as pht;
import '../../providers/reports_provider.dart';
import '../../../core/network/api_constants.dart';
import '../../providers/system_settings_provider.dart';
class TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newText = '';
    bool capitalizeNext = true;

    for (int i = 0; i < newValue.text.length; i++) {
      String char = newValue.text[i];
      if (capitalizeNext && char.trim().isNotEmpty) {
        newText += char.toUpperCase();
        capitalizeNext = false;
      } else {
        newText += char;
      }
      
      if (char == ' ' || char == '-') {
        capitalizeNext = true;
      }
    }

    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

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
          _passwordFormKey.currentState?.reset();
          _profileFormKey.currentState?.reset();
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

  bool _hasProfileChanges() {
    final user = ref.read(profileProvider).asData?.value;
    if (user == null) return false;
    
    return _firstNameCtrl.text.trim() != user.firstName ||
           _middleNameCtrl.text.trim() != (user.middleName ?? '') ||
           _lastNameCtrl.text.trim() != user.lastName ||
           _extCtrl.text.trim() != (user.extension ?? '') ||
           _phoneCtrl.text.trim() != (user.phone ?? '') ||
           _emailCtrl.text.trim() != (user.email ?? '');
  }

  void _revertProfileChanges() {
    final user = ref.read(profileProvider).asData?.value;
    if (user != null) {
      _firstNameCtrl.text = user.firstName;
      _middleNameCtrl.text = user.middleName ?? '';
      _lastNameCtrl.text = user.lastName;
      _extCtrl.text = user.extension ?? '';
      _phoneCtrl.text = user.phone ?? '';
      _emailCtrl.text = user.email ?? '';
    }
  }

  Future<bool> _promptToConfirmSave() async {
    final ctrl = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Changes'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Type "CONFIRM" to save your profile changes.'),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'CONFIRM',
                  controller: ctrl,
                  validator: (v) {
                    if (v == null || v.trim().toUpperCase() != 'CONFIRM') {
                      return 'Please type CONFIRM';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text(
                'SAVE',
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

    return result ?? false;
  }

  Future<void> _handleUpdateProfile() async {
    if (!_profileFormKey.currentState!.validate()) {
      _revertProfileChanges();
      return;
    }

    final isConfirmed = await _promptToConfirmSave();
    if (!isConfirmed) {
      _revertProfileChanges();
      return;
    }

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
      _revertProfileChanges();
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (newPass != confirm) {
      showErrorDialog(context, 'Validation Error', 'Passwords do not match.');
      return;
    }

    final currentPassword = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        bool obscure = true;
        final dialogFormKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Enter Current Password'),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please verify your current password to proceed.',
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

    if (currentPassword == null || currentPassword.isEmpty) return;

    setState(() => _isPasswordLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPass,
        confirmPassword: confirm,
      );
      if (!mounted) return;
      showSuccessDialog(context, message: 'Password changed successfully!');
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Update Failed',
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
  }

  Future<bool> _isServerMachine() async {
    try {
      final uri = Uri.tryParse(ApiConstants.baseUrl);
      if (uri == null) return false;
      final host = uri.host;
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1' ||
          host == '0.0.0.0') {
        return true;
      }
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        includeLinkLocal: true,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.address == host) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<int?> _getFreeDiskSpaceBytes(String filePath) async {
    try {
      if (Platform.isWindows) {
        final drive = filePath.substring(0, 1).toUpperCase();
        final result = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-Command',
            '(Get-PSDrive -Name "$drive").Free',
          ],
        );
        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim());
        }
      }
    } catch (_) {}
    return null;
  }

  void _showManualRestoreGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: AppColors.primaryGreen),
            SizedBox(width: 10),
            Expanded(child: Text('Manual Restore Guide')),
          ],
        ),
        content: const SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'If your backup ZIP file is too large to upload over HTTP or you want to restore directly on the server host machine, follow these simple steps:',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                SizedBox(height: 16),
                Text(
                  'Step 1: Stop the TIS RMS Server',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Close the terminal/command prompt window or service running the TIS RMS backend server.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                SizedBox(height: 12),
                Text(
                  'Step 2: Locate the Server Data Directory',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Open File Explorer and navigate to your server directory (e.g., C:\\SumbrerongBato\\tis_rms_server\\backend\\data).',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                SizedBox(height: 12),
                Text(
                  'Step 3: Extract & Overwrite Files',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Open your backup .zip file. Copy the database files (tis_rms.db, tis_rms.db-wal, tis_rms.db-shm) and the "students" folder into the backend\\data folder, replacing any existing files.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                SizedBox(height: 12),
                Text(
                  'Step 4: Restart the Server',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Start the backend server again. All restored data and uploaded student documents will be immediately available.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackup() async {
    if (!await _isServerMachine()) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Server Host Only',
        'Backup and Restore operations can only be performed from the server computer itself for data security.\n\nPlease run this action on the computer hosting the TIS RMS Server.',
      );
      return;
    }

    setState(() => _isBackupLoading = true);

    // Estimate size
    String estimatedSizeStr = 'Unknown';
    int estimatedBytes = 0;
    try {
      estimatedBytes = await ref.read(reportRepositoryProvider).getStorageUsed();
      if (estimatedBytes < 1024)
        estimatedSizeStr = '$estimatedBytes B';
      else if (estimatedBytes < 1048576)
        estimatedSizeStr = '${(estimatedBytes / 1024).toStringAsFixed(1)} KB';
      else if (estimatedBytes < 1073741824)
        estimatedSizeStr = '${(estimatedBytes / 1048576).toStringAsFixed(1)} MB';
      else
        estimatedSizeStr = '${(estimatedBytes / 1073741824).toStringAsFixed(1)} GB';
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

    String? saveResult;
    final fileName = 'tis_rms_backup_${DateTime.now().toIso8601String().split('T').first}.zip';

    if (Platform.isAndroid || Platform.isIOS) {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select folder to save backup',
      );
      if (selectedDirectory == null) return;
      saveResult = '$selectedDirectory/$fileName';
    } else {
      saveResult = await FilePicker.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
    }

    if (saveResult == null) return;

    // Check disk space before saving
    final freeBytes = await _getFreeDiskSpaceBytes(saveResult);
    if (freeBytes != null && estimatedBytes > 0 && freeBytes < (estimatedBytes * 1.1)) {
      if (!mounted) return;
      final freeMb = (freeBytes / (1024 * 1024)).toStringAsFixed(1);
      final reqMb = (estimatedBytes / (1024 * 1024)).toStringAsFixed(1);
      showErrorDialog(
        context,
        'Insufficient Disk Space',
        'You only have $freeMb MB of free space remaining on the destination drive, but the backup is estimated to require ~$reqMb MB.\n\nPlease free up disk space or save to another drive.',
      );
      return;
    }

    if (!mounted) return;
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TransferProgressDialog(
        title: 'Backing Up System Data',
        initialStatus: 'Connecting to server...',
        action: (onProgress, cancelToken) async {
          await ref.read(backupProvider.notifier).downloadBackup(
                saveResult!,
                onReceiveProgress: onProgress,
                cancelToken: cancelToken,
              );
        },
      ),
    );

    if (!mounted) return;
    if (result == true) {
      ref.invalidate(backupInfoProvider);
      showInfoDialog(
        context,
        title: 'Backup Successful',
        message: 'System data backed up to $saveResult',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.primaryGreen,
      );
    } else if (result == 'cancelled') {
      showInfoDialog(
        context,
        title: 'Backup Cancelled',
        message: 'The backup download was cancelled. No partial files were saved.',
        icon: Icons.info_outline,
      );
    } else if (result != null) {
      showErrorDialog(
        context,
        'Backup Failed',
        result.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _handleRestore() async {
    if (!await _isServerMachine()) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Server Host Only',
        'Backup and Restore operations can only be performed from the server computer itself for data security.\n\nPlease run this action on the computer hosting the TIS RMS Server.',
      );
      return;
    }

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
      type: FileType.any,
    );

    if (fileResult == null || fileResult.files.single.path == null) return;

    if (!fileResult.files.single.name.toLowerCase().endsWith('.zip')) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Invalid File',
        'Please select a valid .zip backup file.',
      );
      return;
    }

    final file = File(fileResult.files.single.path!);

    if (!mounted) return;
    final transferResult = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TransferProgressDialog(
        title: 'Restoring System Data',
        initialStatus: 'Uploading backup archive...',
        action: (onProgress, cancelToken) async {
          await ref.read(backupProvider.notifier).restoreBackup(
                file,
                onSendProgress: onProgress,
                cancelToken: cancelToken,
              );
        },
      ),
    );

    if (!mounted) return;
    if (transferResult == true) {
      ref.invalidate(backupInfoProvider);
      showInfoDialog(
        context,
        title: 'Restore Successful',
        message:
            'Database and files restored successfully.\n\nThe server has been shut down to apply the changes. Please restart the TIS RMS server manually.',
        icon: Icons.power_settings_new,
        iconColor: AppColors.warning,
      );
    } else if (transferResult == 'cancelled') {
      showInfoDialog(
        context,
        title: 'Restore Cancelled',
        message: 'The restore upload was cancelled. Your existing system data remains untouched.',
        icon: Icons.info_outline,
      );
    } else if (transferResult != null) {
      final errStr = transferResult.toString().replaceAll('Exception: ', '');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error),
              SizedBox(width: 10),
              Text('Restore Failed'),
            ],
          ),
          content: Text(
            '$errStr\n\nIf the backup file is too large to upload over HTTP, you can perform a manual restore directly on the server computer.',
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showManualRestoreGuideDialog(context);
              },
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('MANUAL RESTORE GUIDE'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
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

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        if (_hasProfileChanges()) {
          _handleUpdateProfile();
        }
      },
      child: Scaffold(
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
                        child: Form(
                          key: _profileFormKey,
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
                                  if (_isProfileLoading)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSizes.p24,
                                ),
                                child: Divider(),
                              ),
                              CustomTextField(
                                hintText: 'First Name',
                                prefixIcon: Icons.badge_outlined,
                                controller: _firstNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [TitleCaseTextInputFormatter()],
                                validator: (v) =>
                                    AppValidators.validateRequired(v, 'First Name'),
                              ),
                              const SizedBox(height: AppSizes.p16),
                              CustomTextField(
                                hintText: 'Middle Name (Optional)',
                                prefixIcon: Icons.badge_outlined,
                                controller: _middleNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [TitleCaseTextInputFormatter()],
                              ),
                              const SizedBox(height: AppSizes.p16),
                              CustomTextField(
                                hintText: 'Last Name',
                                prefixIcon: Icons.badge_outlined,
                                controller: _lastNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [TitleCaseTextInputFormatter()],
                                validator: (v) =>
                                    AppValidators.validateRequired(v, 'Last Name'),
                              ),
                              const SizedBox(height: AppSizes.p16),
                              CustomTextField(
                                hintText: 'Suffix (Optional)',
                                prefixIcon: Icons.text_format,
                                controller: _extCtrl,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [UpperCaseTextFormatter()],
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _extCtrl,
                                builder: (context, value, child) {
                                  final text = value.text.toLowerCase();
                                  final suggestions = ['Jr.', 'Sr.', 'II', 'III', 'IV'];
                                  final filtered = suggestions.where((s) => s.toLowerCase().startsWith(text) && s.toLowerCase() != text).toList();
                                  
                                  if (filtered.isEmpty) return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Wrap(
                                      spacing: 8.0,
                                      children: filtered.map((suffix) => ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(suffix, style: const TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          _extCtrl.text = suffix;
                                          _extCtrl.selection = TextSelection.collapsed(offset: suffix.length);
                                        },
                                      )).toList(),
                                    ),
                                  );
                                }
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
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _emailCtrl,
                                builder: (context, value, child) {
                                  final text = value.text;
                                  if (!text.contains('@')) return const SizedBox.shrink();
                                  
                                  final parts = text.split('@');
                                  final domainPart = parts.length > 1 ? parts[1].toLowerCase() : '';
                                  
                                  final commonDomains = ['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com'];
                                  final suggestions = commonDomains.where((d) => d.startsWith(domainPart) && d != domainPart).toList();
                                  
                                  if (suggestions.isEmpty) return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Wrap(
                                      spacing: 8.0,
                                      children: suggestions.map((domain) => ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(domain, style: const TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          final newText = '${parts[0]}@$domain';
                                          _emailCtrl.text = newText;
                                          _emailCtrl.selection = TextSelection.collapsed(offset: newText.length);
                                        },
                                      )).toList(),
                                    ),
                                  );
                                }
                              ),
                            ],
                          ),
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
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showManualRestoreGuideDialog(context),
                                    icon: const Icon(Icons.help_outline, size: 16),
                                    label: const Text(
                                      'Backup too large? View Manual Restore Guide',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.p24),

                        // ── Student Enrollment Auto-Update (Admin Only) ──
                        Consumer(
                          builder: (context, ref, _) {
                            final sysSettingsAsync = ref.watch(systemSettingsProvider);
                            final settingsMap = sysSettingsAsync.asData?.value ?? {};
                            final isAutoEnrollEnabled =
                                (settingsMap['auto_update_enrollment_from_sf'] ?? 'true') == 'true';
                            final frequency = settingsMap['auto_update_enrollment_from_sf_frequency'] ?? 'immediate';
                            final timeVal = settingsMap['auto_update_enrollment_from_sf_time'] ?? '00:00';

                            return _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome_outlined,
                                        color: AppColors.primaryGreen,
                                      ),
                                      const SizedBox(width: AppSizes.p8),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Student Enrollment Auto-Update',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Automatically extract Academic Year, Grade Level, and Section from uploaded or scanned SF10/SF9 documents to update student enrollment records.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: isAutoEnrollEnabled,
                                        activeColor: AppColors.primaryGreen,
                                        onChanged: (val) {
                                          ref
                                              .read(systemSettingsProvider.notifier)
                                              .updateSetting(
                                                'auto_update_enrollment_from_sf',
                                                val ? 'true' : 'false',
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                  if (isAutoEnrollEnabled) ...[
                                    const SizedBox(height: AppSizes.p16),
                                    const Divider(color: Colors.grey),
                                    const SizedBox(height: AppSizes.p12),
                                    const Text(
                                      'Update Frequency',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSizes.p8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Immediate',
                                          value: 'immediate',
                                          currentValue: frequency,
                                        ),
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Daily',
                                          value: 'daily',
                                          currentValue: frequency,
                                        ),
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Weekly',
                                          value: 'weekly',
                                          currentValue: frequency,
                                        ),
                                        _buildFrequencyChip(
                                          ref: ref,
                                          label: 'Monthly',
                                          value: 'monthly',
                                          currentValue: frequency,
                                        ),
                                      ],
                                    ),
                                    if (frequency != 'immediate') ...[
                                      const SizedBox(height: AppSizes.p16),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Execution Time:',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(width: 12),
                                          DropdownButton<String>(
                                            value: _validTimeValue(timeVal),
                                            underline: const SizedBox(),
                                            items: _buildTimeDropdownItems(),
                                            onChanged: (newTime) {
                                              if (newTime != null) {
                                                ref.read(systemSettingsProvider.notifier).updateSetting(
                                                  'auto_update_enrollment_from_sf_time',
                                                  newTime,
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            );
                          },
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

  Widget _buildFrequencyChip({
    required WidgetRef ref,
    required String label,
    required String value,
    required String currentValue,
  }) {
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.pageBackground,
      onSelected: (_) {
        ref.read(systemSettingsProvider.notifier).updateSetting(
          'auto_update_enrollment_from_sf_frequency',
          value,
        );
      },
    );
  }

  String _validTimeValue(String? val) {
    const validTimes = [
      '00:00', '01:00', '02:00', '03:00', '04:00', '05:00',
      '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
      '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
      '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
    ];
    if (val != null && validTimes.contains(val)) return val;
    return '00:00';
  }

  List<DropdownMenuItem<String>> _buildTimeDropdownItems() {
    const times = [
      '00:00', '01:00', '02:00', '03:00', '04:00', '05:00',
      '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
      '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
      '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
    ];
    return times.map((t) {
      final parts = t.split(':');
      final hour = int.parse(parts[0]);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final displayTime = '${displayHour.toString().padLeft(2, '0')}:00 $suffix';
      return DropdownMenuItem<String>(
        value: t,
        child: Text(displayTime, style: const TextStyle(fontSize: 14)),
      );
    }).toList();
  }
}

class _TransferProgressDialog extends StatefulWidget {
  final String title;
  final String initialStatus;
  final Future<void> Function(
    void Function(int count, int total) onProgress,
    CancelToken cancelToken,
  ) action;

  const _TransferProgressDialog({
    required this.title,
    required this.initialStatus,
    required this.action,
  });

  @override
  State<_TransferProgressDialog> createState() => _TransferProgressDialogState();
}

class _TransferProgressDialogState extends State<_TransferProgressDialog> {
  final CancelToken _cancelToken = CancelToken();
  double? _progress;
  String _statusText = '';
  String _etaText = 'Calculating ETA...';
  String _rateText = '';
  DateTime? _startTime;
  DateTime? _lastTime;

  @override
  void initState() {
    super.initState();
    _statusText = widget.initialStatus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAction();
      }
    });
  }

  void _onProgress(int count, int total) {
    if (!mounted) return;

    final now = DateTime.now();
    _startTime ??= now;
    _lastTime ??= now;

    double? p;
    String status;
    String eta = 'Calculating...';
    String rateStr = '';

    if (total > 0) {
      p = count / total;
      final mbCount = (count / (1024 * 1024)).toStringAsFixed(1);
      final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
      final pct = (p * 100).toStringAsFixed(0);
      status = '$pct% ($mbCount MB / $mbTotal MB)';

      final elapsedSec = now.difference(_startTime!).inMilliseconds / 1000.0;
      if (elapsedSec > 0.5 && count > 0) {
        final rateBytesPerSec = count / elapsedSec;
        final rateMbPerSec = (rateBytesPerSec / (1024 * 1024)).toStringAsFixed(2);
        rateStr = '$rateMbPerSec MB/s';

        final remainingBytes = total - count;
        if (rateBytesPerSec > 0) {
          final remainingSec = remainingBytes / rateBytesPerSec;
          final mins = (remainingSec / 60).floor();
          final secs = (remainingSec % 60).round();
          if (mins > 0) {
            eta = '${mins}m ${secs}s remaining';
          } else {
            eta = '${secs}s remaining';
          }
        }
      }
    } else {
      final mbCount = (count / (1024 * 1024)).toStringAsFixed(1);
      status = '$mbCount MB transferred';
    }

    setState(() {
      _progress = p;
      _statusText = status;
      _etaText = eta;
      _rateText = rateStr;
    });
  }

  Future<void> _startAction() async {
    try {
      await widget.action(_onProgress, _cancelToken);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      if (_cancelToken.isCancelled) {
        Navigator.of(context).pop('cancelled');
      } else {
        Navigator.of(context).pop(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.sync_rounded, color: AppColors.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                  backgroundColor: AppColors.inputBackground,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _rateText.isNotEmpty ? _rateText : 'Starting transfer...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    _etaText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Please do not close the window while the transfer is in progress.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              _cancelToken.cancel('User cancelled transfer');
            },
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            label: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

