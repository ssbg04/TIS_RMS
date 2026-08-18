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

    // We skip initialization on Web
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // For Windows, initialization settings can be empty if not required by specific windows plugin,
    // flutter_local_notifications natively supports windows.
    // We will just use the default initialization settings for other platforms.
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

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
            // Handle notification tapped logic here if needed
          },
    );

    if (!kIsWeb && Platform.isAndroid) {
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

    _initialized = true;
  }

  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    // Do nothing on web
    if (kIsWeb) return;

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
