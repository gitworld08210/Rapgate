import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

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

  Future<void> initialize() async {
    // Initialize timezone data for scheduled notifications
    tz_data.initializeTimeZones();

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
    debugPrint('Notification tapped: ${response.payload}');
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

  Future<void> showFineNotification({required int amountPaise}) async {
    final amountRupees = amountPaise / 100;
    await _showLocalNotification(
      title: 'Fine Created ₹${amountRupees.toStringAsFixed(0)}',
      body: 'Push-ups missed today. Pay the fine or complete push-ups now.',
      channelId: 'fines',
      payload: 'fine_screen',
    );
  }

  // =========================================================================
  // Scheduled daily reminders
  // =========================================================================

  /// Unique notification IDs for scheduled reminders.
  static const int _pushupReminderId = 9001;
  static const int _foodBreakfastId = 9010;
  static const int _foodLunchId = 9011;
  static const int _foodDinnerId = 9012;
  static const int _waterBaseId = 9020; // 9020..9027 for 8 water slots

  /// Schedule a daily repeating push-up reminder at the user's chosen time.
  Future<void> scheduleDailyPushupReminder(TimeOfDay time) async {
    await _localNotifications.cancel(_pushupReminderId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      _pushupReminderId,
      'Push-up time! 💪',
      'Time to complete your daily push-ups and keep your streak alive!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pushup_reminders',
          'Push-up Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'pushup_screen',
    );
  }

  /// Schedule daily food log reminders at 8 AM (breakfast), 12 PM (lunch),
  /// and 7 PM (dinner).
  Future<void> scheduleDailyFoodLogReminder() async {
    final meals = [
      (id: _foodBreakfastId, hour: 8, label: 'Breakfast'),
      (id: _foodLunchId, hour: 12, label: 'Lunch'),
      (id: _foodDinnerId, hour: 19, label: 'Dinner'),
    ];

    for (final meal in meals) {
      await _localNotifications.cancel(meal.id);

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        meal.hour,
        0,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _localNotifications.zonedSchedule(
        meal.id,
        'Log your ${meal.label} 🍽️',
        'Take a quick photo of your meal to track nutrition.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'health_tracking',
            'Health Tracking',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'food_log_screen',
      );
    }
  }

  /// Schedule water reminders every 2 hours between 8 AM and 10 PM.
  Future<void> scheduleWaterReminders() async {
    // Cancel existing water reminders
    for (int i = 0; i < 8; i++) {
      await _localNotifications.cancel(_waterBaseId + i);
    }

    final hours = [8, 10, 12, 14, 16, 18, 20, 22];
    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < hours.length; i++) {
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hours[i],
        0,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _localNotifications.zonedSchedule(
        _waterBaseId + i,
        'Drink water 💧',
        'Stay hydrated! Time for a glass of water.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'health_tracking',
            'Health Tracking',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'water_screen',
      );
    }
  }

  /// Cancel all scheduled reminders (push-up, food, water).
  Future<void> cancelAllReminders() async {
    await _localNotifications.cancel(_pushupReminderId);
    await _localNotifications.cancel(_foodBreakfastId);
    await _localNotifications.cancel(_foodLunchId);
    await _localNotifications.cancel(_foodDinnerId);
    for (int i = 0; i < 8; i++) {
      await _localNotifications.cancel(_waterBaseId + i);
    }
  }
}
