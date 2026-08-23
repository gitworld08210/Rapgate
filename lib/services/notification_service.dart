import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../main.dart';
import '../screens/fines/fines_screen.dart';
import '../screens/pushup/pushup_screen.dart';
import '../screens/water/water_tracker_screen.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  Future<void> initialize() async {
    // Initialize timezone data for scheduled notifications.
    tz.initializeTimeZones();

    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels (Android)
    await _createNotificationChannels();

    // Handle FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Get and store FCM token
    final token = await _fcm.getToken();
    debugPrint('FCM Token: $token');

    // Schedule daily water intake reminders.
    await scheduleWaterReminders();
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Push-up reminder channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'pushup_reminders',
          'Push-up Reminders',
          description: 'Reminders to complete daily push-ups',
          importance: Importance.high,
        ),
      );

      // Fine notifications channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'fines',
          'Fine Notifications',
          description: 'Notifications about fines for missed push-ups',
          importance: Importance.high,
        ),
      );

      // Health tracking channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'health_tracking',
          'Health Tracking',
          description: 'Reminders for food logging and water intake',
          importance: Importance.defaultImportance,
        ),
      );

      // Streak notifications
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'streaks',
          'Streak Updates',
          description: 'Updates about your streaks',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Handle foreground FCM message
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'HealthPush',
        body: message.notification!.body ?? '',
        channelId: message.data['channel'] ?? 'health_tracking',
      );
    }
  }

  /// Handle message opened app (user tapped notification)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.data}');
    final screen = message.data['screen'] ?? message.data['channel'];
    _navigateToScreen(screen);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _navigateToScreen(response.payload);
  }

  /// Navigate to the appropriate screen based on [route].
  ///
  /// Uses the global [NavigatorState] from [HealthPushApp.navigatorKey]. If the
  /// navigator is not yet mounted (e.g. during early startup), this is a no-op.
  void _navigateToScreen(String? route) {
    if (route == null || route.isEmpty) return;

    final navigator = HealthPushApp.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator not ready, cannot navigate to $route');
      return;
    }

    switch (route) {
      case 'pushup_screen':
        navigator.push(
          MaterialPageRoute(builder: (_) => const PushupScreen()),
        );
      case 'fine_screen':
        navigator.push(
          MaterialPageRoute(builder: (_) => const FinesScreen()),
        );
      case 'water_reminder':
        navigator.push(
          MaterialPageRoute(builder: (_) => const WaterTrackerScreen()),
        );
      default:
        debugPrint('Unknown notification route: $route');
    }
  }

  /// Schedule water intake reminders at 2-hour intervals during waking hours
  /// (08:00, 10:00, 12:00, 14:00, 16:00, 18:00, 20:00). Each reminder repeats
  /// daily at the same time.
  Future<void> scheduleWaterReminders() async {
    // Cancel any previously scheduled water reminders (IDs 9000-9006).
    for (int i = 0; i < 7; i++) {
      await _localNotifications.cancel(9000 + i);
    }

    const hours = [8, 10, 12, 14, 16, 18, 20];
    final location = tz.local;

    for (int i = 0; i < hours.length; i++) {
      final scheduledTime = _nextInstanceOfHour(hours[i], location);

      await _localNotifications.zonedSchedule(
        9000 + i,
        'Time to hydrate! \u{1F4A7}',
        'You\'re doing great - have a glass of water.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'health_tracking',
            'Health Tracking',
            channelDescription: 'Reminders for food logging and water intake',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'water_reminder',
      );
    }
  }

  /// Returns the next [tz.TZDateTime] for the given [hour] in [location].
  /// If the hour has already passed today, returns tomorrow at that hour.
  tz.TZDateTime _nextInstanceOfHour(int hour, tz.Location location) {
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String channelId = 'health_tracking',
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Show push-up reminder notification
  Future<void> showPushupReminder({
    String title = 'Push-up time! \u{1F4AA}',
    String body =
        '1 ghanta baaki hai \u{2014} complete your push-ups to keep apps unlocked!',
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: 'pushup_reminders',
      payload: 'pushup_screen',
    );
  }

  /// Show fine notification
  Future<void> showFineNotification({
    required int amountPaise,
  }) async {
    final amountRupees = amountPaise / 100;
    await _showLocalNotification(
      title: 'Fine Created \u{20B9}${amountRupees.toStringAsFixed(0)}',
      body: 'Push-ups missed today. Pay the fine or complete push-ups now.',
      channelId: 'fines',
      payload: 'fine_screen',
    );
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}
