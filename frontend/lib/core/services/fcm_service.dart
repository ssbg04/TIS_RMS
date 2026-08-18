import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_constants.dart';
import 'notification_service.dart';

/// Top-level background message handler — required by firebase_messaging.
/// FCM automatically shows the notification when the app is killed/backgrounded
/// if the message has a `notification` payload. Nothing extra needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Auto-refresh token with backend whenever FCM rotates the token
    _messaging.onTokenRefresh.listen((newToken) {
      registerToken();
    });

    // Foreground: show local notification banner (with deduplication)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ??
          message.data['title']?.toString() ??
          'TIS RMS';
      final body = message.notification?.body ??
          message.data['body']?.toString() ??
          '';
      int? notifId;
      if (message.data['id'] != null && message.data['id'].toString().isNotEmpty) {
        notifId = int.tryParse(message.data['id'].toString());
      }
      if (body.isNotEmpty) {
        await NotificationService().showNotification(
          id: notifId,
          title: title,
          body: body,
        );
      }
    });
  }

  static Future<void> registerToken() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final rawUrl = prefs.getString('server_url') ?? ApiConstants.baseUrl;
      final clean = rawUrl.replaceAll(RegExp(r'/+$'), '');
      final baseUrl = clean.endsWith('/api') ? clean : '$clean/api';

      final jwtToken = prefs.getString('jwt_token') ?? '';
      if (jwtToken.isEmpty) return;

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));

      await dio.post('/notifications/fcm-token', data: {'token': token});
      debugPrint('[FcmService] Token registered');
    } catch (e) {
      debugPrint('[FcmService] Token registration failed: $e');
    }
  }
}
