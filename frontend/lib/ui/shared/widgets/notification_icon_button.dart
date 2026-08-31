import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notification_provider.dart';
import '../modals/view_activity_modal.dart';
import '../../screens/dashboard/widgets/notification_dropdown.dart';

Color getNotificationColorHelper(String title) {
  final t = title.toLowerCase();
  if (t.contains('student')) return Colors.blue;
  if (t.contains('document')) return const Color(0xFF1C8248);
  if (t.contains('password')) return Colors.orange;
  return Colors.grey;
}

IconData getNotificationIconHelper(String title) {
  final t = title.toLowerCase();
  if (t.contains('student')) return Icons.person_add;
  if (t.contains('document')) return Icons.upload_file;
  if (t.contains('password')) return Icons.lock_reset;
  return Icons.notifications;
}

void showNotificationDropdownMenu(BuildContext context, WidgetRef ref) {
  final notificationsAsync = ref.read(notificationsProvider);
  final list = notificationsAsync.value ?? [];

  final RenderBox button = context.findRenderObject() as RenderBox;
  final RenderBox overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(
        Offset(0, button.size.height + 4),
        ancestor: overlay,
      ),
      button.localToGlobal(
        button.size.bottomRight(const Offset(0, 4)),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  showMenu(
    context: context,
    position: position,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 8,
    items: [
      // ── Header row ────────────────────────────────────────────────
      PopupMenuItem(
        enabled: false,
        child: Container(
          width: 300,
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (list.isNotEmpty) ...[
                    InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(notificationsProvider.notifier)
                            .markAllAsRead();
                      },
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1C8248),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(notificationsProvider.notifier)
                            .clearNotifications();
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      // ── Empty state ───────────────────────────────────────────────
      if (list.isEmpty)
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 300,
            height: 120,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No new notifications',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        )
      // ── Notification items ────────────────────────────────────────
      else
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: NotificationDropdownWidget(
            notifications: list,
            onViewActivity: (ctx, title, desc, date, icon, color) {
              ViewActivityModal.show(
                context: ctx,
                title: title,
                description: desc,
                date: date,
                icon: icon,
                actionColor: color,
              );
            },
            getIcon: getNotificationIconHelper,
            getColor: getNotificationColorHelper,
          ),
        ),
    ],
  );
}

class NotificationIconButton extends ConsumerWidget {
  final double iconSize;

  const NotificationIconButton({super.key, this.iconSize = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount =
        notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;

    return Builder(
      builder: (ctx) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, size: iconSize),
            tooltip: 'Notifications',
            onPressed: () => showNotificationDropdownMenu(ctx, ref),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
