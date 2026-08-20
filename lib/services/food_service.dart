import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/food_log_model.dart';
import '../utils/constants.dart';

class FoodService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

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

  /// Upload food image to Cloud Storage
  Future<String> uploadFoodImage(String uid, XFile imageFile) async {
    final fileName =
        'food_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('users/$uid/food_images/$fileName');

    final uploadTask = await ref.putFile(
      File(imageFile.path),
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  /// Scan food image using Cloud Function (AI Vision)
  Future<FoodScanResult> scanFoodImage({
    required String imageBase64,
    required MealType mealType,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(AppConstants.cfScanFoodImage)
          .call({
        'imageBase64': imageBase64,
        'mealType': mealType.name,
      });

      final data = result.data as Map<String, dynamic>;
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

  /// Search food from barcode (Open Food Facts API fallback)
  Future<FoodItem?> searchByBarcode(String barcode) async {
    // This would call Open Food Facts API
    // For now, delegated to Cloud Function for better error handling
    try {
      final result = await _functions
          .httpsCallable('searchFoodByBarcode')
          .call({'barcode': barcode});

      final data = result.data as Map<String, dynamic>;
      if (data['found'] == true) {
        return FoodItem.fromMap(data['item'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
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
