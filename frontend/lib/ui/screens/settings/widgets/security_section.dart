import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/utils/ip_location_helper.dart';
import '../../../../domain/entities/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/sessions_provider.dart';
import 'change_password_modal.dart';
import 'two_factor_setup_modal.dart';

class SecuritySection extends ConsumerStatefulWidget {
  final UserModel user;
  final Future<void> Function(BuildContext, WidgetRef) onDeactivateAccount;
  final Widget Function({required Widget child}) buildCard;
  final Widget Function({required Widget child}) buildDangerCard;
  final bool isDark;

  const SecuritySection({
    super.key,
    required this.user,
    required this.onDeactivateAccount,
    required this.buildCard,
    required this.buildDangerCard,
    required this.isDark,
  });

  @override
  ConsumerState<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<SecuritySection> {
  bool _isDevicesExpanded = false;
  static const Duration _activeThreshold = Duration(minutes: 15);
  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  Map<String, dynamic>? _twoFactorStatus;
  bool _isLoading2fa = true;

  bool _isSessionActive(Map<String, dynamic> session) {
    if (session['is_current'] == true) return true;
    final raw = session['last_seen_at']?.toString();
    if (raw == null || raw.isEmpty) return false;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return false;
    return DateTime.now().toUtc().difference(parsed.toUtc()).abs() <= _activeThreshold;
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    _loadTwoFactorStatus();
  }

  Future<void> _loadTwoFactorStatus() async {
    try {
      final status = await ref.read(authProvider.notifier).getTwoFactorStatus();
      if (!mounted) return;
      setState(() {
        _twoFactorStatus = status;
        _isLoading2fa = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading2fa = false);
    }
  }

  Future<void> _openTwoFactorModal() async {
    if (_isLoading2fa) return;
    final changed = await TwoFactorSetupModal.show(
      context,
      status: _twoFactorStatus ?? const {'enabled': false},
    );
    if (changed == true && mounted) {
      await _loadTwoFactorStatus();
    }
  }

  Future<void> _loadBiometricState() async {
    final supported = await BiometricAuthService.isSupported();
    final enabled = supported ? await BiometricAuthService.hasSavedCredentials() : false;
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!value) {
      try {
        final currentBioToken = await BiometricAuthService.getSavedToken();
        await ref.read(authProvider.notifier).disableBiometrics(token: currentBioToken);
      } catch (_) {}
      await BiometricAuthService.clearCredentials();
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with biometrics disabled on this device.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      return;
    }

    // Prompt biometric scan directly to verify device owner
    final verified = await BiometricAuthService.authenticate(
      reason: 'Scan your fingerprint or face to enable biometric sign-in',
    );
    if (!verified || !mounted) return;

    try {
      final token = await ref.read(authProvider.notifier).registerBiometrics();
      await BiometricAuthService.saveBiometricToken(widget.user.username, token);
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with biometrics enabled on this device.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to enable biometrics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Logged-in Devices Section ───────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.devices_outlined,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Logged-in Devices',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildDeviceCountBadge(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Manage devices where your account is currently active.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            _buildSessionsList(context, ref),
          ],
        ),
        const SizedBox(height: AppSizes.p24),
        Divider(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
        const SizedBox(height: AppSizes.p20),

        // ── Change Password Card ───────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ChangePasswordModal.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark ? AppColors.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: AppColors.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Change Password',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set a new password for your account',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: widget.isDark ? AppColors.darkTextSecondary : Colors.grey),
                ],
              ),
            ),
          ),
        ),

        if (_biometricSupported) ...[
          const SizedBox(height: AppSizes.p16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isDark ? AppColors.darkBorder : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sign in with Biometrics',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _biometricEnabled
                            ? 'Auto-prompt enabled on login for this device'
                            : 'Disabled on this device',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _biometricEnabled,
                  activeTrackColor: AppColors.primaryGreen,
                  onChanged: _toggleBiometric,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSizes.p16),
        // ── Two-Factor Authentication (2FA) Card ───────────
        _buildTwoFactorCard(context),

        const SizedBox(height: AppSizes.p24),
        // ── Danger Zone / Deactivate Account Card ───────────
        widget.buildDangerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_off_outlined, color: AppColors.error, size: 22),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Danger Zone: Deactivate Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Temporarily deactivate your account. Your data is preserved and an administrator can reactivate it later.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_off_outlined, size: 18),
                  label: const Text(
                    'Deactivate Account',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => widget.onDeactivateAccount(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCountBadge() {
    final sessionsAsync = ref.watch(sessionsProvider);
    return sessionsAsync.maybeWhen(
      data: (sessions) {
        final activeCount = sessions.where(_isSessionActive).length;
        if (activeCount == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$activeCount active',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildSessionsList(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final isNarrow = MediaQuery.of(context).size.width < 500;

    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No active devices found.', style: TextStyle(color: Colors.grey)),
          );
        }

        final activeDevices = sessions.where(_isSessionActive).toList();
        final recentDevices = sessions.where((s) => !_isSessionActive(s)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (activeDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  'No active devices right now.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              ...activeDevices.map((session) => _buildSessionItem(context, ref, session, isActiveDevice: true)),
            if (recentDevices.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _isDevicesExpanded = !_isDevicesExpanded);
                  },
                  icon: Icon(
                    _isDevicesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isDevicesExpanded
                        ? 'Hide recently active devices'
                        : 'More (${recentDevices.length} recently active)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              ),
              if (_isDevicesExpanded) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'RECENTLY ACTIVE DEVICES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                ...recentDevices.map((session) => _buildSessionItem(context, ref, session, isActiveDevice: false)),
              ],
            ],
            if (sessions.length > 1) ...[
              const SizedBox(height: 12),
              Align(
                alignment: isNarrow ? Alignment.centerLeft : Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _handleRevokeAllOther(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text(
                    'Sign out of all other devices',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ]
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Error loading sessions: $e', style: const TextStyle(color: AppColors.error)),
      ),
    );
  }

  Widget _buildSessionItem(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> session, {
    required bool isActiveDevice,
  }) {
    final isCurrent = session['is_current'] == true;
    final rawPlatform = (session['platform']?.toString() ?? '').trim();
    final platformLower = (rawPlatform.isEmpty || rawPlatform.toLowerCase() == 'unknown')
        ? 'windows'
        : rawPlatform.toLowerCase();

    final String platformName = platformLower.contains('win')
        ? 'Windows'
        : platformLower.contains('android')
            ? 'Android'
            : platformLower.contains('ios')
                ? 'iOS'
                : platformLower.contains('web')
                    ? 'Web'
                    : platformLower.contains('mac')
                        ? 'macOS'
                        : 'Windows';

    final rawDevice = (session['device_name']?.toString() ?? '').trim();
    final deviceName = (rawDevice.isEmpty ||
            rawDevice.toLowerCase() == 'unknown device' ||
            rawDevice.toLowerCase() == 'device')
        ? (platformName == 'Windows'
            ? 'Windows PC'
            : platformName == 'Android'
                ? 'Android Device'
                : '$platformName Device')
        : rawDevice;

    final ipAddress = (session['ip_address'] ?? '').toString().trim();
    final lastSeen = session['last_seen_at'] != null 
        ? DateFormat('MMM d, y, h:mm a').format(DateTime.parse(session['last_seen_at']).toLocal()) 
        : 'Recently';

    IconData platformIcon = Icons.desktop_windows_rounded;
    if (platformLower.contains('android')) {
      platformIcon = Icons.phone_android_rounded;
    } else if (platformLower.contains('ios')) {
      platformIcon = Icons.phone_iphone_rounded;
    } else if (platformLower.contains('web')) {
      platformIcon = Icons.web_rounded;
    } else if (platformLower.contains('mac')) {
      platformIcon = Icons.laptop_mac_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? AppColors.primaryGreen.withValues(alpha: 0.35)
              : (widget.isDark ? AppColors.darkBorder : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primaryGreen.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  platformIcon,
                  color: isCurrent ? AppColors.primaryGreen : Colors.grey.shade600,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        deviceName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_biometricEnabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fingerprint_rounded, size: 12, color: AppColors.primaryGreen),
                              SizedBox(width: 3),
                              Text(
                                'Biometrics',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (!isCurrent)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                  tooltip: 'Sign out of this device',
                  onPressed: () => _handleRevokeSession(context, ref, session['id'].toString()),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 35),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  platformName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (ipAddress.isNotEmpty) ...[
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                  Text(
                    ipAddress,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  FutureBuilder<String>(
                    future: IpLocationHelper.resolveLocation(ipAddress),
                    initialData: IpLocationHelper.getFastLocation(ipAddress),
                    builder: (context, snapshot) {
                      final loc = snapshot.data;
                      if (loc == null || loc.isEmpty) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            loc,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                Text(
                  isActiveDevice ? 'Active: $lastSeen' : 'Last seen: $lastSeen',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRevokeSession(BuildContext context, WidgetRef ref, String sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of device'),
        content: const Text('Are you sure you want to sign out of this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(revokeSessionProvider)(sessionId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to sign out: $e')));
        }
      }
    }
  }

  Future<void> _handleRevokeAllOther(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of all other devices'),
        content: const Text('This will sign you out of all devices except this one. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIGN OUT ALL'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(revokeAllOtherSessionsProvider)();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to sign out: $e')));
        }
      }
    }
  }

  Widget _buildTwoFactorCard(BuildContext context) {
    final enabled = _twoFactorStatus?['enabled'] == true;
    final method = _twoFactorStatus?['method'] as String?;
    final remaining =
        (_twoFactorStatus?['backupCodesRemaining'] as num?)?.toInt() ?? 0;

    final String statusLabel;
    final String subtitle;
    if (_isLoading2fa) {
      statusLabel = 'Loading...';
      subtitle = 'Checking two-factor authentication status...';
    } else if (enabled) {
      final isTotp = method == 'totp';
      statusLabel = isTotp ? 'TOTP Active' : 'Email OTP';
      final methodName = isTotp ? 'Authenticator App' : 'Email OTP';
      subtitle = 'Protected via $methodName • $remaining backup codes left';
    } else {
      statusLabel = 'Off';
      subtitle =
          'Add an extra layer of security with Authenticator App or Email OTP';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isLoading2fa ? null : _openTwoFactorModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? AppColors.darkBorder : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSizes.p12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Two-Factor Authentication (2FA)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: enabled
                                ? AppColors.primaryGreen.withValues(alpha: 0.14)
                                : (widget.isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: enabled
                                  ? (widget.isDark
                                        ? const Color(0xFF76BA8A)
                                        : AppColors.primaryGreen)
                                  : (widget.isDark
                                        ? AppColors.darkTextSecondary
                                        : Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.isDark ? AppColors.darkTextSecondary : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
