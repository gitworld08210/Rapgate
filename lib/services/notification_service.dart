import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Local + server-recorded notifications.
///
/// Remote push delivery is no longer FCM-based: the `register-notification-
/// token` Edge Function stores a device token in `notification_tokens`, and
/// server events (fine review, streak reminders) are recorded in
/// `notification_events`. Actual push delivery to the device requires a
/// separate push provider wired to `PUSH_WEBHOOK_URL` (see SUPABASE_SETUP.md);
/// until that is configured, this client still shows local notifications for
/// in-app reminders.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Static callback that the app can wire up (e.g., from main.dart or
  /// HomeScreen) to handle notification tap navigation. The payload string
  /// identifies which screen to navigate to (e.g., 'pushup_screen',
  /// 'fine_screen').
  static void Function(String? payload)? onNotificationTap;

  /// Whether water reminders are currently enabled.
  // FIXME: This should persist via SharedPreferences or similar so it
  // survives app restarts. For now it resets to false on each launch.
  static bool waterRemindersEnabled = false;

  /// Fixed notification IDs for water reminders (one per scheduled time).
  static const List<int> _waterReminderIds = [1001, 1002, 1003, 1004];

  Future<void> initialize() async {
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

    await _createNotificationChannels();
  }

  /// Registers this device with the backend so server-side events (fine
  /// review outcomes, streak reminders) can be recorded against it. Call
  /// once a real push token/device id is available from a push provider.
  Future<void> registerToken(String token, {String platform = 'android'}) async {
    try {
      await supabase.functions.invoke('register-notification-token', body: {
        'token': token,
        'platform': platform,
      });
    } catch (e) {
      debugPrint('Could not register notification token: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'pushup_reminders',
          'Push-up Reminders',
          description: 'Reminders to complete daily push-ups',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'fines',
          'Fine Notifications',
          description: 'Notifications about fines for missed push-ups',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'health_tracking',
          'Health Tracking',
          description: 'Reminders for food logging and water intake',
          importance: Importance.defaultImportance,
        ),
      );

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

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('Notification tapped: $payload');
    // FIXME: For deep navigation (e.g., to pushup_screen), the
    // onNotificationTap callback must be wired from the widget tree.
    if (onNotificationTap != null) {
      onNotificationTap!(payload);
    }
  }

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

  Future<void> showPushupReminder({
    String title = 'Push-up time! 💪',
    String body =
        '1 ghanta baaki hai — complete your push-ups to keep apps unlocked!',
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: 'pushup_reminders',
      payload: 'pushup_screen',
    );
  }

  /// Schedules 4 daily water reminder notifications.
  ///
  /// Uses [periodicallyShow] with [RepeatInterval.daily] for each reminder.
  /// Note: `periodicallyShow` repeats from the moment it is scheduled (not at
  /// a specific clock time). Proper time-specific scheduling would require the
  /// `timezone` package and [zonedSchedule] with
  /// `matchDateTimeComponents: DateTimeComponents.time`.
  // FIXME: Replace with zonedSchedule + timezone package for exact daily times
  // (9 AM, 12 PM, 3 PM, 6 PM). The current approach repeats once every 24h
  // from the moment scheduleWaterReminders() is called, which is approximate.
  Future<void> scheduleWaterReminders() async {
    // Cancel any existing water reminders first.
    await cancelWaterReminders();

    const messages = [
      'Time for a glass of water! Stay hydrated. 💧',
      'Hydration check! Grab a glass of water. 💧',
      'Water break! Keep your intake on track. 💧',
      'Evening reminder: drink some water! 💧',
    ];

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'health_tracking',
        'Health Tracking',
        channelDescription: 'Reminders for food logging and water intake',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (var i = 0; i < _waterReminderIds.length; i++) {
      await _localNotifications.periodicallyShow(
        _waterReminderIds[i],
        'Water Reminder',
        messages[i],
        RepeatInterval.daily,
        notificationDetails,
        payload: 'water_tracker',
      );
    }

    waterRemindersEnabled = true;
  }

  /// Cancels all scheduled water reminder notifications (IDs 1001-1004).
  Future<void> cancelWaterReminders() async {
    for (final id in _waterReminderIds) {
      await _localNotifications.cancel(id);
    }
    waterRemindersEnabled = false;
  }

  Future<void> showFineNotification({required int amountPaise}) async {
    final amountRupees = amountPaise / 100;
    await _showLocalNotification(
      title: 'Fine Created ₹${amountRupees.toStringAsFixed(0)}',
      body: 'Push-ups missed today. Pay the fine or complete push-ups now.',
      channelId: 'fines',
      payload: 'fine_screen',
    );
  }
}
