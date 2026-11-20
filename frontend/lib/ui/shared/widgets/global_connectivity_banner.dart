import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connected_users_provider.dart';

/// A sleek, non-blocking global banner that floats at the top of the viewport
/// to inform users of network connectivity state changes without blocking interaction.
class GlobalConnectivityBanner extends ConsumerStatefulWidget {
  const GlobalConnectivityBanner({super.key});

  @override
  ConsumerState<GlobalConnectivityBanner> createState() =>
      _GlobalConnectivityBannerState();
}

class _GlobalConnectivityBannerState
    extends ConsumerState<GlobalConnectivityBanner> {
  bool _showRestoredBanner = false;
  Timer? _restoredTimer;

  @override
  void dispose() {
    _restoredTimer?.cancel();
    super.dispose();
  }

  void _onStatusChanged(
    ServerConnectionStatus? previous,
    ServerConnectionStatus current,
  ) {
    if (previous != null &&
        (previous == ServerConnectionStatus.offline ||
            previous == ServerConnectionStatus.reconnecting) &&
        current == ServerConnectionStatus.connected) {
      setState(() => _showRestoredBanner = true);
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() => _showRestoredBanner = false);
        }
      });
    } else if (current != ServerConnectionStatus.connected && _showRestoredBanner) {
      _restoredTimer?.cancel();
      setState(() => _showRestoredBanner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ServerConnectionStatus>(
      serverConnectionStatusProvider,
      _onStatusChanged,
    );

    final status = ref.watch(serverConnectionStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOffline = status == ServerConnectionStatus.offline;
    final isReconnecting = status == ServerConnectionStatus.reconnecting;
    final isRestored =
        _showRestoredBanner && status == ServerConnectionStatus.connected;

    final isVisible = isOffline || isReconnecting || isRestored;

    final Color bgColor;
    final Color textColor;
    final Color borderColor;
    final Color accentColor;
    final IconData icon;
    final String message;
    final bool showProgress;

    if (isRestored) {
      accentColor = const Color(0xFF10B981);
      bgColor = isDark ? const Color(0xFF0F2922) : const Color(0xFFECFDF5);
      textColor = isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46);
      borderColor = accentColor.withValues(alpha: isDark ? 0.45 : 0.35);
      icon = Icons.check_circle_rounded;
      message = 'Connection restored — back online';
      showProgress = false;
    } else if (isReconnecting) {
      accentColor = const Color(0xFFF59E0B);
      bgColor = isDark ? const Color(0xFF2B2111) : const Color(0xFFFFFBEB);
      textColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
      borderColor = accentColor.withValues(alpha: isDark ? 0.45 : 0.40);
      icon = Icons.sync_rounded;
      message = 'Reconnecting to server…';
      showProgress = true;
    } else if (isOffline) {
      accentColor = const Color(0xFFEF4444);
      bgColor = isDark ? const Color(0xFF2D1517) : const Color(0xFFFEF2F2);
      textColor = isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B);
      borderColor = accentColor.withValues(alpha: isDark ? 0.45 : 0.35);
      icon = Icons.wifi_off_rounded;
      message = 'Offline — Trying to reconnect';
      showProgress = false;
    } else {
      accentColor = Colors.transparent;
      bgColor = Colors.transparent;
      textColor = Colors.transparent;
      borderColor = Colors.transparent;
      icon = Icons.circle;
      message = '';
      showProgress = false;
    }

    return IgnorePointer(
      ignoring: !isVisible,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          offset: isVisible ? Offset.zero : const Offset(0, -1.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 240),
            opacity: isVisible ? 1.0 : 0.0,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: isVisible
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.10,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (showProgress)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        )
                      else
                        Icon(icon, size: 16, color: accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.15,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOffline) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              ref.read(heartbeatServiceProvider).checkNow(),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Retry',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
