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
  ServerConnectionStatus? _previousStatus;
  bool _showRestoredBanner = false;
  Timer? _restoredTimer;

  @override
  void dispose() {
    _restoredTimer?.cancel();
    super.dispose();
  }

  void _handleStatusChange(ServerConnectionStatus current) {
    if (_previousStatus != null &&
        (_previousStatus == ServerConnectionStatus.offline ||
            _previousStatus == ServerConnectionStatus.reconnecting) &&
        current == ServerConnectionStatus.connected) {
      // Transitioned back to connected: flash a brief positive confirmation
      setState(() {
        _showRestoredBanner = true;
      });
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() {
            _showRestoredBanner = false;
          });
        }
      });
    } else if (current != ServerConnectionStatus.connected) {
      _restoredTimer?.cancel();
      _showRestoredBanner = false;
    }
    _previousStatus = current;
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(serverConnectionStatusProvider);
    _handleStatusChange(status);

    final isOffline = status == ServerConnectionStatus.offline;
    final isReconnecting = status == ServerConnectionStatus.reconnecting;
    final isRestored = _showRestoredBanner && status == ServerConnectionStatus.connected;

    final isVisible = isOffline || isReconnecting || isRestored;

    final Color bgColor;
    final Color textColor;
    final Color borderColor;
    final IconData icon;
    final String message;
    final bool showProgress;

    if (isRestored) {
      bgColor = const Color(0xFF065F46); // Emerald 800
      textColor = const Color(0xFFD1FAE5); // Emerald 100
      borderColor = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
      message = 'Connection restored — back online';
      showProgress = false;
    } else if (isReconnecting) {
      bgColor = const Color(0xFF78350F); // Amber 900
      textColor = const Color(0xFFFEF3C7); // Amber 100
      borderColor = const Color(0xFFF59E0B);
      icon = Icons.sync_rounded;
      message = 'Reconnecting to server…';
      showProgress = true;
    } else if (isOffline) {
      bgColor = const Color(0xFF7F1D1D); // Red 900
      textColor = const Color(0xFFFEE2E2); // Red 100
      borderColor = const Color(0xFFEF4444);
      icon = Icons.wifi_off_rounded;
      message = 'Offline — Trying to reconnect';
      showProgress = false;
    } else {
      bgColor = Colors.transparent;
      textColor = Colors.transparent;
      borderColor = Colors.transparent;
      icon = Icons.circle;
      message = '';
      showProgress = false;
    }

    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, -1.2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: isVisible ? 1.0 : 0.0,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1),
              boxShadow: isVisible
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
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
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOffline) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => ref.read(heartbeatServiceProvider).checkNow(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
    );
  }
}
