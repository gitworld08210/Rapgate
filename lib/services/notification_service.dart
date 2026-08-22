import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

import '../utils/constants.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize notifications
  Future<void> initialize() async {
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

    // Register the token server-side so Cloud Functions can target this device.
    if (token != null) {
      registerToken(token);
    }

    // Re-register whenever the token is rotated (e.g. app data cleared,
    // OS token refresh, or new device restore).
    _fcm.onTokenRefresh.listen(registerToken);
  }

  /// Sends the FCM token to the `registerFcmToken` Cloud Function.
  ///
  /// Fire-and-forget: callers don't await this because a transient failure
  /// here should not block app startup.
  // NOTE: 'registerFcmToken' matches the export in
  // firebase/functions/src/scheduled.ts.
  void registerToken(String token) {
    FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion)
        .httpsCallable(AppConstants.cfRegisterFcmToken)
        .call({'token': token})
        .catchError((e) {
      debugPrint('Failed to register FCM token: $e');
    });
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
    // TODO: Navigate to relevant screen based on message data
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate based on payload
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
    String title = 'Push-up time! 💪',
    String body = '1 ghanta baaki hai — complete your push-ups to keep apps unlocked!',
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
      title: 'Fine Created ₹${amountRupees.toStringAsFixed(0)}',
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
