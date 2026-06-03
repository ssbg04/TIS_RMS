import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../shared/inputs/custom_text_field.dart';
import '../../shared/buttons/primary_button.dart';
import '../../layouts/windows_sidebar_layout.dart';
import '../../layouts/android_bottom_nav_layout.dart';
import '../../providers/auth_provider.dart';
import 'package:frontend/ui/providers/navigation_provider.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../../core/utils/validators.dart';

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
  void initState() {
    super.initState();
    _loadRememberMe(); // Load saved credentials on startup
  }

  // --- Added: Load saved credentials for Remember Me ---
  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final isRemembered = prefs.getBool('rememberMe') ?? false;
    
    if (isRemembered) {
      setState(() {
        _rememberMe = true;
        _usernameController.text = prefs.getString('saved_username') ?? '';
        // Note: For a production app, use 'flutter_secure_storage' to save passwords securely.
        _passwordController.text = prefs.getString('saved_password') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      showErrorDialog(
        context,
        'Missing Credentials', 
        'Please enter both your username and password to continue.'
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
      // --- Added: Save or clear credentials based on checkbox ---
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('saved_username', _usernameController.text.trim());
      } else {
        await prefs.remove('rememberMe');
        await prefs.remove('saved_username');
        await prefs.remove('saved_password');
      }

      final user = ref.read(authProvider).value;
      final isDesktop = MediaQuery.of(context).size.width >= 800;
      
      // Ensure we always redirect to Dashboard after a successful login
      ref.read(activeTabProvider.notifier).setTab('Dashboard');
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isDesktop
              ? WindowsSidebarLayout(userRole: user!.role)
              : AndroidBottomNavLayout(userRole: user!.role),
        ),
      );
    } else {
      final error = ref.read(authProvider).error.toString();
      showErrorDialog(
        context,
        'Login Failed', 
        error.replaceAll('Exception: ', '')
      );
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        onSuccess: (msg) {
          Navigator.pop(ctx);
          showSuccessDialog(
            context, 
            title: 'Request Submitted', 
            message: msg, 
            ///onDismissed: () {}
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

    return CallbackShortcuts(
      bindings:{
        const SingleActivator(LogicalKeyboardKey.enter): _handleLogin,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleLogin,
      }, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomTextField(
          hintText: 'Username',
          prefixIcon: Icons.person_outline,
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: AppSizes.p16),
        CustomTextField(
          hintText: 'Password',
          prefixIcon: Icons.lock_outline,
          controller: _passwordController,
          isPassword: true,
          obscureText: _obscurePassword,
          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
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
    )
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
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePasswords = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (newPass != confirmPass) {
      showErrorDialog(context, 'Password Mismatch', 'Passwords do not match.', );
      return;
    }

    setState(() { _isLoading = true;});

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.requestPasswordReset(
        username: username,
        newPassword: newPass,
        confirmPassword: confirmPass,
      );
      if (mounted) {
        widget.onSuccess('Reset request submitted. Awaiting Admin approval.');
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Request Failed', e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
      insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_reset, color: AppColors.primaryGreen, size: isMobile ? 24 : 28),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text('Forgot Password', style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold)),
                      ),
                      if (!isMobile)
                        TextButton.icon(
                          onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
                          icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility, size: 18),
                          label: Text(_obscurePasswords ? 'Show Passwords' : 'Hide Passwords'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                        ),
                      if (isMobile)
                        IconButton(
                          onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
                          icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility, size: 20),
                          color: AppColors.textSecondary,
                          tooltip: _obscurePasswords ? 'Show Passwords' : 'Hide Passwords',
                        ),
                      IconButton(icon: Icon(Icons.close, size: isMobile ? 20 : 24), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  SizedBox(height: isMobile ? 4 : 8),
                  Text(
                    'Admin and Teacher accounts only. Your request will be reviewed by the Admin.',
                    style: TextStyle(fontSize: isMobile ? 12 : 14, color: AppColors.textSecondary),
                  ),
                  Divider(height: isMobile ? 20 : 28),
  
                  CustomTextField(
                    hintText: 'Your Username', 
                    prefixIcon: Icons.person_outline, 
                    controller: _usernameCtrl,
                    validator: (v) => AppValidators.validateRequired(v, 'Username'),
                  ),
                  const SizedBox(height: AppSizes.p12),
                  CustomTextField(
                    hintText: 'New Password',
                    prefixIcon: Icons.lock_outline,
                    controller: _newPassCtrl,
                    isPassword: true,
                    obscureText: _obscurePasswords,
                    validator: AppValidators.validatePasswordComplexity,
                  ),
                  const SizedBox(height: AppSizes.p12),
                  CustomTextField(
                    hintText: 'Confirm New Password',
                    prefixIcon: Icons.lock_outline,
                    controller: _confirmPassCtrl,
                    isPassword: true,
                    obscureText: _obscurePasswords,
                    validator: (v) => AppValidators.validateRequired(v, 'Confirm Password'),
                  ),
  
                  SizedBox(height: isMobile ? 16 : 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: isMobile ? 130 : 140,
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
        ),
      ),
    );
  }
}