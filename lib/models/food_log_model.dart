import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.confidence = 0.0,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      name: map['name'] ?? '',
      calories: (map['calories'] ?? 0.0).toDouble(),
      protein: (map['protein'] ?? 0.0).toDouble(),
      carbs: (map['carbs'] ?? 0.0).toDouble(),
      fat: (map['fat'] ?? 0.0).toDouble(),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'confidence': confidence,
    };
  }
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

  factory FoodLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FoodLogModel(
      id: doc.id,
      imageUrl: data['imageUrl'],
      detectedItems: (data['detectedItems'] as List<dynamic>?)
              ?.map((item) => FoodItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      mealType: MealType.values.firstWhere(
        (e) => e.name == data['mealType'],
        orElse: () => MealType.snack,
      ),
      loggedAt: (data['loggedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: FoodLogSource.values.firstWhere(
        (e) => e.name == data['source'],
        orElse: () => FoodLogSource.manual,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'detectedItems': detectedItems.map((item) => item.toMap()).toList(),
      'mealType': mealType.name,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'source': source.name,
    };
  }
}
