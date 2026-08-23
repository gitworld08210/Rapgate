import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// Handles capturing the meal share card as an image and sharing / saving it.
class ShareService {
  ShareService._();
  static final instance = ShareService._();

  final _screenshotController = ScreenshotController();

  /// Returns the [ScreenshotController] used to capture the meal card widget.
  ScreenshotController get controller => _screenshotController;

  /// Captures the widget bound to [controller] as a PNG image.
  ///
  /// The [pixelRatio] controls output resolution. Default 1.0 produces the
  /// exact pixel dimensions of the widget (1080x1920 for the meal card).
  Future<Uint8List?> captureCardAsImage({double pixelRatio = 1.0}) async {
    try {
      final image = await _screenshotController.capture(
        pixelRatio: pixelRatio,
      );
      return image;
    } catch (e) {
      debugPrint('ShareService: capture failed - $e');
      return null;
    }
  }

  /// Shares the captured image via the native share sheet.
  ///
  /// Works with Instagram Stories, WhatsApp Status, and any other app that
  /// accepts image shares.
  Future<void> shareToSocial(Uint8List imageBytes, String caption) async {
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/repgate_meal_card.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: caption,
      );
    } catch (e) {
      debugPrint('ShareService: share failed - $e');
      rethrow;
    }
  }

  /// Saves the captured image to the device gallery.
  ///
  /// Uses share_plus to trigger a "save" action via the system share sheet,
  /// which works on Android 10+ scoped storage without needing
  /// MANAGE_EXTERNAL_STORAGE permission. The user can pick "Save to device"
  /// or share directly from the sheet.
  Future<bool> saveToGallery(Uint8List imageBytes) async {
    try {
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/repgate_meal_$timestamp.png');
      await file.writeAsBytes(imageBytes);

      // Use Share.shareXFiles which handles scoped storage properly on all
      // Android versions. The user can save to gallery from the share sheet.
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My meal card from RepGate',
      );
      return true;
    } catch (e) {
      debugPrint('ShareService: gallery save failed - $e');
      return false;
    }
  }
}
