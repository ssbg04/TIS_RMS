import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../layouts/windows_sidebar_layout.dart';
import '../../layouts/android_bottom_nav_layout.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both username and password.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await ref.read(authProvider.notifier).login(
      _usernameController.text.trim(),
      _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      final user = ref.read(authProvider).value;
      final isDesktop = MediaQuery.of(context).size.width >= 800;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isDesktop
              ? WindowsSidebarLayout(userRole: user!.role)
              : AndroidBottomNavLayout(userRole: user!.role),
        ),
      );
    } else {
      final error = ref.read(authProvider).error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        onSuccess: (msg) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            // Desktop: Split Layout
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    color: AppColors.primaryGreen,
                    padding: const EdgeInsets.all(AppSizes.p48),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/logo.png', width: 220, height: 220),
                          const SizedBox(height: AppSizes.p24),
                          const Text('TIS RMS', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0)),
                          const Text('Tiaong, Quezon', style: TextStyle(fontSize: 18, color: Colors.white70, letterSpacing: 1.0)),
                          const SizedBox(height: AppSizes.p32),
                          const Text('Record Management System', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSizes.p8),
                          const Text('Secure Academic Records Database System', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _buildLoginForm(),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile: Stacked Layout
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/logo.png', width: 120, height: 120),
                      const SizedBox(height: AppSizes.p24),
                      const Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      const SizedBox(height: AppSizes.p8),
                      const Text('Login to your account', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      const SizedBox(height: AppSizes.p48),
                      _buildLoginForm(),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildLoginForm() {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomTextField(
          hintText: 'Username',
          prefixIcon: Icons.person_outline,
          controller: _usernameController,
        ),
        const SizedBox(height: AppSizes.p16),
        CustomTextField(
          hintText: 'Password',
          prefixIcon: Icons.lock_outline,
          controller: _passwordController,
          isPassword: true,
          obscureText: _obscurePassword,
          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: AppSizes.p8),

        // Remember Me + Forgot Password row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                ),
                const Text('Remember Me', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
            ),
          ],
        ),

        const SizedBox(height: AppSizes.p16),
        PrimaryButton(
          label: 'LOGIN',
          isLoading: isLoading,
          onPressed: _handleLogin,
        ),
      ],
    );
  }
}

// ================================================================
// FORGOT PASSWORD DIALOG
// ================================================================
class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  final void Function(String message) onSuccess;
  const _ForgotPasswordDialog({required this.onSuccess});

  @override
  ConsumerState<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  final _usernameCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final username = _usernameCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (username.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.requestPasswordReset(
        username: username,
        newPassword: newPass,
        confirmPassword: confirmPass,
      );
      if (mounted) {
        widget.onSuccess('Reset request submitted. Awaiting Super Admin approval.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  const Icon(Icons.lock_reset, color: AppColors.primaryGreen),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Forgot Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Admin and Teacher accounts only. Your request will be reviewed by the Super Admin.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Divider(height: 28),

              CustomTextField(hintText: 'Your Username', prefixIcon: Icons.person_outline, controller: _usernameCtrl),
              const SizedBox(height: AppSizes.p12),
              CustomTextField(
                hintText: 'New Password',
                prefixIcon: Icons.lock_outline,
                controller: _newPassCtrl,
                isPassword: true,
                obscureText: _obscureNew,
                onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: AppSizes.p12),
              CustomTextField(
                hintText: 'Confirm New Password',
                prefixIcon: Icons.lock_outline,
                controller: _confirmPassCtrl,
                isPassword: true,
                obscureText: _obscureConfirm,
                onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: AppSizes.p24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: PrimaryButton(
                      label: 'SUBMIT REQUEST',
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