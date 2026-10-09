import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connected_users_provider.dart';

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

    Color color;
    Color bgColor;
    String label;

    switch (status) {
      case ServerConnectionStatus.connected:
        color = const Color(0xFF10B981); // Emerald
        bgColor = color.withValues(alpha: isDark ? 0.20 : 0.12);
        label = 'Connected';
        break;
      case ServerConnectionStatus.reconnecting:
        color = const Color(0xFFF59E0B); // Amber
        bgColor = color.withValues(alpha: isDark ? 0.20 : 0.12);
        label = 'Reconnecting...';
        break;
      case ServerConnectionStatus.offline:
        color = const Color(0xFFEF4444); // Red
        bgColor = color.withValues(alpha: isDark ? 0.20 : 0.12);
        label = 'Offline';
        break;
    }

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
