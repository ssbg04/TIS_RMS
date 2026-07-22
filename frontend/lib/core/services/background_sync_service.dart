import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Retrieve the saved base URL and Auth Token
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('server_url');
      if (baseUrl == null) return true; // No server known, wait till next run

      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      if (token == null) return true; // Not logged in

      // 2. Fetch recent notifications from server
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {'Authorization': 'Bearer $token'},
      ));

      final response = await dio.get('/notifications/recent');
      final list = (response.data as List).cast<Map<String, dynamic>>();

      if (list.isNotEmpty) {
        // 3. Find the last seen notification ID
        final highestOldId = prefs.getInt('last_seen_notification_id') ?? 0;
        
        // Find new ones
        final newNotes = list.where((e) => (e['id'] as int) > highestOldId).toList();
        
        if (newNotes.isNotEmpty) {
          final notificationService = NotificationService();
          await notificationService.initialize(); // Ensure it's ready in this isolate

          // 4. Show local notification for each new one
          for (var note in newNotes) {
            await notificationService.showNotification(
              title: note['title'] ?? 'New Notification',
              body: note['message'] ?? '',
            );
          }

          // 5. Update highest seen ID in prefs
          final newHighestId = list.map((e) => e['id'] as int).reduce(math.max);
          await prefs.setInt('last_seen_notification_id', math.max(highestOldId, newHighestId));
        }
      }

      return Future.value(true);
    } catch (e) {
      print('Background fetch failed: $e');
      return Future.value(false); // Retries on false
    }
  });
}
