import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../screens/pushup/pushup_screen.dart';
import '../screens/fines/fines_screen.dart';

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

  /// Global navigator key used by MaterialApp so notification taps can
  /// navigate without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
    final payload = response.payload;
    if (payload == null) return;

    switch (payload) {
      case 'pushup_screen':
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const PushupScreen()),
        );
        break;
      case 'fine_screen':
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const FinesScreen()),
        );
        break;
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
