import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/food_log_model.dart';

class FoodService {
  final SupabaseClient _db = supabase;
  final ImagePicker _imagePicker = ImagePicker();

  static const _bucket = 'food-images';

  /// Pick image from camera
  Future<XFile?> pickFromCamera() async {
    return await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
  }

  /// Pick image from gallery
  Future<XFile?> pickFromGallery() async {
    return await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
  }

  /// Uploads to the private `food-images` bucket under `<uid>/food_images/`,
  /// which is the path prefix required by the bucket's RLS policy and by
  /// the `scan-food-image` Edge Function's ownership check.
  Future<String> uploadFoodImage(String uid, XFile imageFile) async {
    final fileName = 'food_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$uid/food_images/$fileName';

    await _db.storage.from(_bucket).upload(
          path,
          File(imageFile.path),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    // Private bucket: a time-limited signed URL is required for display.
    return await _db.storage.from(_bucket).createSignedUrl(path, 60 * 60 * 24 * 7);
  }

  /// Scan food image using the `scan-food-image` Edge Function (AI Vision).
  Future<FoodScanResult> scanFoodImage({
    required String imageBase64,
    required MealType mealType,
    String? imagePath,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'scan-food-image',
        body: {
          'imageBase64': imageBase64,
          'mealType': mealType.name,
          if (imagePath != null) 'imagePath': imagePath,
        },
      );

      if (response.status >= 400) {
        throw Exception((response.data as Map?)?['error'] ?? 'Scan failed');
      }

      final data = response.data as Map<String, dynamic>;
      final detectedItems = (data['detectedItems'] as List<dynamic>)
          .map((item) => FoodItem.fromMap(item as Map<String, dynamic>))
          .toList();

      return FoodScanResult(
        detectedItems: detectedItems,
        totalCalories: (data['totalCalories'] ?? 0.0).toDouble(),
        totalProtein: (data['totalProtein'] ?? 0.0).toDouble(),
      );
    } catch (e) {
      throw Exception('Food scan failed: $e');
    }
  }

  /// Convert XFile to base64
  Future<String> imageToBase64(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  /// Search food from barcode via the `search-food-by-barcode` Edge Function
  /// (which itself calls Open Food Facts — no API key required).
  Future<FoodItem?> searchByBarcode(String barcode) async {
    try {
      final response = await _db.functions.invoke(
        'search-food-by-barcode',
        body: {'barcode': barcode},
      );
      if (response.status >= 400) return null;

      final data = response.data as Map<String, dynamic>;
      if (data['found'] == true) {
        return FoodItem.fromMap(data['item'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Result from food scan API
class FoodScanResult {
  final List<FoodItem> detectedItems;
  final double totalCalories;
  final double totalProtein;

  FoodScanResult({
    required this.detectedItems,
    required this.totalCalories,
    required this.totalProtein,
  });
}
