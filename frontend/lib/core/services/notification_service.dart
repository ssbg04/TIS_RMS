import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Skip on Web and Windows (flutter_local_notifications does not support Windows platform interface)
    if (kIsWeb || Platform.isWindows) {
      _initialized = true;
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
          linux: initializationSettingsLinux,
        );

    try {
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) {
              // Handle notification tapped logic here if needed
            },
      );

      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'tis_rms_activities_channel',
          'Recent Activities',
          description: 'Notifications for recent activities and system events',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidImplementation?.createNotificationChannel(channel);

        try {
          await androidImplementation?.requestNotificationsPermission();
        } catch (_) {}
      }
    } catch (_) {}

    _initialized = true;
  }

  final Set<String> _recentlyShown = <String>{};

  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
  }) async {
    // Skip on Web and Windows
    if (kIsWeb || Platform.isWindows) return;

    if (!_initialized) await initialize();

    // Deduplication check: key primarily by notification ID if available, otherwise by content
    final dedupeKey = id != null
        ? 'id_$id'
        : 'msg_${title.trim()}_${body.trim()}';

    if (_recentlyShown.contains(dedupeKey)) {
      debugPrint('[NotificationService] Suppressed duplicate notification: $dedupeKey');
      return;
    }
    _recentlyShown.add(dedupeKey);
    // Evict after 60 seconds (covers rapid polling cycles and AlarmManager checks)
    Future.delayed(const Duration(seconds: 60), () {
      _recentlyShown.remove(dedupeKey);
    });

    // Advance last_seen_notification_id in SharedPreferences
    if (id != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final current = prefs.getInt('last_seen_notification_id') ?? 0;
        if (id > current) {
          await prefs.setInt('last_seen_notification_id', id);
        }
      } catch (_) {}
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'tis_rms_activities_channel', // id
          'Recent Activities', // name
          channelDescription:
              'Notifications for recent activities and system events',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          showWhen: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final notificationId =
        id ?? (DateTime.now().millisecondsSinceEpoch.remainder(100000));

    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
