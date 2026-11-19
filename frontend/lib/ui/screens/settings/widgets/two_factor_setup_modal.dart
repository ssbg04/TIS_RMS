import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/qr_code_widget.dart';

enum _TwoFactorView {
  overview,
  chooseMethod,
  totpSetup,
  emailSetup,
  backupCodes,
  passwordConfirm,
}

enum _PasswordAction { disable, regenerate }

class TwoFactorSetupModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> status;

  const TwoFactorSetupModal({super.key, required this.status});

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> status,
  }) {
    final screenH = MediaQuery.of(context).size.height;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: screenH < 640 ? 16 : 32,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: screenH * 0.9,
          ),
          child: TwoFactorSetupModal(status: status),
        ),
      ),
    );
  }

  @override
  ConsumerState<TwoFactorSetupModal> createState() =>
      _TwoFactorSetupModalState();
}

class _TwoFactorSetupModalState extends ConsumerState<TwoFactorSetupModal> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  late _TwoFactorView _view;
  _PasswordAction? _passwordAction;
  bool _hasChanged = false;
  bool _isBusy = false;
  bool _obscurePassword = true;
  bool _codesCopied = false;
  String? _errorMessage;

  // TOTP setup state
  String? _totpSecret;
  String? _totpUri;

  // Email setup state
  String? _setupMaskedEmail;
  int _emailCooldown = 0;
  Timer? _emailTimer;

  // Backup codes state
  List<String> _backupCodes = const [];

  bool get _isEnabled => widget.status['enabled'] == true;
  String? get _activeMethod => widget.status['method'] as String?;
  bool get _hasEmail => widget.status['hasEmail'] == true;
  String? get _maskedEmail => widget.status['maskedEmail'] as String?;
  int get _backupRemaining =>
      (widget.status['backupCodesRemaining'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _view = _isEnabled ? _TwoFactorView.overview : _TwoFactorView.chooseMethod;
    _setupMaskedEmail = _maskedEmail;
  }

  @override
  void dispose() {
    _emailTimer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startEmailCooldown(int seconds) {
    _emailTimer?.cancel();
    setState(() => _emailCooldown = seconds);
    _emailTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_emailCooldown <= 1) {
        timer.cancel();
        setState(() => _emailCooldown = 0);
      } else {
        setState(() => _emailCooldown--);
      }
    });
  }

  Future<void> _startTotpSetup() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _codeController.clear();
    });
    try {
      final data = await ref.read(authProvider.notifier).setupTotp();
      if (!mounted) return;
      setState(() {
        _totpSecret = data['secret'] as String?;
        _totpUri = data['otpauthUri'] as String?;
        _view = _TwoFactorView.totpSetup;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmTotpSetup() async {
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code.');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final codes = await ref.read(authProvider.notifier).confirmTotp(code);
      if (!mounted) return;
      setState(() {
        _backupCodes = codes;
        _codesCopied = false;
        _hasChanged = true;
        _view = _TwoFactorView.backupCodes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _startEmailSetup() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _codeController.clear();
    });
    try {
      final masked =
          await ref.read(authProvider.notifier).setupEmailTwoFactor();
      if (!mounted) return;
      setState(() {
        _setupMaskedEmail = masked ?? _maskedEmail;
        _view = _TwoFactorView.emailSetup;
      });
      _startEmailCooldown(30);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmEmailSetup() async {
    final code = _codeController.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code.');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final codes =
          await ref.read(authProvider.notifier).confirmEmailTwoFactor(code);
      if (!mounted) return;
      setState(() {
        _backupCodes = codes;
        _codesCopied = false;
        _hasChanged = true;
        _view = _TwoFactorView.backupCodes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitPasswordAction() async {
    final pw = _passwordController.text;
    if (pw.isEmpty) {
      setState(() => _errorMessage = 'Please enter your current password.');
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(authProvider.notifier);
      if (_passwordAction == _PasswordAction.disable) {
        await notifier.disableTwoFactor(pw);
        _hasChanged = true;
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        final codes = await notifier.regenerateTwoFactorBackupCodes(pw);
        if (!mounted) return;
        setState(() {
          _backupCodes = codes;
          _codesCopied = false;
          _hasChanged = true;
          _passwordController.clear();
          _view = _TwoFactorView.backupCodes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _copyText(String text, {bool markCodesCopied = false}) {
    Clipboard.setData(ClipboardData(text: text));
    if (markCodesCopied) {
      setState(() => _codesCopied = true);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard.'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatSecret(String secret) {
    final buf = StringBuffer();
    for (int i = 0; i < secret.length; i += 4) {
      if (i > 0) buf.write(' ');
      buf.write(secret.substring(i, (i + 4).clamp(0, secret.length)));
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final String title;
    switch (_view) {
      case _TwoFactorView.overview:
        title = 'Two-Factor Authentication';
      case _TwoFactorView.chooseMethod:
        title = _isEnabled ? 'Switch 2FA Method' : 'Set Up Two-Factor Auth';
      case _TwoFactorView.totpSetup:
        title = 'Authenticator App Setup';
      case _TwoFactorView.emailSetup:
        title = 'Email OTP Setup';
      case _TwoFactorView.backupCodes:
        title = 'Save Backup Recovery Codes';
      case _TwoFactorView.passwordConfirm:
        title = _passwordAction == _PasswordAction.disable
            ? 'Disable Two-Factor Auth'
            : 'Regenerate Backup Codes';
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_isBusy) Navigator.of(context).pop(_hasChanged);
        },
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isDark ? Border.all(color: AppColors.darkBorder) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primaryGreen,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: _isBusy
                        ? null
                        : () => Navigator.of(context).pop(_hasChanged),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 14),
                    ],
                    if (_view == _TwoFactorView.overview)
                      _buildOverview(isDark, textPrimary, textSecondary)
                    else if (_view == _TwoFactorView.chooseMethod)
                      _buildMethodChooser(isDark, textPrimary, textSecondary)
                    else if (_view == _TwoFactorView.totpSetup)
                      _buildTotpSetup(isDark, textPrimary, textSecondary)
                    else if (_view == _TwoFactorView.emailSetup)
                      _buildEmailSetup(isDark, textPrimary, textSecondary)
                    else if (_view == _TwoFactorView.backupCodes)
                      _buildBackupCodes(isDark, textPrimary, textSecondary)
                    else
                      _buildPasswordConfirm(isDark, textPrimary, textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(bool isDark, Color textPrimary, Color textSecondary) {
    final isTotp = _activeMethod == 'totp';
    final methodLabel = isTotp ? 'Authenticator App (TOTP)' : 'Email OTP';
    final methodDetail = isTotp
        ? 'Generates rotating 6-digit codes offline.'
        : 'Codes sent to ${_maskedEmail ?? "your registered email"}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2FA Active • $methodLabel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      methodDetail,
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_backupRemaining backup recovery codes remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _backupRemaining <= 2
                            ? Colors.orange.shade700
                            : (isDark
                                  ? const Color(0xFF76BA8A)
                                  : AppColors.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        OutlinedButton.icon(
          onPressed: _isBusy
              ? null
              : () => setState(() {
                  _errorMessage = null;
                  _view = _TwoFactorView.chooseMethod;
                }),
          icon: const Icon(Icons.swap_horiz_rounded, size: 19),
          label: const Text('Switch 2FA Method'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isBusy
              ? null
              : () => setState(() {
                  _errorMessage = null;
                  _passwordController.clear();
                  _passwordAction = _PasswordAction.regenerate;
                  _view = _TwoFactorView.passwordConfirm;
                }),
          icon: const Icon(Icons.key_rounded, size: 18),
          label: const Text('Regenerate Backup Recovery Codes'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isBusy
              ? null
              : () => setState(() {
                  _errorMessage = null;
                  _passwordController.clear();
                  _passwordAction = _PasswordAction.disable;
                  _view = _TwoFactorView.passwordConfirm;
                }),
          icon: const Icon(Icons.gpp_bad_outlined, size: 18),
          label: const Text('Disable Two-Factor Authentication'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodChooser(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose how you want to verify your identity during login:',
          style: TextStyle(fontSize: 13.5, color: textSecondary),
        ),
        const SizedBox(height: 14),

        // Method 1: Authenticator App (TOTP)
        _buildMethodTile(
          isDark: isDark,
          icon: Icons.qr_code_scanner_rounded,
          title: 'Authenticator App (TOTP)',
          badge: _isEnabled && _activeMethod == 'totp'
              ? 'Current'
              : 'Recommended • Offline',
          subtitle:
              'Use Google Authenticator or Microsoft Authenticator. Works without internet access.',
          enabled: !_isBusy,
          onTap: _startTotpSetup,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 12),

        // Method 2: Email OTP
        _buildMethodTile(
          isDark: isDark,
          icon: Icons.mark_email_read_outlined,
          title: 'Email One-Time Code (OTP)',
          badge: _isEnabled && _activeMethod == 'email' ? 'Current' : null,
          subtitle: _hasEmail
              ? 'Send a 6-digit verification code to ${_maskedEmail ?? "your registered email"}.'
              : 'Add an email address in Account Settings first to enable Email OTP.',
          enabled: _hasEmail && !_isBusy,
          onTap: _startEmailSetup,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),

        if (_isEnabled) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isBusy
                ? null
                : () => setState(() {
                    _errorMessage = null;
                    _view = _TwoFactorView.overview;
                  }),
            child: const Text('Back'),
          ),
        ],
      ],
    );
  }

  Widget _buildMethodTile({
    required bool isDark,
    required IconData icon,
    required String title,
    String? badge,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF76BA8A)
                                    : AppColors.primaryGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.chevron_right_rounded, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotpSetup(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final secret = _totpSecret ?? '';
    final uri = _totpUri ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. Scan this QR code with Google Authenticator or Microsoft Authenticator:',
          style: TextStyle(fontSize: 13, color: textSecondary, height: 1.35),
        ),
        const SizedBox(height: 14),
        if (uri.isNotEmpty) Center(child: QrCodeWidget(data: uri, size: 175)),
        const SizedBox(height: 14),

        Text(
          'Or enter this setup key manually:',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _formatSecret(secret),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.primaryGreen,
                tooltip: 'Copy setup key',
                onPressed: () => _copyText(secret),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          '2. Enter the 6-digit code shown in your app to verify:',
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 8),
        _buildSixDigitField(isDark, textPrimary, textSecondary, _confirmTotpSetup),
        const SizedBox(height: 16),

        Row(
          children: [
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => setState(() {
                      _errorMessage = null;
                      _view = _TwoFactorView.chooseMethod;
                    }),
              child: const Text('Back'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isBusy ? null : _confirmTotpSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                elevation: 0,
              ),
              child: _isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify & Enable'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmailSetup(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'We sent a 6-digit verification code to ${_setupMaskedEmail ?? "your registered email"}. Enter it below to activate Email OTP.',
          style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        _buildSixDigitField(isDark, textPrimary, textSecondary, _confirmEmailSetup),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: (_isBusy || _emailCooldown > 0) ? null : _startEmailSetup,
            child: Text(
              _emailCooldown > 0
                  ? 'Resend code in ${_emailCooldown}s'
                  : 'Resend code',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => setState(() {
                      _errorMessage = null;
                      _view = _TwoFactorView.chooseMethod;
                    }),
              child: const Text('Back'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isBusy ? null : _confirmEmailSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                elevation: 0,
              ),
              child: _isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify & Enable'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackupCodes(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: isDark ? 0.14 : 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Save these one-time recovery codes in a safe place. Each code can only be used once if you lose access to your 2FA device.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.1,
          ),
          itemCount: _backupCodes.length,
          itemBuilder: (context, index) {
            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: SelectableText(
                _backupCodes[index],
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: textPrimary,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _copyText(
                _backupCodes.join('\n'),
                markCodesCopied: true,
              ),
              icon: Icon(
                _codesCopied ? Icons.check_rounded : Icons.copy_all_rounded,
                size: 18,
              ),
              label: Text(_codesCopied ? 'Copied!' : 'Copy All Codes'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
                elevation: 0,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordConfirm(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isDisable = _passwordAction == _PasswordAction.disable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isDisable
              ? 'Enter your current password to disable Two-Factor Authentication.'
              : 'Enter your current password to generate new backup recovery codes (previous unused codes will be invalidated).',
          style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          autofocus: true,
          obscureText: _obscurePassword,
          enabled: !_isBusy,
          style: TextStyle(color: textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Current Password',
            filled: true,
            fillColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => _submitPasswordAction(),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            TextButton(
              onPressed: _isBusy
                  ? null
                  : () => setState(() {
                      _errorMessage = null;
                      _view = _TwoFactorView.overview;
                    }),
              child: const Text('Back'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isBusy ? null : _submitPasswordAction,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDisable ? AppColors.error : AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                elevation: 0,
              ),
              child: _isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isDisable ? 'Disable 2FA' : 'Generate Codes'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSixDigitField(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    VoidCallback onSubmit,
  ) {
    return TextField(
      controller: _codeController,
      enabled: !_isBusy,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
        letterSpacing: 6,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: TextStyle(
          letterSpacing: 6,
          color: textSecondary.withValues(alpha: 0.45),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface2 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
      ),
      onSubmitted: (_) => onSubmit(),
    );
  }
}
