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
  /// On Android this writes to the Pictures directory via MediaStore.
  /// Falls back to saving in the app's temp directory if gallery access fails.
  Future<bool> saveToGallery(Uint8List imageBytes) async {
    try {
      // Use the external storage Pictures directory on Android
      final directory = Directory('/storage/emulated/0/Pictures/RepGate');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/meal_card_$timestamp.png');
      await file.writeAsBytes(imageBytes);
      return true;
    } catch (e) {
      debugPrint('ShareService: gallery save failed - $e');
      // Fallback: save to temp directory
      try {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${tempDir.path}/meal_card_$timestamp.png');
        await file.writeAsBytes(imageBytes);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
