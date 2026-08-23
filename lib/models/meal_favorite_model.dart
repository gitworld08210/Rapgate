import 'food_log_model.dart';

class MealFavoriteModel {
  final String id;
  final String name;
  final List<FoodItem> detectedItems;
  final String? mealType;
  final DateTime createdAt;

  MealFavoriteModel({
    required this.id,
    required this.name,
    required this.detectedItems,
    this.mealType,
    required this.createdAt,
  });

  factory MealFavoriteModel.fromMap(String id, Map<String, dynamic> data) =>
      MealFavoriteModel(
        id: id,
        name: data['name'] as String? ?? '',
        detectedItems: ((data['detected_items'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => FoodItem.fromMap(Map<String, dynamic>.from(item)))
            .toList(),
        mealType: data['meal_type'] as String?,
        createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'name': name,
        'detected_items': detectedItems.map((item) => item.toMap()).toList(),
        'meal_type': mealType,
      };

  double get totalCalories =>
      detectedItems.fold(0, (sum, item) => sum + item.calories);

  double get totalProtein =>
      detectedItems.fold(0, (sum, item) => sum + item.protein);
}
