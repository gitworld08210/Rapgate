class FoodItem {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double confidence;

  FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.confidence = 0,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) => FoodItem(
        name: map['name'] as String? ?? '',
        calories: (map['calories'] as num?)?.toDouble() ?? 0,
        protein: (map['protein'] as num?)?.toDouble() ?? 0,
        carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
        fat: (map['fat'] as num?)?.toDouble() ?? 0,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'confidence': confidence,
      };
}

enum MealType { breakfast, lunch, dinner, snack }
enum FoodLogSource { aiScan, manual, barcode }

class FoodLogModel {
  final String id;
  final String? imageUrl;
  final List<FoodItem> detectedItems;
  final MealType mealType;
  final DateTime loggedAt;
  final FoodLogSource source;

  FoodLogModel({
    required this.id,
    this.imageUrl,
    required this.detectedItems,
    required this.mealType,
    required this.loggedAt,
    required this.source,
  });

  double get totalCalories =>
      detectedItems.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein =>
      detectedItems.fold(0, (sum, item) => sum + item.protein);
  double get totalCarbs =>
      detectedItems.fold(0, (sum, item) => sum + item.carbs);
  double get totalFat =>
      detectedItems.fold(0, (sum, item) => sum + item.fat);

  factory FoodLogModel.fromMap(String id, Map<String, dynamic> data) =>
      FoodLogModel(
        id: id,
        imageUrl: data['image_path'] as String?,
        detectedItems: ((data['detected_items'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => FoodItem.fromMap(Map<String, dynamic>.from(item)))
            .toList(),
        mealType: MealType.values.firstWhere(
          (item) => item.name == data['meal_type'],
          orElse: () => MealType.snack,
        ),
        loggedAt: DateTime.tryParse(data['logged_at']?.toString() ?? '') ??
            DateTime.now(),
        source: _sourceFromValue(data['source']),
      );

  static FoodLogSource _sourceFromValue(Object? value) {
    final normalized = value == 'aiScan' ? 'ai_scan' : value?.toString();
    return switch (normalized) {
      'ai_scan' => FoodLogSource.aiScan,
      'barcode' => FoodLogSource.barcode,
      _ => FoodLogSource.manual,
    };
  }

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'image_path': imageUrl,
        'detected_items': detectedItems.map((item) => item.toMap()).toList(),
        'meal_type': mealType.name,
        'logged_at': loggedAt.toIso8601String(),
        'source': source == FoodLogSource.aiScan ? 'ai_scan' : source.name,
      };
}
