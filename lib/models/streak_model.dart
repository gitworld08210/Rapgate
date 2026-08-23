class StreakModel {
  final int currentPushupStreak;
  final int longestPushupStreak;
  final int currentFoodLogStreak;
  final int consecutiveMisses;
  final int restDayPasses;
  final DateTime? lastPushupDate;
  final DateTime? lastFoodLogDate;

  StreakModel({
    this.currentPushupStreak = 0,
    this.longestPushupStreak = 0,
    this.currentFoodLogStreak = 0,
    this.consecutiveMisses = 0,
    this.restDayPasses = 0,
    this.lastPushupDate,
    this.lastFoodLogDate,
  });

  factory StreakModel.fromMap(Map<String, dynamic> data) => StreakModel(
        currentPushupStreak: (data['current_pushup_streak'] as num?)?.toInt() ?? 0,
        longestPushupStreak: (data['longest_pushup_streak'] as num?)?.toInt() ?? 0,
        currentFoodLogStreak: (data['current_food_log_streak'] as num?)?.toInt() ?? 0,
        consecutiveMisses: (data['consecutive_misses'] as num?)?.toInt() ?? 0,
        restDayPasses: (data['rest_day_passes'] as num?)?.toInt() ?? 0,
        lastPushupDate: DateTime.tryParse(data['last_pushup_date']?.toString() ?? ''),
        lastFoodLogDate: DateTime.tryParse(data['last_food_log_date']?.toString() ?? ''),
      );
}
