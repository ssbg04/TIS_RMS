import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
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
import 'package:dio/dio.dart';
import '../../shared/dialogs/disconnected_dialog.dart';
import '../../shared/dialogs/error_dialog.dart';
import '../../shared/dialogs/success_dialog.dart';
import '../../shared/widgets/abstract_background.dart';
import '../../../core/utils/validators.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/server_discovery.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../shared/inputs/password_strength_indicator.dart';
import 'widgets/two_factor_verify_modal.dart';

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
  bool _biometricSupported = false;
  bool _hasBiometricCredentials = false;
  List<String> _enrolledBiometricUsers = [];
  String? _biometricUsername;
  bool _isBiometricAuthenticating = false;
  String? _inlineError;
  bool _capsLockOn = false;

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late AnimationController _animController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

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
      duration: const Duration(milliseconds: 500),
    );
    _headerFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    ));
    _cardFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _animController.forward();

    _loadRememberMe(); // Load saved credentials on startup
    _loadBiometricStatus();
    _usernameController.addListener(_clearInlineError);
    _passwordController.addListener(_clearInlineError);
    _passwordFocus.addListener(_checkCapsLock);
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
              'You have been logged out due to 10 minutes of inactivity.',
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

  void _clearInlineError() {
    if (_inlineError != null && mounted) {
      setState(() => _inlineError = null);
    }
    _checkCapsLock();
  }

  void _checkCapsLock() {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    final isOn = HardwareKeyboard.instance.lockModesEnabled
        .contains(KeyboardLockMode.capsLock);
    if (isOn != _capsLockOn && mounted) {
      setState(() => _capsLockOn = isOn);
    }
  }

  // --- Added: Load saved username for Remember Me ---
  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('saved_password')) {
      await prefs.remove('saved_password');
    }
    final isRemembered = prefs.getBool('rememberMe') ?? false;

    if (isRemembered && mounted) {
      setState(() {
        _rememberMe = true;
        _usernameController.text = prefs.getString('saved_username') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_clearInlineError);
    _passwordController.removeListener(_clearInlineError);
    _passwordFocus.removeListener(_checkCapsLock);
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricStatus() async {
    final supported = await BiometricAuthService.isSupported();
    if (!supported || !mounted) return;
    final enrolled = await BiometricAuthService.getEnrolledUsernames();
    final lastUser = await BiometricAuthService.getLastUsername();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _enrolledBiometricUsers = enrolled;
      _hasBiometricCredentials = enrolled.isNotEmpty;
      _biometricUsername = (lastUser != null && enrolled.contains(lastUser))
          ? lastUser
          : (enrolled.isNotEmpty ? enrolled.first : null);
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    final user = ref.read(authProvider).value;
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    ref.read(activeTabProvider.notifier).setTab('Dashboard');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isDesktop
            ? WindowsSidebarLayout(userRole: user!.role)
            : AndroidBottomNavLayout(userRole: user!.role),
      ),
    );
  }

  void _showLoginError() {
    final rawError = ref.read(authProvider).error;
    final errorStr = rawError?.toString().toLowerCase() ?? '';
    final isConnectionIssue = (rawError is DioException &&
            (rawError.type == DioExceptionType.connectionError ||
                rawError.type == DioExceptionType.connectionTimeout ||
                rawError.type == DioExceptionType.receiveTimeout)) ||
        errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('connection closed') ||
        errorStr.contains('handshake');

    if (isConnectionIssue) {
      DisconnectedDialog.show(context);
      return;
    }
    final cleanMessage = ApiConstants.extractErrorMessage(
      rawError,
      'Failed to log in. Please check your credentials.',
    );
    if (mounted) {
      setState(() => _inlineError = cleanMessage);
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_isBiometricAuthenticating) return;

    final typedUser = _usernameController.text.trim();
    String? targetUser;

    if (typedUser.isNotEmpty) {
      final hasCreds =
          await BiometricAuthService.hasSavedCredentialsFor(typedUser);
      if (!hasCreds) {
        setState(() {
          _inlineError =
              '@$typedUser has not enabled biometric sign-in on this device. Please enter your password.';
        });
        return;
      }
      targetUser = typedUser;
    } else if (_enrolledBiometricUsers.length > 1) {
      targetUser = await _showAccountPickerModal(_enrolledBiometricUsers);
      if (targetUser == null || !mounted) return;
    } else if (_enrolledBiometricUsers.isNotEmpty) {
      targetUser = _enrolledBiometricUsers.first;
    } else {
      return;
    }

    setState(() => _isBiometricAuthenticating = true);

    try {
      final bioData = await BiometricAuthService.authenticateAndGetToken(
        requestedUsername: targetUser,
      );
      if (!mounted || bioData == null) {
        if (mounted) setState(() => _isBiometricAuthenticating = false);
        return;
      }

      final success = await ref
          .read(authProvider.notifier)
          .loginWithBiometrics(bioData.token);

      if (!mounted) return;
      setState(() => _isBiometricAuthenticating = false);

      if (success) {
        _navigateToHome();
      } else {
        await BiometricAuthService.clearCredentialsFor(bioData.username);
        _loadBiometricStatus();
        if (mounted) {
          showErrorDialog(
            context,
            'Biometric Sign-In Expired',
            'Your biometric session has expired or was revoked. Please log in with your password to re-enable biometrics.',
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isBiometricAuthenticating = false);
    }
  }

  Future<String?> _showAccountPickerModal(List<String> users) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fingerprint_rounded,
                      color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Select Account to Unlock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...users.map(
                (u) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primaryGreen.withValues(alpha: 0.12),
                    child: Text(
                      u.isNotEmpty ? u[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(u,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () => Navigator.of(ctx).pop(u),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finalizePasswordLogin(String username) async {
    // Commit autofill context BEFORE unfocusing so Android Google Password Manager
    // receives the active field values and prompts to save the password.
    TextInput.finishAutofillContext(shouldSave: true);
    FocusScope.of(context).unfocus();

    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('rememberMe', true);
      await prefs.setString('saved_username', username);
    } else {
      await prefs.remove('rememberMe');
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
    }

    ref.read(pendingBiometricPromptUsernameProvider.notifier).state = username;
    if (mounted) _navigateToHome();
  }

  void _handleLogin() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _inlineError = 'Please enter both your username and password.';
      });
      return;
    }
    if (_inlineError != null) {
      setState(() => _inlineError = null);
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final success = await ref
        .read(authProvider.notifier)
        .login(
          username,
          password,
          rememberMe: _rememberMe,
        );

    if (!mounted) return;

    if (success) {
      await _finalizePasswordLogin(username);
      return;
    }

    final challenge = ref.read(authProvider.notifier).pendingTwoFactorChallenge;
    if (challenge != null) {
      final verified = await TwoFactorVerifyModal.show(
        context,
        challenge: challenge,
      );
      ref.read(authProvider.notifier).clearPendingTwoFactorChallenge();
      if (verified == true && mounted) {
        await _finalizePasswordLogin(username);
      }
      return;
    }

    FocusScope.of(context).unfocus();
    _showLoginError();
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ForgotPasswordDialog(
        initialUsername: _usernameController.text,
        onSuccess: (msg) {
          showSuccessDialog(
            context,
            title: 'Success',
            message: msg,
          );
        },
      ),
    );
  }

  Future<void> _handleLoginScreenBack() async {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null &&
        primaryFocus.hasFocus &&
        primaryFocus.context != null) {
      final isEditable = primaryFocus.context!.widget is EditableText ||
          primaryFocus.context!
                  .findAncestorWidgetOfExactType<EditableText>() !=
              null;
      if (isEditable) {
        primaryFocus.unfocus();
        return;
      }
    }

    if (_isBiometricAuthenticating || ref.read(authProvider).isLoading) {
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Confirm Exit'),
          ],
        ),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleLoginScreenBack();
      },
      child: GestureDetector(
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
                title: const Text(
                  'TIS RMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          Expanded(
            child: AbstractBackground(
              blurSigma: 6.0,
              withOverlay: true,
              overlayOpacity: isDark ? 0.36 : 0.22,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.25, -0.25),
                          radius: 1.15,
                          colors: [
                            AppColors.primaryGreen.withValues(
                              alpha: isDark ? 0.14 : 0.10,
                            ),
                            Colors.transparent,
                            Colors.black.withValues(
                              alpha: isDark ? 0.30 : 0.08,
                            ),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardColor = isDark
                          ? AppColors.darkSurfaceCard.withValues(alpha: 0.80)
                          : AppColors.surfaceWhite.withValues(alpha: 0.86);
                      final cardBorder = isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white.withValues(alpha: 0.75);

                  if (constraints.maxWidth >= 800) {
                    // Desktop: Clean Minimalist Split Layout
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p32,
                            vertical: AppSizes.p24,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: FadeTransition(
                                  opacity: _headerFade,
                                  child: SlideTransition(
                                    position: _headerSlide,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: _handleLogoTap,
                                          child: Image.asset(
                                            'assets/images/logo.webp',
                                            width: 112,
                                            height: 112,
                                          ),
                                        ),
                                        const SizedBox(height: AppSizes.p24),
                                        Text(
                                          'TIS RMS',
                                          style: TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSizes.p8),
                                        Text(
                                          'Talisay Integrated School • Tiaong, Quezon',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSizes.p16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryGreen
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'Records Management System',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildServerFooterPill(isDark),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSizes.p48),
                              SizedBox(
                                width: 410,
                                child: FadeTransition(
                                  opacity: _cardFade,
                                  child: SlideTransition(
                                    position: _cardSlide,
                                    child: _buildGlassCard(
                                      isDark: isDark,
                                      cardColor: cardColor,
                                      cardBorder: cardBorder,
                                      padding: const EdgeInsets.all(32),
                                      child: SingleChildScrollView(
                                        child: _buildLoginForm(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Mobile: Centered Minimalist Layout
                  return SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: _headerFade,
                                child: SlideTransition(
                                  position: _headerSlide,
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: _handleLogoTap,
                                        child: Image.asset(
                                          'assets/images/logo.webp',
                                          width: 72,
                                          height: 72,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'TIS RMS',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Talisay Integrated School • Tiaong, Quezon',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              FadeTransition(
                                opacity: _cardFade,
                                child: SlideTransition(
                                  position: _cardSlide,
                                  child: _buildGlassCard(
                                    isDark: isDark,
                                    cardColor: cardColor,
                                    cardBorder: cardBorder,
                                    padding: const EdgeInsets.all(24),
                                    child: _buildLoginForm(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildServerFooterPill(isDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    )));
  }

  Widget _buildGlassCard({
    required bool isDark,
    required Color cardColor,
    required Color cardBorder,
    required EdgeInsets padding,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildServerFooterPill(bool isDark) {
    final uri = Uri.tryParse(ApiConstants.baseUrl);
    final hostLabel = (uri != null && uri.host.isNotEmpty)
        ? '${uri.host}${uri.hasPort ? ':${uri.port}' : ''}'
        : ApiConstants.baseUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _showServerConfigDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white)
              .withValues(alpha: isDark ? 0.30 : 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: isDark ? 0.10 : 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 13,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Server: $hostLabel • Configure',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServerConfigDialog() async {
    final controller = TextEditingController(text: ApiConstants.baseUrl);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
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
                hintText: 'https://tis-rms.cc.cd/api',
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
              ApiConstants.setBaseUrl(ApiConstants.tunnelUrl);
              await ServerDiscoveryService.save(ApiConstants.baseUrl);
              if (mounted) setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Use Tunnel'),
          ),
          TextButton(
            onPressed: () {
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
              if (ctx.mounted) Navigator.pop(ctx);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _handleLogin,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleLogin,
      },
      child: AutofillGroup(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign In',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Access your school records account',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.p24),
          CustomTextField(
            hintText: 'Username',
            prefixIcon: Icons.person_outline,
            controller: _usernameController,
            focusNode: _usernameFocus,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
          ),
          const SizedBox(height: AppSizes.p16),
          CustomTextField(
            hintText: 'Password',
            prefixIcon: Icons.lock_outline,
            controller: _passwordController,
            focusNode: _passwordFocus,
            autofillHints: const [AutofillHints.password],
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
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: AppColors.primaryGreen,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) =>
                              setState(() => _rememberMe = val ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember me',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.p20),
          if (_capsLockOn) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.keyboard_capslock_rounded,
                      size: 15, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Caps Lock is on',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_inlineError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 17, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inlineError!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _inlineError = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: PrimaryButton(
                    label: 'Sign In',
                    isLoading: isLoading,
                    onPressed: _handleLogin,
                  ),
                ),
              ),
              if (_biometricSupported && _hasBiometricCredentials) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: _biometricUsername != null &&
                          _biometricUsername!.isNotEmpty
                      ? 'Sign in with Biometrics ($_biometricUsername)'
                      : 'Sign in with Biometrics',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: (isLoading || _isBiometricAuthenticating)
                          ? null
                          : _handleBiometricLogin,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primaryGreen
                            .withValues(alpha: isDark ? 0.14 : 0.08),
                        side: BorderSide(
                          color: AppColors.primaryGreen.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _isBiometricAuthenticating
                            ? const SizedBox(
                                key: ValueKey('bio-loading'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              )
                            : const Icon(
                                key: ValueKey('bio-icon'),
                                Icons.fingerprint_rounded,
                                color: AppColors.primaryGreen,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_biometricSupported && _hasBiometricCredentials) ...[
            const SizedBox(height: 10),
            Center(
              child: Builder(builder: (context) {
                final typed = _usernameController.text.trim();
                final String caption;
                final bool isWarning;

                if (typed.isNotEmpty) {
                  final hasCreds = _enrolledBiometricUsers
                      .any((u) => u.toLowerCase() == typed.toLowerCase());
                  if (hasCreds) {
                    caption = 'Biometric unlock ready for @$typed';
                    isWarning = false;
                  } else {
                    caption = '@$typed has not enabled biometrics';
                    isWarning = true;
                  }
                } else if (_enrolledBiometricUsers.length > 1) {
                  caption = 'Tap fingerprint to select account to unlock';
                  isWarning = false;
                } else if (_enrolledBiometricUsers.isNotEmpty) {
                  caption =
                      'Biometric unlock ready for @${_enrolledBiometricUsers.first}';
                  isWarning = false;
                } else {
                  caption = '';
                  isWarning = false;
                }

                if (caption.isEmpty) return const SizedBox.shrink();
                return Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        isWarning ? FontWeight.w600 : FontWeight.normal,
                    color: isWarning
                        ? Colors.orange.shade700
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

// ================================================================
// FORGOT PASSWORD OTP DIALOG (EMAIL & PHONE SMS MULTI-STEP)
// ================================================================
// ================================================================
// FORGOT PASSWORD DIALOG (EMAIL OTP VERIFICATION)
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
  final _usernameFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  int _currentStep = 0; // 0: Enter Username, 1: Enter OTP & Set New Password
  bool _isLoading = false;
  bool _obscurePasswords = true;
  String? _maskedEmail;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

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
    _cooldownTimer?.cancel();
    _usernameCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  // ── Step 0: Find Account & Send Email OTP ─────────────────────────────────
  Future<void> _handleSendEmailOtp() async {
    if (!_usernameFormKey.currentState!.validate()) return;
    final username = _usernameCtrl.text.trim();

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      
      // 1. Lookup account to verify email exists & get masked email
      final lookup = await repo.lookupResetOptions(username);
      _maskedEmail = lookup['maskedEmail'] as String?;

      // 2. Dispatch OTP to email
      await repo.sendEmailOtp(username);

      if (!mounted) return;
      _startCooldown(60);
      setState(() {
        _otpCtrl.clear();
        _currentStep = 1;
      });
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Error',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 1: Verify OTP & Reset Password ───────────────────────────────────
  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    final username = _usernameCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (newPass != confirmPass) {
      showErrorDialog(context, 'Error', 'Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final message = await repo.resetPasswordEmailOtp(
        username: username,
        otp: otp,
        newPassword: newPass,
        confirmPassword: confirmPass,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess(message);
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(
          context,
          'Error',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasResetProgress =>
      _otpCtrl.text.trim().isNotEmpty ||
      _newPassCtrl.text.isNotEmpty ||
      _confirmPassCtrl.text.isNotEmpty;

  Future<bool> _confirmDiscard({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _handleBackStep() async {
    if (_isLoading) return;
    final ok = await _confirmDiscard(
      title: 'Go Back?',
      message: _hasResetProgress
          ? 'Your entered verification code and password fields will be cleared.'
          : 'You already requested a verification code. Go back to the username step?',
      confirmLabel: 'Go Back',
    );
    if (!ok || !mounted) return;
    setState(() {
      _otpCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _currentStep = 0;
    });
  }

  Future<void> _handleClose() async {
    if (_isLoading) return;
    final ok = await _confirmDiscard(
      title: 'Cancel Recovery?',
      message: _currentStep == 1
          ? 'Exit password recovery? You will need to request a new code if you leave.'
          : 'Are you sure you want to exit account recovery?',
      confirmLabel: 'Exit',
    );
    if (!ok || !mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : Colors.grey.shade300;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isLoading) return;
        if (_currentStep == 1) {
          _handleBackStep();
        } else {
          _handleClose();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_currentStep > 0) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: _isLoading ? null : _handleBackStep,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _currentStep == 0
                            ? Icons.mark_email_unread_outlined
                            : Icons.lock_reset_rounded,
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
                            _currentStep == 0
                                ? 'Account Recovery'
                                : 'Reset Password',
                            style: TextStyle(
                              fontSize: isMobile ? 17 : 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentStep == 0
                                ? 'Verify via registered email'
                                : 'Enter code & choose new password',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: _isLoading ? null : _handleClose,
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: borderColor.withValues(alpha: 0.6)),
                const SizedBox(height: 18),

                // ── STEP 0: Enter Username & Send Email OTP ─────────────────
                if (_currentStep == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface2
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enter your username to receive a 6-digit verification code on your registered email address.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _usernameFormKey,
                    child: CustomTextField(
                      hintText: 'Username',
                      prefixIcon: Icons.person_outline,
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSendEmailOtp(),
                      validator: (v) =>
                          AppValidators.validateRequired(v, 'Username'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleClose,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: borderColor),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: PrimaryButton(
                            label: 'Send Code',
                            isLoading: _isLoading,
                            onPressed: _handleSendEmailOtp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── STEP 1: Enter OTP & Set New Password ────────────────────
                if (_currentStep == 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(
                        alpha: isDark ? 0.14 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.primaryGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Code sent to ${_maskedEmail ?? "your registered email"}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Form(
                    key: _resetFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Verification Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: (_cooldownSeconds == 0 && !_isLoading)
                                  ? _handleSendEmailOtp
                                  : null,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _cooldownSeconds > 0
                                    ? 'Resend (${_cooldownSeconds}s)'
                                    : 'Resend Code',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        CustomTextField(
                          hintText: '6-digit code',
                          prefixIcon: Icons.pin_outlined,
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          maxLength: 6,
                          counterText: '',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().length != 6) {
                              return 'Enter full 6-digit code';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        CustomTextField(
                          hintText: 'New Password',
                          prefixIcon: Icons.lock_outline,
                          controller: _newPassCtrl,
                          isPassword: true,
                          obscureText: _obscurePasswords,
                          textInputAction: TextInputAction.next,
                          onToggleVisibility: () => setState(
                              () => _obscurePasswords = !_obscurePasswords),
                          validator: AppValidators.validatePasswordComplexity,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (_) => setState(() {}),
                        ),

                        if (_newPassCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          PasswordStrengthIndicator(
                            password: _newPassCtrl.text,
                          ),
                        ],

                        const SizedBox(height: 14),

                        CustomTextField(
                          hintText: 'Confirm New Password',
                          prefixIcon: Icons.lock_outline,
                          controller: _confirmPassCtrl,
                          isPassword: true,
                          obscureText: _obscurePasswords,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleResetPassword(),
                          onToggleVisibility: () => setState(
                              () => _obscurePasswords = !_obscurePasswords),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Confirm Password is required';
                            }
                            if (v != _newPassCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleBackStep,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(color: borderColor),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 46,
                          child: PrimaryButton(
                            label: 'Reset Password',
                            isLoading: _isLoading,
                            onPressed: _handleResetPassword,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
    final found = await ServerDiscoveryService.scanLanOnly(
      onProgress: (msg) {
        if (mounted) setState(() => _status = msg);
      },
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (found != null) {
      showSuccessDialog(
        context,
        title: 'LAN Server Connected',
        message: 'Successfully discovered and connected to local server: $found',
      );
    } else {
      showErrorDialog(
        context,
        'LAN Server Not Found',
        'No TIS RMS server was found on your local network (LAN).\n\n'
        '• Ensure the TIS RMS Server Manager is running on the host computer.\n'
        '• Ensure this device is connected to the same Wi-Fi / network.\n\n'
        'Your connection remains active on Cloud Tunnel (${ApiConstants.tunnelUrl}).',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Local Network Scan'),
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(_status)),
          ],
        ),
      ),
    );
  }
}
