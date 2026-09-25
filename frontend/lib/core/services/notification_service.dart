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

        const channels = [
          AndroidNotificationChannel(
            'tis_rms_activities_sound_vibrate',
            'Recent Activities (Sound & Vibrate)',
            description: 'Notifications with sound and vibration',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
          AndroidNotificationChannel(
            'tis_rms_activities_sound_only',
            'Recent Activities (Sound Only)',
            description: 'Notifications with sound only',
            importance: Importance.max,
            playSound: true,
            enableVibration: false,
          ),
          AndroidNotificationChannel(
            'tis_rms_activities_vibrate_only',
            'Recent Activities (Vibrate Only)',
            description: 'Notifications with vibration only',
            importance: Importance.max,
            playSound: false,
            enableVibration: true,
          ),
          AndroidNotificationChannel(
            'tis_rms_activities_silent',
            'Recent Activities (Silent)',
            description: 'Silent notifications without sound or vibration',
            importance: Importance.high,
            playSound: false,
            enableVibration: false,
          ),
          AndroidNotificationChannel(
            'tis_rms_activities_channel',
            'Recent Activities',
            description: 'Notifications for recent activities and system events',
            importance: Importance.max,
            playSound: false,
            enableVibration: false,
          ),
        ];

        for (final ch in channels) {
          await androidImplementation?.createNotificationChannel(ch);
        }

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

    bool soundEnabled = false;
    bool vibrationEnabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      soundEnabled = prefs.getBool('pref_sound_enabled') ?? false;
      vibrationEnabled = prefs.getBool('pref_vibration_enabled') ?? false;
    } catch (_) {}

    String channelId;
    if (soundEnabled && vibrationEnabled) {
      channelId = 'tis_rms_activities_sound_vibrate';
    } else if (soundEnabled) {
      channelId = 'tis_rms_activities_sound_only';
    } else if (vibrationEnabled) {
      channelId = 'tis_rms_activities_vibrate_only';
    } else {
      channelId = 'tis_rms_activities_silent';
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channelId,
          'Recent Activities',
          channelDescription:
              'Notifications for recent activities and system events',
          importance: (soundEnabled || vibrationEnabled)
              ? Importance.max
              : Importance.high,
          priority: Priority.max,
          playSound: soundEnabled,
          enableVibration: vibrationEnabled,
          visibility: NotificationVisibility.public,
          showWhen: true,
        );

    final DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentSound: soundEnabled,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
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
