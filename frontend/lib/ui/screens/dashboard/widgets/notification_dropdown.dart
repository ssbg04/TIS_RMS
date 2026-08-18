import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../../domain/entities/notification_model.dart';
import '../../../../core/utils/date_utils.dart' as pht;
import '../../../shared/modals/reset_requests_modal.dart';

class NotificationDropdownWidget extends ConsumerStatefulWidget {
  final List<NotificationModel> notifications;
  final Function(BuildContext, String, String, String, IconData, Color)
  onViewActivity;
  final Function(String) getIcon;
  final Function(String) getColor;

  const NotificationDropdownWidget({
    super.key,
    required this.notifications,
    required this.onViewActivity,
    required this.getIcon,
    required this.getColor,
  });

  @override
  ConsumerState<NotificationDropdownWidget> createState() =>
      _NotificationDropdownWidgetState();
}

class _NotificationDropdownWidgetState
    extends ConsumerState<NotificationDropdownWidget> {
  int _displayCount = 5;
  int? _hoveredId;

  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationsProvider);
    final list = notificationsState.value ?? widget.notifications;
    final displayList = list.take(_displayCount).toList();
    final hasMore = list.length > _displayCount;

    if (list.isEmpty) {
      return SizedBox(
        width: 300,
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              const Text(
                'No new notifications',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 320,
      height: math.min(
        400,
        (displayList.length * 80.0) + (hasMore ? 50.0 : 0.0) + 16.0,
      ), // fixed max height
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: displayList.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displayList.length) {
            return InkWell(
              onTap: () {
                setState(() {
                  _displayCount += 5;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: const Text(
                  'Load More',
                  style: TextStyle(
                    color: Color(0xFF1C8248),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }

          final note = displayList[index];
          final icon = widget.getIcon(note.title) as IconData;
          final color = widget.getColor(note.title) as Color;

          final itemWidget = MouseRegion(
            onEnter: (_) => setState(() => _hoveredId = note.id),
            onExit: (_) => setState(() => _hoveredId = null),
            child: InkWell(
              onTap: () {
                  ref.read(notificationsProvider.notifier).markAsRead(note.id);
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (context.mounted) {
                      final role = ref.read(authProvider).value?.role;
                      if (note.title.toLowerCase().contains('password') &&
                          role == 'admin') {
                        ResetRequestsModal.show(context);
                      } else {
                        widget.onViewActivity(
                          context,
                          note.title,
                          note.message,
                          pht.formatModalDate(note.createdAt),
                          icon,
                          color,
                        );
                      }
                    }
                  });
                },
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    note.title,
                                    style: TextStyle(
                                      fontWeight: note.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (!note.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              note.message,
                              style: TextStyle(
                                fontSize: 12,
                                color: note.isRead
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: note.isRead
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pht.formatRelative(note.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hoveredId == note.id)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            ref
                                .read(notificationsProvider.notifier)
                                .deleteNotification(note.id);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 12,
                        ),
                    ],
                  ),
                ),
              ),
            );

          if (!kIsWeb && Platform.isAndroid) {
            return Dismissible(
              key: ValueKey(note.id),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                ref
                    .read(notificationsProvider.notifier)
                    .deleteNotification(note.id);
              },
              background: Container(
                color: Colors.redAccent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              secondaryBackground: Container(
                color: Colors.redAccent,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: itemWidget,
            );
          }

          return itemWidget;
        },
      ),
    );
  }
}
