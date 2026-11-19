import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../providers/auth_provider.dart';

class TwoFactorVerifyModal extends ConsumerStatefulWidget {
  final TwoFactorChallenge challenge;

  const TwoFactorVerifyModal({super.key, required this.challenge});

  static Future<bool?> show(
    BuildContext context, {
    required TwoFactorChallenge challenge,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TwoFactorVerifyModal(challenge: challenge),
        ),
      ),
    );
  }

  @override
  ConsumerState<TwoFactorVerifyModal> createState() =>
      _TwoFactorVerifyModalState();
}

class _TwoFactorVerifyModalState extends ConsumerState<TwoFactorVerifyModal> {
  final _codeController = TextEditingController();
  bool _isBackupMode = false;
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _statusMessage;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  bool get _isEmailMethod => widget.challenge.method == 'email';

  @override
  void initState() {
    super.initState();
    if (_isEmailMethod) {
      _startResendCooldown(30);
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a verification code.');
      return;
    }
    if (!_isBackupMode && code.replaceAll(RegExp(r'\D'), '').length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final ok = await ref
        .read(authProvider.notifier)
        .verifyTwoFactorLogin(
          challengeToken: widget.challenge.challengeToken,
          code: code,
          isBackupCode: _isBackupMode,
          rememberMe: widget.challenge.rememberMe,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final err = ref.read(authProvider).asError?.error.toString() ??
          'Verification failed.';
      setState(() {
        _errorMessage = err.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _resendCooldown > 0) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final msg = await ref
          .read(authProvider.notifier)
          .resendTwoFactorLoginOtp(widget.challenge.challengeToken);
      if (!mounted) return;
      setState(() => _statusMessage = msg);
      _startResendCooldown(30);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _toggleBackupMode() {
    setState(() {
      _isBackupMode = !_isBackupMode;
      _codeController.clear();
      _errorMessage = null;
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final String subtitle;
    if (_isBackupMode) {
      subtitle = 'Enter one of your 8-character recovery backup codes.';
    } else if (_isEmailMethod) {
      final dest = widget.challenge.maskedEmail ?? 'your registered email';
      subtitle = 'Enter the 6-digit verification code sent to $dest.';
    } else {
      subtitle =
          'Enter the 6-digit code from your authenticator app (e.g. Google or Microsoft Authenticator).';
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_isSubmitting) Navigator.of(context).pop(false);
        },
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isDark ? Border.all(color: AppColors.darkBorder) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Two-Factor Verification',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '@${widget.challenge.username}',
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                  tooltip: 'Cancel',
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _codeController,
              autofocus: true,
              enabled: !_isSubmitting,
              keyboardType: _isBackupMode
                  ? TextInputType.text
                  : TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: _isBackupMode ? 12 : 6,
              inputFormatters: _isBackupMode
                  ? [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9\-]'),
                      ),
                    ]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: _isBackupMode ? 18 : 22,
                fontWeight: FontWeight.bold,
                letterSpacing: _isBackupMode ? 2 : 6,
                color: textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: _isBackupMode ? 'XXXX-XXXX' : '000000',
                hintStyle: TextStyle(
                  letterSpacing: _isBackupMode ? 2 : 6,
                  color: textSecondary.withValues(alpha: 0.45),
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurface2
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1.6,
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primaryGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF76BA8A)
                              : AppColors.primaryGreen,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : _toggleBackupMode,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    _isBackupMode
                        ? 'Use 6-digit verification code'
                        : 'Use a backup recovery code',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                if (_isEmailMethod && !_isBackupMode)
                  TextButton(
                    onPressed: (_isResending || _resendCooldown > 0 || _isSubmitting)
                        ? null
                        : _resendCode,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _isResending
                          ? 'Sending...'
                          : _resendCooldown > 0
                          ? 'Resend (${_resendCooldown}s)'
                          : 'Resend Code',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(fontWeight: FontWeight.w600),
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
}
