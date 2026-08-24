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

    // Schedule recurring health reminders on app start.
    await scheduleHydrationReminders();
    await scheduleFoodLogReminder();
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

  // ===========================================================================
  // Scheduled health reminders
  // ===========================================================================

  /// Unique notification IDs for scheduled reminders so they can be cancelled
  /// and don't collide with the timestamp-based IDs used by one-shot alerts.
  static const int _hydrationNotificationId = 9001;
  static const int _foodLunchNotificationId = 9002;
  static const int _foodDinnerNotificationId = 9003;

  /// Schedules a repeating hydration reminder approximately every hour.
  ///
  /// Uses `periodicallyShow` with [RepeatInterval.hourly] as the closest
  /// available cadence for "drink water regularly" reminders. Android may
  /// batch notifications, so real frequency depends on device power settings.
  /// On Android 13+ users must grant notification permission first.
  Future<void> scheduleHydrationReminders() async {
    // Cancel any previously scheduled hydration reminder to avoid duplicates.
    await _localNotifications.cancel(_hydrationNotificationId);

    await _localNotifications.periodicallyShow(
      _hydrationNotificationId,
      'Stay hydrated! 💧',
      'Time to drink a glass of water. Your body will thank you.',
      RepeatInterval.hourly,
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
      payload: 'water_screen',
    );
  }

  /// Schedules food logging reminders for lunch and dinner (daily).
  ///
  /// Since `zonedSchedule` requires the `timezone` package which is not in
  /// pubspec, we use `periodicallyShow` with daily interval for each meal.
  /// Both fire once per day at OS-determined times. For precise time control,
  /// add the timezone package and use `zonedSchedule` in a future iteration.
  Future<void> scheduleFoodLogReminder() async {
    // Cancel previously scheduled food reminders to avoid duplicates.
    await _localNotifications.cancel(_foodLunchNotificationId);
    await _localNotifications.cancel(_foodDinnerNotificationId);

    // Lunch reminder - daily
    await _localNotifications.periodicallyShow(
      _foodLunchNotificationId,
      'Log your meal 🍽️',
      'Don\'t forget to log your lunch! Tracking helps you hit your calorie goals.',
      RepeatInterval.daily,
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
      payload: 'food_log_screen',
    );

    // Dinner reminder - daily (uses a separate ID; both fire daily but at
    // OS-determined times. For true time control, use zonedSchedule with the
    // timezone package.)
    await _localNotifications.periodicallyShow(
      _foodDinnerNotificationId,
      'Evening check-in 🌙',
      'Have you logged dinner? Keep your streak going strong.',
      RepeatInterval.daily,
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
      payload: 'food_log_screen',
    );
  }

  /// Cancels all scheduled health reminders. Call when the user opts out.
  Future<void> cancelAllHealthReminders() async {
    await _localNotifications.cancel(_hydrationNotificationId);
    await _localNotifications.cancel(_foodLunchNotificationId);
    await _localNotifications.cancel(_foodDinnerNotificationId);
  }
}
