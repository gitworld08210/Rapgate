import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for communicating with Android native modules via Platform Channels
class PlatformChannelService {
  static const MethodChannel _channel =
      MethodChannel('com.healthpush.app/applock');

  static const EventChannel _eventChannel =
      EventChannel('com.healthpush.app/applock_events');

  /// Check if Accessibility Service is enabled
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking accessibility: $e');
      return false;
    }
  }

  /// Open Accessibility Service settings
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('Error opening accessibility settings: $e');
    }
  }

  /// Check if overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Request overlay permission
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      debugPrint('Error requesting overlay permission: $e');
    }
  }

  /// Check if Usage Stats permission is granted
  Future<bool> hasUsageStatsPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking usage stats permission: $e');
      return false;
    }
  }

  /// Request Usage Stats permission
  Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } on PlatformException catch (e) {
      debugPrint('Error requesting usage stats permission: $e');
    }
  }

  /// Check if battery optimization is disabled (important for Xiaomi/Oppo/Vivo)
  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request disable battery optimization
  Future<void> requestDisableBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestDisableBatteryOptimization');
    } on PlatformException catch (e) {
      debugPrint('Error requesting battery optimization disable: $e');
    }
  }

  /// Update blocked apps list in native service
  Future<void> updateBlockedApps(List<String> blockedPackages) async {
    try {
      await _channel.invokeMethod('updateBlockedApps', {
        'packages': blockedPackages,
      });
    } on PlatformException catch (e) {
      debugPrint('Error updating blocked apps: $e');
    }
  }

  /// Update allowlist in native service
  Future<void> updateAllowlist(List<String> allowlistPackages) async {
    try {
      await _channel.invokeMethod('updateAllowlist', {
        'packages': allowlistPackages,
      });
    } on PlatformException catch (e) {
      debugPrint('Error updating allowlist: $e');
    }
  }

  /// Set unlock status in native service
  Future<void> setUnlockStatus({
    required bool isUnlocked,
    DateTime? unlockUntil,
  }) async {
    try {
      await _channel.invokeMethod('setUnlockStatus', {
        'isUnlocked': isUnlocked,
        'unlockUntilMs': unlockUntil?.millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      debugPrint('Error setting unlock status: $e');
    }
  }

  /// Get list of installed apps (for blocked app selection)
  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (result == null) return [];
      return result
          .map((app) => Map<String, String>.from(app as Map))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('Error getting installed apps: $e');
      return [];
    }
  }

  /// Start the app lock service
  Future<void> startAppLockService() async {
    try {
      await _channel.invokeMethod('startAppLockService');
    } on PlatformException catch (e) {
      debugPrint('Error starting app lock service: $e');
    }
  }

  /// Stop the app lock service
  Future<void> stopAppLockService() async {
    try {
      await _channel.invokeMethod('stopAppLockService');
    } on PlatformException catch (e) {
      debugPrint('Error stopping app lock service: $e');
    }
  }

  /// Listen to app lock events (blocked app detected, etc.)
  Stream<Map<String, dynamic>> get appLockEvents {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }
}
