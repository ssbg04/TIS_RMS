import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/user_model.dart';
import '../../../providers/sessions_provider.dart';
import 'change_password_modal.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Logged-in Devices Card (Collapsible) ───────────
        widget.buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _isDevicesExpanded = !_isDevicesExpanded);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.devices_outlined,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                        const SizedBox(width: AppSizes.p12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Logged-in Devices',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildDeviceCountBadge(),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage devices where your account is currently active.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isDevicesExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: widget.isDark
                                ? AppColors.darkTextSecondary
                                : Colors.grey.shade600,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Divider(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 10),
                    _buildSessionsList(context, ref),
                  ],
                ),
                crossFadeState: _isDevicesExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.p24),

        // ── Change Password Card ───────────
        widget.buildCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            onTap: () => ChangePasswordModal.show(context),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.primaryGreen, size: 24),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set a new password for your account',
                        style: TextStyle(
                          fontSize: 13,
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

        if (widget.user.username.toLowerCase() != 'developer') ...[
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
      ],
    );
  }

  Widget _buildDeviceCountBadge() {
    final sessionsAsync = ref.watch(sessionsProvider);
    return sessionsAsync.maybeWhen(
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        final count = sessions.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count ${count == 1 ? 'device' : 'devices'}',
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

    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No active sessions found.', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...sessions.map((session) => _buildSessionItem(context, ref, session)),
            if (sessions.length > 1) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () => _handleRevokeAllOther(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out of all other devices'),
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

  Widget _buildSessionItem(BuildContext context, WidgetRef ref, Map<String, dynamic> session) {
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
    final deviceName = (rawDevice.isEmpty || rawDevice.toLowerCase() == 'unknown device' || rawDevice.toLowerCase() == 'device')
        ? (platformName == 'Windows'
            ? 'Windows PC'
            : platformName == 'Android'
                ? 'Android Device'
                : '$platformName Device')
        : rawDevice;

    final ipAddress = session['ip_address'] ?? '';
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primaryGreen.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          platformIcon,
          color: isCurrent ? AppColors.primaryGreen : Colors.grey.shade600,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              deviceName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrent)
            Container(
              margin: const EdgeInsets.only(left: 8),
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
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '$platformName ${ipAddress.isNotEmpty ? "• $ipAddress" : ""}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            'Last seen: $lastSeen',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
      trailing: !isCurrent
          ? IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              tooltip: 'Sign out of this device',
              onPressed: () => _handleRevokeSession(context, ref, session['id'].toString()),
            )
          : null,
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
}
