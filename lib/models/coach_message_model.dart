class CoachMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;
  final bool isLoading;

  const CoachMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
    this.isLoading = false,
  });

  CoachMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<String>? suggestions,
    bool? isLoading,
  }) {
    return CoachMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserHealthContext {
  final String userName;
  final int userAge;
  final double userWeight;
  final double userHeight;
  final String userGender;
  final double calorieTarget;
  final double proteinTarget;
  final double carbsTarget;
  final double fatTarget;
  final int waterTargetMl;
  final int pushupTarget;

  final double consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;
  final int consumedWaterMl;
  final int streakDays;

  final List<Map<String, dynamic>> loggedMeals;

  const UserHealthContext({
    required this.userName,
    required this.userAge,
    required this.userWeight,
    required this.userHeight,
    required this.userGender,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
    required this.waterTargetMl,
    required this.pushupTarget,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    required this.consumedWaterMl,
    required this.streakDays,
    required this.loggedMeals,
  });

  double get calorieDeficit => (calorieTarget - consumedCalories);
  double get proteinDeficit => (proteinTarget - consumedProtein).clamp(0.0, proteinTarget);
  double get carbsDeficit => (carbsTarget - consumedCarbs);
  double get fatDeficit => (fatTarget - consumedFat);
  int get waterDeficitMl => (waterTargetMl - consumedWaterMl).clamp(0, waterTargetMl);
}
