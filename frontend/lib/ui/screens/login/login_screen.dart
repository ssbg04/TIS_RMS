import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
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
import '../../shared/widgets/abstract_background.dart';
import '../../../core/utils/validators.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/server_discovery.dart';
import '../../shared/inputs/password_strength_indicator.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool sessionExpired;
  const LoginScreen({super.key, this.sessionExpired = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  int _logoTapCount = 0;

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late AnimationController _animController;
  late Animation<double> _revealAnimation;

  void _handleLogoTap() {
    _logoTapCount++;
    if (_logoTapCount >= 3) {
      _logoTapCount = 0;
      _showServerConfigDialog();
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 400),
    );
    _revealAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
    
    _usernameFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    _usernameController.addListener(_onTextChange);
    _passwordController.addListener(_onTextChange);

    _loadRememberMe(); // Load saved credentials on startup
    if (widget.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryGreen),
                SizedBox(width: 8),
                Text('Session Expired'),
              ],
            ),
            content: const Text(
              'You have been logged out due to 5 minutes of inactivity.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  void _onTextChange() {
    if (!mounted) return;
    _updateAnimationState();
  }

  void _onFocusChange() {
    if (!mounted) return;
    _updateAnimationState();
  }

  void _updateAnimationState() {
    final hasFocus = _usernameFocus.hasFocus || _passwordFocus.hasFocus;
    final hasText = _usernameController.text.isNotEmpty || _passwordController.text.isNotEmpty;
    if (hasFocus || hasText) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
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
    _usernameFocus.removeListener(_onFocusChange);
    _passwordFocus.removeListener(_onFocusChange);
    _usernameController.removeListener(_onTextChange);
    _passwordController.removeListener(_onTextChange);
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      showErrorDialog(
        context,
        'Missing Credentials',
        'Please enter both your username and password to continue.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await ref
        .read(authProvider.notifier)
        .login(
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
        await prefs.setString(
          'saved_username',
          _usernameController.text.trim(),
        );
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
        error.replaceAll('Exception: ', ''),
      );
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialUsername: _usernameController.text,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          if (!kIsWeb &&
              (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
            SizedBox(
              height: 32,
              child: WindowCaption(
                brightness: Brightness.dark,
                backgroundColor: AppColors.primaryGreen,
                title: Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'TIS Record Management System',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: AbstractBackground(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 800) {
                    // Desktop: Split Layout
                    return AnimatedBuilder(
                      animation: _revealAnimation,
                      builder: (context, child) {
                        return Container(
                          color: AppColors.darkGreen,
                          child: Row(
                            children: [
                              if (_revealAnimation.value > 0)
                                Flexible(
                                  flex: (5000 * _revealAnimation.value).toInt(),
                                  child: Opacity(
                                    opacity: _revealAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(AppSizes.p48),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: _handleLogoTap,
                                              child: Image.asset(
                                                'assets/images/logo.png',
                                                width: 220,
                                                height: 220,
                                              ),
                                            ),
                                            const SizedBox(height: AppSizes.p24),
                                            const Text(
                                              'Talisay Integrated School',
                                              style: TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 2.0,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const Text(
                                              'Tiaong, Quezon',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white70,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: AppSizes.p32),
                                            const Text(
                                              'Record Management System',
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: AppSizes.p8),
                                            const Text(
                                              'Secure Academic Records Database System',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                flex: 4000,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceCard : AppColors.pageBackground,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(24.0 * _revealAnimation.value),
                                      bottomLeft: Radius.circular(24.0 * _revealAnimation.value),
                                    ),
                                  ),
                                   child: Align(
                                     alignment: Alignment.topCenter,
                                     child: SingleChildScrollView(
                                       padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 24),
                                       child: ConstrainedBox(
                                         constraints: const BoxConstraints(
                                           maxWidth: 400,
                                         ),
                                         child: _buildLoginForm(),
                                       ),
                                     ),
                                   ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    );
                  } else {
                    // Mobile: Stacked Layout
                    return AnimatedBuilder(
                      animation: _revealAnimation,
                      builder: (context, child) {
                        return Container(
                          color: AppColors.darkGreen,
                          child: Column(
                            children: [
                              if (_revealAnimation.value > 0)
                                ClipRect(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    heightFactor: _revealAnimation.value,
                                    child: Opacity(
                                      opacity: _revealAnimation.value,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSizes.p48,
                                          horizontal: AppSizes.p24,
                                        ),
                                        child: SafeArea(
                                          bottom: false,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              GestureDetector(
                                                onTap: _handleLogoTap,
                                                child: Image.asset(
                                                  'assets/images/logo.png',
                                                  width: 100,
                                                  height: 100,
                                                ),
                                              ),
                                              const SizedBox(height: AppSizes.p16),
                                              const Text(
                                                'Talisay Integrated School',
                                                style: TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 1.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const Text(
                                                'Tiaong, Quezon',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white70,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: AppSizes.p16),
                                              const Text(
                                                'Record Management System',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: AppSizes.p4),
                                              const Text(
                                                'Secure Academic Records Database System',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: SafeArea(
                                  top: false,
                                  bottom: true,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurfaceCard : AppColors.pageBackground,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(24.0 * _revealAnimation.value),
                                        topRight: Radius.circular(24.0 * _revealAnimation.value),
                                      ),
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 24),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 400,
                                          ),
                                          child: _buildLoginForm(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Future<void> _showServerConfigDialog() async {
    final controller = TextEditingController(text: ApiConstants.baseUrl);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Server Configuration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://198.252.107.197:18484/api',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              ApiConstants.setBaseUrl(ApiConstants.vpsUrl);
              await ServerDiscoveryService.save(ApiConstants.baseUrl);
              if (mounted) setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Use VPS'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (scanCtx) => const _NetworkScanDialog(),
              );
            },
            child: const Text('Scan LAN'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                ApiConstants.setBaseUrl(newUrl);
                await ServerDiscoveryService.save(ApiConstants.baseUrl);
                if (mounted) setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _handleLogin,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleLogin,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _revealAnimation.value < 0.5 
                ? 'Login to TIS Record Management System' 
                : 'Login',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.p32),
          CustomTextField(
            hintText: 'Username',
            prefixIcon: Icons.person_outline,
            controller: _usernameController,
            focusNode: _usernameFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
          ),
          const SizedBox(height: AppSizes.p16),
          CustomTextField(
            hintText: 'Password',
            prefixIcon: Icons.lock_outline,
            controller: _passwordController,
            focusNode: _passwordFocus,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () =>
                setState(() => _obscurePassword = !_obscurePassword),
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
                    onChanged: (val) =>
                        setState(() => _rememberMe = val ?? false),
                  ),
                  Text(
                    'Remember Me',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
      ),
    );
  }
}

// ================================================================
// FORGOT PASSWORD DIALOG
// ================================================================
class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  final void Function(String message) onSuccess;
  final String? initialUsername;
  const _ForgotPasswordDialog({required this.onSuccess, this.initialUsername});

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePasswords = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null &&
        widget.initialUsername!.trim().isNotEmpty) {
      _usernameCtrl.text = widget.initialUsername!.trim();
    }
  }

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
      showErrorDialog(context, 'Password Mismatch', 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
        showErrorDialog(
          context,
          'Request Failed',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
      ),
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
                      Icon(
                        Icons.lock_reset,
                        color: AppColors.primaryGreen,
                        size: isMobile ? 24 : 28,
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text(
                          'Forgot Password',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: isMobile ? 20 : 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 4 : 8),
                  Text(
                    'Admin and Teacher accounts only. Your request will be reviewed by the Admin.',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Divider(height: isMobile ? 20 : 28),

                  CustomTextField(
                    hintText: 'Your Username',
                    prefixIcon: Icons.person_outline,
                    controller: _usernameCtrl,
                    validator: (v) =>
                        AppValidators.validateRequired(v, 'Username'),
                  ),
                  const SizedBox(height: AppSizes.p16),
                  Divider(height: isMobile ? 20 : 28),
                  const SizedBox(height: AppSizes.p8),
                  CustomTextField(
                    hintText: 'New Password',
                    prefixIcon: Icons.lock_outline,
                    controller: _newPassCtrl,
                    isPassword: true,
                    obscureText: _obscurePasswords,
                    onToggleVisibility: () => setState(() => _obscurePasswords = !_obscurePasswords),
                    validator: AppValidators.validatePasswordComplexity,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (v) => setState(() {}),
                  ),
                  if (_newPassCtrl.text.isNotEmpty) ...[
                    PasswordStrengthIndicator(password: _newPassCtrl.text),
                  ],
                  const SizedBox(height: AppSizes.p24),
                  CustomTextField(
                    hintText: 'Confirm New Password',
                    prefixIcon: Icons.lock_outline,
                    controller: _confirmPassCtrl,
                    isPassword: true,
                    obscureText: _obscurePasswords,
                    onToggleVisibility: () => setState(() => _obscurePasswords = !_obscurePasswords),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (v) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirm Password is required';
                      if (v != _newPassCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),

                  SizedBox(height: isMobile ? 16 : 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: isMobile ? 130 : 140,
                        child: PrimaryButton(
                          label: 'SUBMIT',
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

class _NetworkScanDialog extends StatefulWidget {
  const _NetworkScanDialog();

  @override
  State<_NetworkScanDialog> createState() => _NetworkScanDialogState();
}

class _NetworkScanDialogState extends State<_NetworkScanDialog> {
  String _status = 'Scanning local network…';

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final found = await ServerDiscoveryService.discover(
      onProgress: (subnet, scanned, total) {
        if (mounted) {
          setState(() => _status = 'Scanning ${subnet}x … ($scanned/$total)');
        }
      },
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (found != null) {
      ApiConstants.setBaseUrl(found);
      await ServerDiscoveryService.save(ApiConstants.baseUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Connected to local server: $found'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No TIS RMS server found on local network.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Local Network Scan'),
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(_status)),
        ],
      ),
    );
  }
}
