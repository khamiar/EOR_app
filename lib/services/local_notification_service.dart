import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;

class LocalNotificationService {
  // Singleton pattern
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notification settings (Android only)
  Future<void> initialize() async {
    debugPrint('Initializing local notifications...');

    try {
      tz_init.initializeTimeZones();
      await _createNotificationChannels();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
    

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      debugPrint('Local notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  // Request notification permissions (Android only)
  Future<bool> requestPermissions() async {
    debugPrint('Requesting notification permissions');
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await androidImplementation?.requestNotificationsPermission();
    final bool? exactAlarmPermission = await androidImplementation?.requestExactAlarmsPermission();
    debugPrint('Exact alarm permission granted: $exactAlarmPermission');
    return granted ?? false;
  }

  // Show immediate notification (Android only)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'eoreporter_channel',
      'EOReporter Notifications',
      channelDescription: 'System notifications for EOReporter app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );

    debugPrint('Notification shown: $title');
  }


  // Schedule a notification for future delivery
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'eoreporter_scheduled_channel',
      'EOReporter Scheduled Notifications',
      channelDescription: 'Scheduled notifications from EOReporter app',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint(
        'Notification scheduled for ${scheduledDate.toIso8601String()}: $title');
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
  
  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    debugPrint('Creating notification channels for Android');
    
    // Main notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'eoreporter_channel',
      'EOReporter Notifications',
      description: 'System notifications for EOReporter app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    
    // Create the channel
    await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
      
    // Scheduled notifications channel
    const AndroidNotificationChannel scheduledChannel = AndroidNotificationChannel(
      'eoreporter_scheduled_channel',
      'EOReporter Scheduled Notifications',
      description: 'Scheduled notifications from EOReporter app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );
    
    // Create the scheduled channel
    await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(scheduledChannel);
      
    debugPrint('Notification channels created successfully');
  }
}
