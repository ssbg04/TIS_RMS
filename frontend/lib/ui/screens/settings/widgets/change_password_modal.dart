import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/dialogs/error_dialog.dart';
import '../../../shared/dialogs/success_dialog.dart';
import '../../../shared/inputs/custom_text_field.dart';
import '../../../shared/modals/custom_modal.dart';

class ChangePasswordModal extends ConsumerStatefulWidget {
  const ChangePasswordModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ChangePasswordModal(),
    );
  }

  @override
  ConsumerState<ChangePasswordModal> createState() =>
      _ChangePasswordModalState();
}

class _ChangePasswordModalState extends ConsumerState<ChangePasswordModal> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isCurrentObscure = true;
  bool _isNewObscure = true;
  bool _isConfirmObscure = true;
  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      showErrorDialog(context, 'Validation Error', 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.changePassword(
        currentPassword: _currentPassCtrl.text,
        newPassword: _newPassCtrl.text,
        confirmPassword: _confirmPassCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showSuccessDialog(context, message: 'Password changed successfully!');
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(
        context,
        'Change Password Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return CustomModal(
      title: 'Change Password',
      icon: Icons.lock_outline,
      maxWidth: 480,
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your current password and a new secure password.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.p16),

            // 1. Current Password
            CustomTextField(
              hintText: 'Current Password',
              prefixIcon: Icons.key_outlined,
              controller: _currentPassCtrl,
              isPassword: true,
              obscureText: _isCurrentObscure,
              onToggleVisibility: () =>
                  setState(() => _isCurrentObscure = !_isCurrentObscure),
              validator: (v) =>
                  AppValidators.validateRequired(v, 'Current Password'),
            ),
            const SizedBox(height: AppSizes.p16),

            // 2. New Password
            CustomTextField(
              hintText: 'New Password',
              prefixIcon: Icons.lock_outline,
              controller: _newPassCtrl,
              isPassword: true,
              obscureText: _isNewObscure,
              onToggleVisibility: () =>
                  setState(() => _isNewObscure = !_isNewObscure),
              onChanged: (v) {
                if (_confirmPassCtrl.text.isNotEmpty) {
                  _formKey.currentState?.validate();
                }
              },
              validator: AppValidators.validatePasswordComplexity,
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
                        backgroundColor: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade200,
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
            const SizedBox(height: AppSizes.p16),

            // 3. Confirm New Password
            CustomTextField(
              hintText: 'Confirm New Password',
              prefixIcon: Icons.lock_outline,
              controller: _confirmPassCtrl,
              isPassword: true,
              obscureText: _isConfirmObscure,
              onToggleVisibility: () =>
                  setState(() => _isConfirmObscure = !_isConfirmObscure),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final req = AppValidators.validateRequired(
                  v,
                  'Confirm Password',
                );
                if (req != null) return req;
                if (v != _newPassCtrl.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSizes.p24),

            // Actions
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: 'UPDATE PASSWORD',
                    isLoading: _isLoading,
                    onPressed: _handleSubmit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: PrimaryButton(
                      label: 'UPDATE PASSWORD',
                      isLoading: _isLoading,
                      onPressed: _handleSubmit,
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
