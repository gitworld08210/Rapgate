import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/food_log_model.dart';

/// Uploads food scan images + AI-detected labels to Cloudinary for future
/// model training. This runs fire-and-forget after a successful scan so it
/// never blocks the user.
///
/// Configure via --dart-define:
///   CLOUDINARY_CLOUD_NAME=your-cloud
///   CLOUDINARY_UPLOAD_PRESET=rapgate-dataset   (unsigned preset)
///
/// Folder structure on Cloudinary:
///   rapgate-dataset/<user_id>/<timestamp>_<meal>.jpg
///
/// The AI labels are stored as Cloudinary context metadata (key: `labels`),
/// so you can query/export them when building your training set.
class DatasetService {
  static const _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const _uploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: 'rapgate-dataset');

  static bool get isConfigured => _cloudName.isNotEmpty;

  /// Upload the food image + detected items as labels. Fire-and-forget.
  static Future<void> uploadForTraining({
    required XFile imageFile,
    required String userId,
    required MealType mealType,
    required List<FoodItem> detectedItems,
  }) async {
    if (!isConfigured) return; // Silently skip if not configured

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final folder = 'rapgate-dataset/$userId';
      final publicId = '${timestamp}_${mealType.name}';

      // Build label metadata: items as JSON string
      final labels = detectedItems.map((item) {
        return {
          'name': item.name,
          'calories': item.calories,
          'protein': item.protein,
          'carbs': item.carbs,
          'fat': item.fat,
          'confidence': item.confidence,
        };
      }).toList();

      final contextMeta = 'labels=${Uri.encodeComponent(jsonEncode(labels))}'
          '|meal_type=${mealType.name}'
          '|user_id=$userId'
          '|detected_count=${detectedItems.length}'
          '|total_calories=${detectedItems.fold<double>(0, (s, i) => s + i.calories).round()}';

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..fields['public_id'] = publicId
        ..fields['context'] = contextMeta
        ..fields['tags'] = [
          mealType.name,
          ...detectedItems.map((i) => i.name.toLowerCase().replaceAll(' ', '-')),
        ].take(10).join(',')
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Cloudinary upload timeout'),
      );

      if (response.statusCode == 200) {
        debugPrint('[DatasetService] Image uploaded to Cloudinary: $folder/$publicId');
      } else {
        debugPrint('[DatasetService] Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      // Never crash the app for a training upload failure
      debugPrint('[DatasetService] Upload error (non-fatal): $e');
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
