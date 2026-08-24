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

  /// In-memory guard: reminders are scheduled at most once per app session.
  /// This prevents `periodicallyShow` from resetting its timer anchor on every
  /// cold start. Acceptable trade-off: reminders re-register once per session
  /// rather than persisting across sessions (which would require
  /// shared_preferences).
  static bool _remindersScheduled = false;

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

    // Request notification permission on Android 13+ before scheduling.
    await _requestAndroidNotificationPermission();

    // Schedule recurring health reminders once per app session.
    if (!_remindersScheduled) {
      await scheduleHydrationReminders();
      await scheduleFoodLogReminder();
      _remindersScheduled = true;
    }
  }

  /// Requests the POST_NOTIFICATIONS runtime permission on Android 13 (API 33)
  /// and above. On older versions or iOS this is a no-op.
  Future<void> _requestAndroidNotificationPermission() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
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
  static const int _foodReminderNotificationId = 9002;

  /// Schedules a repeating hydration reminder approximately every hour.
  ///
  /// Uses `periodicallyShow` with [RepeatInterval.hourly] as the closest
  /// available cadence for "drink water regularly" reminders. Android may
  /// batch notifications, so real frequency depends on device power settings.
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

  /// Schedules a single daily food logging reminder.
  ///
  /// Previously this created two separate daily reminders (lunch + dinner),
  /// but `periodicallyShow` with `RepeatInterval.daily` does not accept a
  /// time-of-day parameter. Both reminders ended up firing at the same
  /// OS-determined offset, producing a confusing duplicate burst. Consolidated
  /// into one daily reminder until `zonedSchedule` with the timezone package
  /// is added for precise time-of-day control.
  Future<void> scheduleFoodLogReminder() async {
    // Cancel any previously scheduled food reminder to avoid duplicates.
    await _localNotifications.cancel(_foodReminderNotificationId);

    await _localNotifications.periodicallyShow(
      _foodReminderNotificationId,
      'Log your meals 🍽️',
      'Have you logged your meals today? Tracking helps you hit your calorie goals.',
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
    await _localNotifications.cancel(_foodReminderNotificationId);
  }
}
