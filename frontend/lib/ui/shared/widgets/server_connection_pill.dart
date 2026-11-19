import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/connected_users_provider.dart';

(Color color, String label) _statusMeta(ServerConnectionStatus status) {
  switch (status) {
    case ServerConnectionStatus.connected:
      return (const Color(0xFF10B981), 'Connected');
    case ServerConnectionStatus.reconnecting:
      return (const Color(0xFFF59E0B), 'Reconnecting...');
    case ServerConnectionStatus.offline:
      return (const Color(0xFFEF4444), 'Offline');
  }
}

class ServerConnectionPill extends ConsumerWidget {
  final bool compact;

  const ServerConnectionPill({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverConnectionStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, label) = _statusMeta(status);
    final bgColor = color.withValues(alpha: isDark ? 0.20 : 0.12);

    if (compact) {
      return Tooltip(
        message: 'Server: $label',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: status == ServerConnectionStatus.offline
              ? () => ref.read(heartbeatServiceProvider).checkNow()
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: status == ServerConnectionStatus.offline
          ? 'Server disconnected. Tap to retry connection.'
          : 'Server status: $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: status == ServerConnectionStatus.offline
              ? () => ref.read(heartbeatServiceProvider).checkNow()
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ServerConnectionInline extends ConsumerWidget {
  const ServerConnectionInline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverConnectionStatusProvider);
    final (color, label) = _statusMeta(status);
    final isOffline = status == ServerConnectionStatus.offline;
    final displayText = isOffline ? 'Offline · Retry' : label;
    final textColor = status == ServerConnectionStatus.connected
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
        : color;

    return Tooltip(
      message: isOffline
          ? 'Server disconnected. Tap to retry connection.'
          : 'Server status: $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: isOffline
              ? () => ref.read(heartbeatServiceProvider).checkNow()
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isOffline ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ServerStatusAvatar extends ConsumerWidget {
  final String initials;
  final String tooltipName;
  final String roleLabel;
  final double radius;
  final bool showStatusDot;

  const ServerStatusAvatar({
    super.key,
    required this.initials,
    required this.tooltipName,
    required this.roleLabel,
    this.radius = 17,
    this.showStatusDot = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverConnectionStatusProvider);
    final (color, label) = _statusMeta(status);
    final isOffline = status == ServerConnectionStatus.offline;

    return Tooltip(
      message: '$tooltipName (${roleLabel.toUpperCase()}) • Server: $label',
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isOffline
              ? () => ref.read(heartbeatServiceProvider).checkNow()
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: radius,
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.76,
                  ),
                ),
              ),
              if (showStatusDot)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.8,
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
}
