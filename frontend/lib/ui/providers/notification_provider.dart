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

final notificationsProvider = AsyncNotifierProvider<NotificationNotifier, List<NotificationModel>>(() {
  return NotificationNotifier();
});

class NotificationNotifier extends AsyncNotifier<List<NotificationModel>> {
  Timer? _pollingTimer;

  @override
  FutureOr<List<NotificationModel>> build() async {
    // Start real-time polling every 30 seconds
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshNotifications();
    });

    // Clean up on dispose
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    final repo = ref.read(notificationRepositoryProvider);
    return await repo.getNotifications();
  }

  Future<void> refreshNotifications() async {
    try {
      final oldList = state.value ?? [];
      final repo = ref.read(notificationRepositoryProvider);
      final list = await repo.getNotifications();
      
      // Trigger native notification for newly fetched items
      if (oldList.isNotEmpty && list.isNotEmpty) {
        final highestOldId = oldList.map((e) => e.id).reduce(math.max);
        final newNotes = list.where((e) => e.id > highestOldId).toList();
        
        for (var note in newNotes) {
          NotificationService().showNotification(
            title: note.title, 
            body: note.message,
          );
        }
      }

      if (list.isNotEmpty) {
        final highestId = list.map((e) => e.id).reduce(math.max);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_seen_notification_id', highestId);
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
            .map((n) => NotificationModel(
                  id: n.id,
                  userId: n.userId,
                  title: n.title,
                  message: n.message,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
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
            .map((n) => n.id == id
                ? NotificationModel(
                    id: n.id,
                    userId: n.userId,
                    title: n.title,
                    message: n.message,
                    isRead: true,
                    createdAt: n.createdAt,
                  )
                : n)
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
