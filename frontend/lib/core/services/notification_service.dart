import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        await androidImplementation?.requestNotificationsPermission();

        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'tis_rms_activities_channel',
          'Recent Activities',
          description: 'Notifications for recent activities and system events',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidImplementation?.createNotificationChannel(channel);
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

    // Deduplication check (prevents duplicate triggers from FCM + Polling + Stream)
    final dedupeKey = '${id ?? ''}_${title.trim()}_${body.trim()}';
    if (_recentlyShown.contains(dedupeKey)) {
      return;
    }
    _recentlyShown.add(dedupeKey);
    // Evict after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      _recentlyShown.remove(dedupeKey);
    });

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
