import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_notification_service.dart';
import 'api_service.dart';

class NotificationPoller {
  static final NotificationPoller _instance = NotificationPoller._internal();
  factory NotificationPoller() => _instance;
  NotificationPoller._internal();

  Timer? _pollingTimer;
  bool _isRunning = false;

  Future<void> startPolling({
    required int userId,
    Duration interval = const Duration(seconds: 15),
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    _pollingTimer = Timer.periodic(interval, (_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final shownIds = prefs.getStringList('shown_notification_ids') ?? [];
        final shownSet = shownIds.toSet();

        final notifications = await ApiService().getNotifications();
        if (notifications != null && notifications.isNotEmpty) {
          for (final notif in notifications) {
            final id = notif['id'].toString();
            final isRead = notif['read'] == true || notif['read'] == 1;

            if (!shownSet.contains(id) && !isRead) {
              await LocalNotificationService().showNotification(
                id: int.tryParse(id) ?? DateTime.now().millisecondsSinceEpoch,
                title: notif['title'] ?? 'Notification',
                body: notif['body'] ?? '',
                payload: id,
              );
              shownSet.add(id);
            }
          }

          // Save updated shown IDs
          await prefs.setStringList('shown_notification_ids', shownSet.toList());
        }
      } catch (e) {
        // ignore errors silently
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _isRunning = false;
  }
}
