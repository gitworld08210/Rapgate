import '../models/achievement_model.dart';

/// Pure-computation service that derives achievement unlock status
/// from existing app data. No database calls - achievements are computed
/// from data already held in providers.
class AchievementService {
  AchievementService._();

  /// Computes the full list of achievements with unlock status and progress.
  ///
  /// All parameters represent cumulative or current stats pulled from the
  /// user's profile and health providers.
  static List<Achievement> computeAchievements({
    required int currentPushupStreak,
    required int longestPushupStreak,
    required int totalVerifiedSessions,
    required int totalReps,
    required int totalFoodLogDays,
    required int totalFoodScans,
    required int currentWaterStreak,
    required int proteinTargetDays,
  }) {
    // Use the best streak (longest ever) for streak achievements
    final bestStreak =
        longestPushupStreak > currentPushupStreak ? longestPushupStreak : currentPushupStreak;

    return Achievement.allAchievements.map((a) {
      final (int current, int required) = _resolveProgress(
        achievement: a,
        bestStreak: bestStreak,
        totalVerifiedSessions: totalVerifiedSessions,
        totalReps: totalReps,
        totalFoodLogDays: totalFoodLogDays,
        totalFoodScans: totalFoodScans,
        currentWaterStreak: currentWaterStreak,
        proteinTargetDays: proteinTargetDays,
      );

      final progress = required > 0
          ? (current / required).clamp(0.0, 1.0)
          : 0.0;
      final unlocked = current >= required;

      return a.copyWith(
        isUnlocked: unlocked,
        unlockedAt: unlocked ? DateTime.now() : null,
        progress: progress,
      );
    }).toList();
  }

  /// Returns (currentValue, requiredValue) for a given achievement.
  static (int, int) _resolveProgress({
    required Achievement achievement,
    required int bestStreak,
    required int totalVerifiedSessions,
    required int totalReps,
    required int totalFoodLogDays,
    required int totalFoodScans,
    required int currentWaterStreak,
    required int proteinTargetDays,
  }) {
    final required = achievement.requiredValue;

    switch (achievement.category) {
      case AchievementCategory.streak:
        return (bestStreak, required);

      case AchievementCategory.fitness:
        // Differentiate between session-based and rep-based achievements
        if (achievement.id == 'fitness_first_session') {
          return (totalVerifiedSessions, required);
        }
        return (totalReps, required);

      case AchievementCategory.nutrition:
        if (achievement.id == 'nutrition_first_scan') {
          return (totalFoodScans, required);
        }
        if (achievement.id == 'nutrition_protein_7') {
          return (proteinTargetDays, required);
        }
        // nutrition_7_days
        return (totalFoodLogDays, required);

      case AchievementCategory.hydration:
        if (achievement.id == 'hydration_first_glass') {
          // Any water logged counts - use waterStreak >= 1 as proxy
          return (currentWaterStreak > 0 ? 1 : 0, required);
        }
        // hydration_hero: 7 consecutive days hitting 3L
        return (currentWaterStreak, required);
    }
  }

  /// Convenience: count how many achievements are unlocked.
  static int countUnlocked(List<Achievement> achievements) {
    return achievements.where((a) => a.isUnlocked).length;
  }

  /// Returns the next locked achievement closest to completion, or null if all
  /// are unlocked.
  static Achievement? nextMilestone(List<Achievement> achievements) {
    final locked = achievements.where((a) => !a.isUnlocked).toList();
    if (locked.isEmpty) return null;
    locked.sort((a, b) => b.progress.compareTo(a.progress));
    return locked.first;
  }
}
