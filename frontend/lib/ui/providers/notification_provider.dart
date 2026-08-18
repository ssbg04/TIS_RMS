import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/entities/notification_model.dart';
import '../../core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationsProvider =
    AsyncNotifierProvider<NotificationNotifier, List<NotificationModel>>(() {
      return NotificationNotifier();
    });

class NotificationNotifier extends AsyncNotifier<List<NotificationModel>> {
  Timer? _pollingTimer;

  @override
  FutureOr<List<NotificationModel>> build() async {
    // Start real-time polling every 10 seconds while app is open
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      refreshNotifications();
    });

    // Clean up on dispose
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    final repo = ref.read(notificationRepositoryProvider);
    final list = await repo.getNotifications();

    // Check if there are any unread notifications on initial load
    if (list.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final highestOldId = prefs.getInt('last_seen_notification_id') ?? 0;

      final newNotes = list.where((e) {
        if (!e.isRead) {
          if (highestOldId == 0) return true;
          return e.id > highestOldId;
        }
        return false;
      }).toList();

      if (newNotes.isNotEmpty) {
        for (var note in newNotes) {
          await NotificationService().showNotification(
            id: note.id,
            title: note.title,
            body: note.message,
          );
        }
      }

      final highestId = list.map((e) => e.id).reduce(math.max);
      await prefs.setInt('last_seen_notification_id', math.max(highestOldId, highestId));
    }

    return list;
  }

  Future<void> refreshNotifications() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final list = await repo.getNotifications();

      final prefs = await SharedPreferences.getInstance();
      final highestOldId = prefs.getInt('last_seen_notification_id') ?? 0;

      if (list.isNotEmpty) {
        final newNotes = list.where((e) {
          if (!e.isRead) {
            if (highestOldId == 0) return true;
            return e.id > highestOldId;
          }
          return false;
        }).toList();

        if (newNotes.isNotEmpty) {
          for (var note in newNotes) {
            await NotificationService().showNotification(
              id: note.id,
              title: note.title,
              body: note.message,
            );
          }
        }

        final highestId = list.map((e) => e.id).reduce(math.max);
        await prefs.setInt('last_seen_notification_id', math.max(highestOldId, highestId));
      }

      state = AsyncData(list);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAllAsRead();

      if (state.hasValue) {
        final updatedList = state.value!
            .map(
              (n) => NotificationModel(
                id: n.id,
                userId: n.userId,
                title: n.title,
                message: n.message,
                isRead: true,
                createdAt: n.createdAt,
              ),
            )
            .toList();
        state = AsyncData(updatedList);
      }
    } catch (e) {
      // Keep original state on failure
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(id);

      if (state.hasValue) {
        final updatedList = state.value!
            .map(
              (n) => n.id == id
                  ? NotificationModel(
                      id: n.id,
                      userId: n.userId,
                      title: n.title,
                      message: n.message,
                      isRead: true,
                      createdAt: n.createdAt,
                    )
                  : n,
            )
            .toList();
        state = AsyncData(updatedList);
      }
    } catch (e) {
      // Keep original state on failure
    }
  }

  Future<void> clearNotifications() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.clearNotifications();
      // Clear local state immediately
      state = const AsyncData([]);
    } catch (e) {
      // Keep original state on failure
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      final repo = ref.read(notificationRepositoryProvider);

      // Optimistically remove from state
      if (state.hasValue) {
        final updatedList = state.value!.where((n) => n.id != id).toList();
        state = AsyncData(updatedList);
      }

      await repo.deleteNotification(id);
    } catch (e) {
      // Refresh to restore original state if delete fails
      refreshNotifications();
    }
  }
}
