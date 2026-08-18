import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_constants.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(ForegroundSyncHandler());
}

class ForegroundSyncHandler extends TaskHandler {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notificationService = NotificationService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _notificationService.initialize();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String rawUrl = prefs.getString('server_url') ?? ApiConstants.baseUrl;
      final clean = rawUrl.replaceAll(RegExp(r'/+$'), '');
      final baseUrl = clean.endsWith('/api') ? clean : '$clean/api';

      final token = await _storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) {
        return;
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final response = await dio.get('/notifications');
      final list = (response.data as List).cast<Map<String, dynamic>>();

      if (list.isNotEmpty) {
        final highestOldId = prefs.getInt('last_seen_notification_id') ?? 0;

        final newNotes = list.where((e) {
          final id = e['id'] as int? ?? 0;
          final isRead = (e['is_read'] == 1 || e['is_read'] == true);
          if (highestOldId == 0) return !isRead;
          return id > highestOldId && !isRead;
        }).toList();

        if (newNotes.isNotEmpty) {
          await _notificationService.initialize();
          for (var note in newNotes) {
            final id = note['id'] as int?;
            final title = note['title']?.toString() ?? 'TIS RMS Notification';
            final message = note['message']?.toString() ?? '';
            await _notificationService.showNotification(
              id: id,
              title: title,
              body: message,
            );
          }
        }

        final ids = list.map((e) => e['id'] as int? ?? 0).toList();
        if (ids.isNotEmpty) {
          final newHighestId = ids.reduce(math.max);
          await prefs.setInt(
            'last_seen_notification_id',
            math.max(highestOldId, newHighestId),
          );
        }
      }
    } catch (_) {
      // Ignore transient network errors
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}

class ForegroundSyncService {
  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tis_rms_foreground_sync',
        channelName: 'TIS RMS Background Sync',
        channelDescription:
            'Maintains real-time connection with local server for notifications',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000), // Check every 10 seconds
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (kIsWeb || !Platform.isAndroid) return;

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'TIS RMS Sync Active',
      notificationText: 'Connected to local server for real-time notifications',
      notificationIcon: null,
      callback: startForegroundCallback,
    );
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
