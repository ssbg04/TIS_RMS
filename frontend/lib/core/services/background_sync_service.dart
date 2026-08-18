import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../network/api_constants.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Retrieve the saved base URL and Auth Token
      final prefs = await SharedPreferences.getInstance();
      String rawUrl = prefs.getString('server_url') ?? ApiConstants.baseUrl;
      final clean = rawUrl.replaceAll(RegExp(r'/+$'), '');
      final baseUrl = clean.endsWith('/api') ? clean : '$clean/api';

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) {
        return Future.value(true); // Not logged in
      }

      // 2. Fetch notifications from server (/notifications)
      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final response = await dio.get('/notifications');
      final list = (response.data as List).cast<Map<String, dynamic>>();

      if (list.isNotEmpty) {
        // 3. Find the last seen notification ID
        final highestOldId = prefs.getInt('last_seen_notification_id') ?? 0;

        // Find new unread notifications
        final newNotes = list.where((e) {
          final id = e['id'] as int? ?? 0;
          final isRead = (e['is_read'] == 1 || e['is_read'] == true);
          if (highestOldId == 0) {
            return !isRead;
          }
          return id > highestOldId && !isRead;
        }).toList();

        if (newNotes.isNotEmpty) {
          final notificationService = NotificationService();
          await notificationService.initialize();

          // 4. Show local notification for each new one
          for (var note in newNotes) {
            final id = note['id'] as int?;
            final title = note['title']?.toString() ?? 'TIS RMS Notification';
            final message = note['message']?.toString() ?? '';
            await notificationService.showNotification(
              id: id,
              title: title,
              body: message,
            );
          }
        }

        // 5. Update highest seen ID in prefs
        final ids = list.map((e) => e['id'] as int? ?? 0).toList();
        if (ids.isNotEmpty) {
          final newHighestId = ids.reduce(math.max);
          await prefs.setInt(
            'last_seen_notification_id',
            math.max(highestOldId, newHighestId),
          );
        }
      }

      return Future.value(true);
    } catch (_) {
      return Future.value(false); // Retries on false
    }
  });
}
