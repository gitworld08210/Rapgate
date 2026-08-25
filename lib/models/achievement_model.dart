/// Categories of achievements in the app.
enum AchievementCategory { streak, nutrition, fitness, hydration }

/// A single achievement/milestone the user can unlock through consistent use.
class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int requiredValue;
  final AchievementCategory category;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress; // 0.0 - 1.0

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.requiredValue,
    required this.category,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0.0,
  });

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? progress,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      emoji: emoji,
      requiredValue: requiredValue,
      category: category,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
    );
  }

  /// Master list of all possible achievements.
  static const List<Achievement> allAchievements = [
    // ---- Streak ----
    Achievement(
      id: 'streak_3',
      title: 'First Steps',
      description: 'Reach a 3-day push-up streak',
      emoji: '\u{1F331}', // seedling
      requiredValue: 3,
      category: AchievementCategory.streak,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Reach a 7-day push-up streak',
      emoji: '\u{1F525}', // fire
      requiredValue: 7,
      category: AchievementCategory.streak,
    ),
    Achievement(
      id: 'streak_14',
      title: 'Two-Week Titan',
      description: 'Reach a 14-day push-up streak',
      emoji: '\u{26A1}', // lightning
      requiredValue: 14,
      category: AchievementCategory.streak,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Monthly Monster',
      description: 'Reach a 30-day push-up streak',
      emoji: '\u{1F3C6}', // trophy
      requiredValue: 30,
      category: AchievementCategory.streak,
    ),
    Achievement(
      id: 'streak_60',
      title: 'Diamond Discipline',
      description: 'Reach a 60-day push-up streak',
      emoji: '\u{1F48E}', // gem
      requiredValue: 60,
      category: AchievementCategory.streak,
    ),
    Achievement(
      id: 'streak_100',
      title: 'Centurion',
      description: 'Reach a 100-day push-up streak',
      emoji: '\u{1F451}', // crown
      requiredValue: 100,
      category: AchievementCategory.streak,
    ),

    // ---- Fitness ----
    Achievement(
      id: 'fitness_first_session',
      title: 'First Set',
      description: 'Complete your first verified push-up session',
      emoji: '\u{1F4AA}', // flexed biceps
      requiredValue: 1,
      category: AchievementCategory.fitness,
    ),
    Achievement(
      id: 'fitness_50_reps',
      title: 'Fifty Reps',
      description: 'Complete 50 total verified reps',
      emoji: '\u{1F44A}', // fist
      requiredValue: 50,
      category: AchievementCategory.fitness,
    ),
    Achievement(
      id: 'fitness_100_reps',
      title: 'Hundred Club',
      description: 'Complete 100 total verified reps',
      emoji: '\u{1F3AF}', // bullseye
      requiredValue: 100,
      category: AchievementCategory.fitness,
    ),
    Achievement(
      id: 'fitness_500_reps',
      title: 'Iron Will',
      description: 'Complete 500 total verified reps',
      emoji: '\u{1F9BE}', // mechanical arm
      requiredValue: 500,
      category: AchievementCategory.fitness,
    ),

    // ---- Nutrition ----
    Achievement(
      id: 'nutrition_first_scan',
      title: 'First Scan',
      description: 'Log your first food scan',
      emoji: '\u{1F4F8}', // camera with flash
      requiredValue: 1,
      category: AchievementCategory.nutrition,
    ),
    Achievement(
      id: 'nutrition_7_days',
      title: 'Week of Meals',
      description: 'Log food for 7 days',
      emoji: '\u{1F37D}', // plate with utensils
      requiredValue: 7,
      category: AchievementCategory.nutrition,
    ),
    Achievement(
      id: 'nutrition_protein_7',
      title: 'Macro Master',
      description: 'Hit your protein target 7 days',
      emoji: '\u{1F947}', // gold medal
      requiredValue: 7,
      category: AchievementCategory.nutrition,
    ),

    // ---- Hydration ----
    Achievement(
      id: 'hydration_first_glass',
      title: 'First Glass',
      description: 'Log any water intake',
      emoji: '\u{1F4A7}', // droplet
      requiredValue: 1,
      category: AchievementCategory.hydration,
    ),
    Achievement(
      id: 'hydration_hero',
      title: 'Hydration Hero',
      description: 'Hit 3L water target 7 days in a row',
      emoji: '\u{1F30A}', // ocean wave
      requiredValue: 7,
      category: AchievementCategory.hydration,
    ),
  ];
}
