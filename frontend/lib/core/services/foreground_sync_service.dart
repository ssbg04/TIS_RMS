import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/widgets.dart';
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
    WidgetsFlutterBinding.ensureInitialized();
    await _notificationService.initialize();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Refresh memory cache from disk across background isolates

      String rawUrl = prefs.getString('server_url') ?? ApiConstants.baseUrl;
      final clean = rawUrl.replaceAll(RegExp(r'/+$'), '');
      final baseUrl = clean.endsWith('/api') ? clean : '$clean/api';

      String? token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        token = await _storage.read(key: 'jwt_token');
      }
      if (token == null || token.isEmpty) {
        return;
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
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
            
            // 1. Fire pop-up banner notification
            await _notificationService.showNotification(
              id: id,
              title: title,
              body: message,
            );

            // 2. Update persistent status notification text
            await FlutterForegroundTask.updateService(
              notificationTitle: title,
              notificationText: message,
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
    } catch (e) {
      debugPrint('Foreground repeat event error: $e');
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

    FlutterForegroundTask.initCommunicationPort();

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
        eventAction: ForegroundTaskEventAction.repeat(5000), // Check every 5 seconds for instant push
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final NotificationPermission notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {}
  }

  static Future<void> start() async {
    // When FCM / AlarmManager is active, avoid running persistent foreground tasks
    // to remove the 'TIS RMS Sync Active' persistent status notification.
    await stop();
  }

  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
