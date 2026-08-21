import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/food_log_model.dart';

class FoodService {
  final SupabaseClient _db = supabase;
  final ImagePicker _imagePicker = ImagePicker();

  String _functionError(FunctionException error, String fallback) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return fallback;
  }

  static const _bucket = 'food-images';

  // 768px @ q70 is ample for food recognition and roughly halves the base64
  // payload versus 1024px @ q85, which cuts both upload time on mobile data
  // and the time Gemini spends ingesting the image.
  static const _maxDimension = 768.0;
  static const _jpegQuality = 70;

  /// Pick image from camera
  Future<XFile?> pickFromCamera() async {
    return await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _jpegQuality,
    );
  }

  /// Pick image from gallery
  Future<XFile?> pickFromGallery() async {
    return await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _jpegQuality,
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
    return await _db.storage
        .from(_bucket)
        .createSignedUrl(path, 60 * 60 * 24 * 7);
  }

  /// Scan food image using the `scan-food-image` Edge Function (AI Vision).
  Future<FoodScanResult> scanFoodImage({
    required String imageBase64,
    required MealType mealType,
    String scanKind = 'food',
    String? imagePath,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'scan-food-image',
        body: {
          'imageBase64': imageBase64,
          'mealType': mealType.name,
          'scanKind': scanKind,
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
    } on FunctionException catch (error) {
      throw Exception(_functionError(error, 'Food scan failed.'));
    } catch (error) {
      throw Exception('Food scan failed: $error');
    }
  }

  /// Convert XFile to base64
  Future<String> imageToBase64(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  /// Looks up a retail barcode or supported packaging QR payload. Failure
  /// reasons are preserved so invalid QR text, missing products, and network
  /// outages are not all shown as the same "not found" message.
  Future<BarcodeLookupResult> searchByBarcode(String barcode) async {
    try {
      final response = await _db.functions.invoke(
        'search-food-by-barcode',
        body: {'barcode': barcode},
      );
      final raw = response.data;
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (response.status >= 400) {
        return BarcodeLookupResult.failure(
          data['error']?.toString() ?? 'Could not check this product.',
        );
      }
      if (data['found'] == true && data['item'] is Map) {
        return BarcodeLookupResult.found(
          FoodItem.fromMap(Map<String, dynamic>.from(data['item'] as Map)),
          gramBasis: _gramBasisFrom(data['nutritionBasis']),
        );
      }
      return BarcodeLookupResult.failure(
        data['reason']?.toString() ??
            'Product not found. Try scanning the number below the barcode.',
      );
    } on FunctionException catch (error) {
      return BarcodeLookupResult.failure(
        _functionError(error, 'Could not check this product.'),
      );
    } catch (_) {
      return BarcodeLookupResult.failure(
        'Could not reach the product database. Check internet and try again.',
      );
    }
  }
}

/// Parses a weight-based nutrition basis (e.g. "100 g") into grams so the
/// review screen can offer a gram portion picker. Returns null for serving-based
/// results, where the stated serving is already the portion.
int? _gramBasisFrom(Object? basis) {
  if (basis is! String) return null;
  final match =
      RegExp(r'^\s*(\d+)\s*(?:g|gram|grams)\s*$', caseSensitive: false)
          .firstMatch(basis);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

class BarcodeLookupResult {
  const BarcodeLookupResult._({this.item, this.error, this.gramBasis});

  factory BarcodeLookupResult.found(FoodItem item, {int? gramBasis}) =>
      BarcodeLookupResult._(item: item, gramBasis: gramBasis);

  factory BarcodeLookupResult.failure(String message) =>
      BarcodeLookupResult._(error: message);

  final FoodItem? item;
  final String? error;

  /// Grams the returned nutrition refers to, when it is weight-based.
  final int? gramBasis;

  bool get isFound => item != null;
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
