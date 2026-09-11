import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_constants.dart';
import 'notification_service.dart';

/// Top-level background message handler — required by firebase_messaging.
/// When app is killed/backgrounded, presents the local notification banner.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final notifIdStr = message.data['id']?.toString();
    int? notifId = (notifIdStr != null && notifIdStr.isNotEmpty)
        ? int.tryParse(notifIdStr)
        : null;

    // Advance last_seen_notification_id so AlarmReceiver and Workmanager won't duplicate it
    if (notifId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentLastId = prefs.getInt('last_seen_notification_id') ?? 0;
        if (notifId > currentLastId) {
          await prefs.setInt('last_seen_notification_id', notifId);
        }
      } catch (_) {}
    }

    // On Android, if message.notification != null, Google Play Services has already
    // presented the notification in the tray. Only present manually for data-only messages.
    if (message.notification == null) {
      final title = message.data['title']?.toString() ?? 'TIS RMS';
      final body = message.data['body']?.toString() ?? '';
      if (body.isNotEmpty) {
        await NotificationService().showNotification(
          id: notifId,
          title: title,
          body: body,
        );
      }
    }
  } catch (e) {
    debugPrint('[FcmBackground] Handler error: $e');
  }
}

class FcmService {
  static bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    try {
      if (!_isMobile || Firebase.apps.isEmpty) return;
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Auto-refresh token with backend whenever FCM rotates the token
      messaging.onTokenRefresh.listen((newToken) {
        registerToken();
      });

      // Foreground: show local notification banner (with deduplication)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final notifIdStr = message.data['id']?.toString();
        int? notifId = (notifIdStr != null && notifIdStr.isNotEmpty)
            ? int.tryParse(notifIdStr)
            : null;

        // Advance last_seen_notification_id so polling or background sync won't repeat it
        if (notifId != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final currentLastId = prefs.getInt('last_seen_notification_id') ?? 0;
            if (notifId > currentLastId) {
              await prefs.setInt('last_seen_notification_id', notifId);
            }
          } catch (_) {}
        }

        final title = message.notification?.title ??
            message.data['title']?.toString() ??
            'TIS RMS';
        final body = message.notification?.body ??
            message.data['body']?.toString() ??
            '';
        if (body.isNotEmpty) {
          await NotificationService().showNotification(
            id: notifId,
            title: title,
            body: body,
          );
        }
      });

      // Eagerly register token with backend on startup if an active session exists
      registerToken();
    } catch (e) {
      debugPrint('[FcmService] Init error: $e');
    }
  }

  static Future<void> registerToken() async {
    try {
      if (!_isMobile || Firebase.apps.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final rawUrl = prefs.getString('server_url') ?? ApiConstants.baseUrl;
      final clean = rawUrl.replaceAll(RegExp(r'/+$'), '');
      final baseUrl = clean.endsWith('/api') ? clean : '$clean/api';

      String? jwtToken = prefs.getString('jwt_token');
      if (jwtToken == null || jwtToken.isEmpty) {
        jwtToken = await const FlutterSecureStorage().read(key: 'jwt_token');
      }
      if (jwtToken == null || jwtToken.isEmpty) return;

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));

      await dio.post('/notifications/fcm-token', data: {'token': token});
      debugPrint('[FcmService] FCM token registered successfully with backend');
    } catch (e) {
      debugPrint('[FcmService] Token registration failed: $e');
    }
  }

  static Future<void> unregisterToken() async {
    try {
      if (!_isMobile || Firebase.apps.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();

      final prefs = await SharedPreferences.getInstance();
      final rawUrl = prefs.getString('server_url') ?? ApiConstants.baseUrl;
      final clean = rawUrl.replaceAll(RegExp(r'/+$'), '');
      final baseUrl = clean.endsWith('/api') ? clean : '$clean/api';

      String? jwtToken = prefs.getString('jwt_token');
      if (jwtToken == null || jwtToken.isEmpty) {
        jwtToken = await const FlutterSecureStorage().read(key: 'jwt_token');
      }
      if (jwtToken != null && jwtToken.isNotEmpty) {
        final dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'Authorization': 'Bearer $jwtToken'},
        ));

        await dio.post('/notifications/fcm-token/unregister', data: {'token': token});
      }

      // Delete FCM token from device instance so no further push notifications arrive
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[FcmService] Token unregistered and deleted from device');
    } catch (e) {
      debugPrint('[FcmService] Token unregistration error: $e');
    }
  }
}
